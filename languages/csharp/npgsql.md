# Npgsql

用途は、PostgreSQL へ接続し、transaction の確定と制約違反の判別を担う data provider である。
採用は、C# は Npgsql である。
判断基準は、composition が所有する transaction で確定点を一つにでき、一意制約違反を SqlState で判別できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 書き込みパス

### 要求
composition が所有する UnitOfWork は Npgsql の transaction で実装し、store は受け取った transaction の中で書く。

### 根拠
store が transaction を握ると、業務判断と確定の制御が混ざり、複数の store をまたぐ一つの確定ができない。
composition が transaction を所有し store が受け取った transaction の中で書けば、確定点が一つに定まる。
一つの確定点に集めれば、状態とイベントを同一のパスで記録できる。

### 完了条件
UnitOfWork が、composition の所有する Npgsql の transaction で実装されている。
store が、受け取った transaction の中で書いている。
確定点が、一つである。

### 禁止事項
store が、transaction の begin・commit を所有すること。

### 行動
composition で transaction を begin し、store に渡して書かせ、composition で commit する。

### 例
組立点が transaction を所有し、状態とイベントを同じ経路で書いた後に一度だけ確定する。

```csharp
await using var connection = await _dataSource.OpenConnectionAsync();
await using var transaction = await connection.BeginTransactionAsync();
await orderStore.InsertAsync(connection, transaction, order);
await outbox.AddAsync(connection, transaction, new OrderPlaced(order.Id));
await transaction.CommitAsync();
```

## 冪等な要求の記録

### 要求
冪等な要求は、operation、actor scope、tenant、key を全て NOT NULL の列として持ち、その複合一意制約で競合を検出する。
認証済み要求は検証済み actor ID、匿名要求は session または client ごとの安定した opaque scope、system 要求は logical actor ごとの ID を actor scope に使う。
multi-tenant operation の認証済み要求は、認証境界で検証した tenant claim または membership、もしくは authorization で許可した tenant 選択から構築した `TenantId` を tenant scope に使う。
multi-tenant operation の匿名要求は、検証済みの host または route と、session または client の tenant context から構築した `TenantId` を tenant scope に使う。
multi-tenant operation の system 要求は、logical actor に設定した `TenantId` を tenant scope に使う。
single-tenant operation は、正準な single-tenant sentinel を tenant scope に使う。
tenant の概念を持たない operation は、正準な no-tenant sentinel を tenant scope に使う。
安定した scope のない匿名要求は、server 発行の全体で一意な key と発行時の proof だけを受け付け、proof を検証した要求者にだけ保存済み response を返す。
request fingerprint と初回 response は、冪等 key と業務の書き込みと同じ Npgsql transaction で保存する。
同じ scope と key の再実行は、fingerprint が一致する場合だけ保存済み response を返し、不一致なら conflict を返す。

### 根拠
[transaction](../../concerns/transaction/README.md) が定める複合 scope と同じ確定点を PostgreSQL の制約と Npgsql transaction に写せば、同時要求の競合と部分確定を DB で止められる。
actor scope を検索条件へ含めれば、別の主体へ保存済み response を返さない。
actor の種別ごとに [transaction](../../concerns/transaction/README.md) の scope を写せば、匿名や system を汎用 sentinel へ潰さない。
tenant の出所を認証、認可、host、route、logical actor の検証済み context に限れば、要求者が指定した未検証 tenant へ scope を切り替えられない。

### 完了条件
operation、actor scope、tenant、key の全列が NOT NULL で、複合一意制約を持っている。
認証済み actor、匿名の安定した opaque scope、logical system actor が actor の種別に応じて記録されている。
multi-tenant operation に、認証済み tenant、匿名の検証済み host または route と session/client tenant context、logical system actor の設定済み tenant が `TenantId` として記録されている。
single-tenant operation に、正準な single-tenant sentinel が記録されている。
tenant の概念を持たない operation に、正準な no-tenant sentinel が記録されている。
安定した匿名 scope がない場合に、server 発行の全体で一意な key と proof が使われ、proof のない別 client へ保存済み response が返らないことが漏洩テストで検証されている。
request fingerprint、初回 response、業務の書き込みが、同じ Npgsql transaction で確定している。
同じ scope と key の同時要求が一件だけ業務を書き、異なる fingerprint が conflict になっている。
別の actor scope から保存済み response を取得できないことが、漏洩テストで検証されている。

### 禁止事項
冪等 key の競合を、Dapper の事前 SELECT だけで判定すること。
request fingerprint または初回 response を、業務の書き込みと別に commit すること。
actor scope を照合せずに、保存済み response を返すこと。
匿名または system の異なる主体を、汎用の actor sentinel へまとめること。
未検証の tenant claim、host、route、session、client 入力から `TenantId` を構築すること。
multi-tenant operation に single-tenant sentinel または no-tenant sentinel を使うこと。
single-tenant operation に `TenantId` または no-tenant sentinel を使うこと。
tenant の概念を持たない operation に `TenantId` または single-tenant sentinel を使うこと。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せず、安定した scope のない匿名要求の保存済み response を返すこと。

### 行動
`applied_requests` に複合一意制約を置き、Npgsql の同じ transaction で業務の書き込み、fingerprint、response を保存する。
認証済み actor ID、匿名の安定した opaque scope、logical system actor ID を種別ごとに記録する。
multi-tenant operation の認証済み要求は検証済み tenant claim、membership、または authorization 済み選択から `TenantId` を構築する。
multi-tenant operation の匿名要求は検証済み host または route と session/client tenant context から、system 要求は logical actor の設定から `TenantId` を構築する。
single-tenant operation に正準な single-tenant sentinel を使う。
tenant の概念を持たない operation に正準な no-tenant sentinel を使う。
安定した匿名 scope がなければ、server 発行の全体で一意な key と proof を発行し、proof を応答取得時に検証する。
同じ scope と key を並行に送る競合テストと、全 actor/tenant 種別の scope 分離、未検証 tenant の拒否、multi-tenant の `TenantId`、single-tenant sentinel、no-tenant sentinel の相互混同拒否、proof のない別 client からの response 取得拒否を確かめる漏洩テストを実行する。

## durable inbox

### 要求
受領した event は、consumer contract または subscription scope と event ID の複合一意制約を持つ durable inbox に記録する。
payload を durable inbox へ commit した後だけ、source へ upstream delivery ack を返す。
処理結果と inbox の処理済み記録は、同じ Npgsql transaction で確定する。
処理 item の inbox processing completion と削除は、transaction の commit が成功した後だけ行う。
inbox が容量上限に達した場合は、受領せず nack または再試行可能な失敗を返す。
inbox の使用量、上限、backlog、nack を監視へ出す。

### 根拠
payload の commit 前に upstream delivery ack を返さず、満杯を nack すれば、前段の停止で event を source から失わない。
処理結果と処理済み記録の commit 前に inbox processing completion を行わなければ、後段の停止で item を再処理できる。

### 完了条件
durable inbox が scope と event ID の複合一意制約を持っている。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
処理結果と処理済み記録が、同じ Npgsql transaction で確定している。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
payload commit の前後と処理結果 commit の前後で停止し、前段は source から再配送され、後段は inbox item が再処理され、結果が一度分になることが結合テストで検証されている。
容量上限で nack または再試行可能な失敗になることが結合テストで検証されている。
inbox の使用量、上限、backlog、nack が監視されている。

### 禁止事項
payload の durable inbox への commit より前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit より前に、inbox processing completion または処理 item の削除を行うこと。
容量上限を超えた event を受領済みとして捨てること。

### 行動
payload を durable inbox へ commit してから、upstream delivery ack を返す。
処理結果と処理済み記録を同じ Npgsql transaction で書き、commit 成功後に inbox processing completion を確定して処理 item を完了または削除する。
容量を予約できない場合は nack または再試行可能な失敗を返し、使用量、backlog、nack を記録する。
payload commit と処理結果 commit の各直前・直後の停止、および容量上限を再現する結合テストを実行する。

## 並行更新の表面

### 要求
版の衝突は、状態の遷移をイベントとして追記し、version への一意制約違反として検出する。
制約違反は競合の Result に写す。

### 根拠
状態カラムを compare-and-set の UPDATE で上書きすると、遷移の事実そのものが行として残らず、persistence が定める事実を追記する規律に反する。
遷移をイベントとして追記し `(OrderId, Version)` に一意制約を課せば、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
Npgsql は制約違反を `PostgresException` で送出し、`SqlState` が `PostgresErrorCodes.UniqueViolation` のとき一意制約違反と判別できる。
制約違反を検出して競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
version の衝突が、`(OrderId, Version)` の一意制約違反として検出されている。
競合が、Result で返されている。
状態の遷移が、行の追記で表されている。

### 禁止事項
状態カラムを直接 UPDATE で上書きし、遷移の事実を追記せずに競合を検出すること。
version の一意制約違反を、検出せずに上書きすること。

### 行動
状態の遷移を `order_events` のようなイベント表への INSERT で表し、version を `(OrderId, Version)` の一意制約の対象に含める。
挿入が一意制約違反で失敗したら、競合の Result に写す。

### 例
競合は閉じた型付き失敗で表す。遷移をイベントとして追記し、`(OrderId, Version)` の一意制約違反を競合へ写す。

```csharp
public abstract record WriteError { private WriteError() { } public sealed record Conflict : WriteError; }
```

```csharp
try
{
    await connection.ExecuteAsync(
        "INSERT INTO order_events (order_id, version, payload) VALUES (@OrderId, @Version, @Payload)",
        new { OrderId = id, Version = expectedVersion + 1, Payload = payload }, transaction);
    return Result.Success<Order, WriteError>(order);
}
catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
{
    return Result.Failure<Order, WriteError>(new WriteError.Conflict());
}
```
