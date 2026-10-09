# Npgsql

用途は、PostgreSQL へ接続し、transaction の確定と制約違反の判別を担う data provider である。
採用は、C# は Npgsql である。
判断基準は、composition が所有する transaction で確定点を一つにでき、一意制約違反を SqlState と違反した制約の名前で判別できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 書き込みパス

### 要求
composition が所有する UnitOfWork は Npgsql の transaction で実装し、store は受け取った transaction の中で書く。

### 根拠
store が transaction を握ると、業務判断と確定の制御が混ざり、複数の store をまたぐ一つの確定ができない。
composition が transaction を所有し store が受け取った transaction の中で書けば、確定点が一つに定まる。
一つの確定点に集めれば、現在情報の書き込み、必要な業務イベントの追記、公開する integration event の outbox 記録を、同一のパスで確定できる。

### 完了条件
UnitOfWork が、composition の所有する Npgsql の transaction で実装されている。
store が、受け取った transaction の中で書いている。
確定点が、一つである。

### 禁止事項
store が、transaction の begin・commit を所有すること。

### 行動
composition で transaction を begin し、store に渡して書かせ、composition で commit する。

### 例
組立点が transaction を所有し、現在情報の書き込みと、公開する integration event の outbox 記録を同じ経路で書いた後に一度だけ確定する。

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
同じ集約への同時の更新は [transaction](../../concerns/transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従って制御し、版で衝突を検出する集約では競合の Result に写す。
版で衝突を検出し、正本が現在情報の行である集約では、`UPDATE` の `WHERE` で期待する version を比較して同じ文で version を進め、影響行数が 0 のときを競合とする。
版で衝突を検出し、正本が追記する事実の関係である集約では、名前を付けた `(集約の識別子, version)` の一意制約の違反だけを競合とし、他の制約違反は競合に写さない。
版で競合を検出する集約の現在情報を書く全ての書き込み経路は、正本に応じた同じ検出を通す。
必要な業務イベントは、現在情報の書き込みと同じ Npgsql transaction で追記する。
業務イベントを必要としない現在情報の更新は、集約に定めた競合制御を通し、業務イベントを追記せず `UPDATE` で書いてよい。
競合または失敗のとき、composition は transaction を commit せず、現在情報の更新、業務イベントの追記、outbox の記録のどれも残さない。
公開する integration event は、業務イベントの追記と別に、現在情報の書き込みと同じ transaction で outbox へ記録する。

### 根拠
同時の更新を検出しなければ、後の書き込みが前の更新を黙って失わせる。
version を `WHERE` で比較して同じ文で進める楽観的ロックなら、同じ version を期待する二つの更新のうち片方だけが行を更新し、他方は影響行数 0 になる。
Dapper の `ExecuteAsync` は影響行数を返すので、0 を競合と判別できる。
正本が追記する事実の関係なら、`(集約の識別子, version)` に一意制約を課すと、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
一意制約違反は冪等 key や重複を許さない値の制約でも起きるので、違反の種類だけで競合と判定すると、version 以外の違反を競合へ誤って写す。
Npgsql は制約違反を `PostgresException` で送出し、`SqlState` が `PostgresErrorCodes.UniqueViolation` のとき一意制約違反と判別できる。
`PostgresException.ConstraintName` は違反した制約の名前を返すので、version の制約に付けた名前と照合すれば競合だけを識別できる。
どちらで検出するかは正本が何かで決まるので、書き込みごとに選ばない。
業務イベントが必要かどうかは [data](../../principles/data/preserve-facts-and-current-state.md) の「業務事実と現在情報を分けて保持する」に従う。
プロフィールの表示名や現在の所属のような可変な現在情報は、業務イベントを必要としない限り、`UPDATE` で更新してよい。
現在情報の更新と必要な業務イベントの追記を同じ transaction で確定すれば、片方だけが確定して現在情報と事実が食い違うことがない。
競合や失敗で commit しなければ、競合した更新の書き込みは現在情報にも業務イベントにも outbox にも残らない。
業務イベントは集約の内側で起きた事実であり、コンテキストの外へ公開する integration event の outbox 記録とは別なので、一方を他方の代わりにしない。
domain event と integration event の区別は [messaging](../../concerns/messaging/domain-integration-events.md) に従う。
影響行数 0 と制約違反を競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
版で衝突を検出し、正本が現在情報の行である集約で、同じ version を期待する並行更新の片方だけが確定し、他方が競合の Result で返されている。
版で衝突を検出する集約で、条件付き `UPDATE` の影響行数 0 が、競合の Result に写されている。
版で衝突を検出し、正本が追記する事実の関係である集約で、同じ version の重複追記が、名前を付けた `(集約の識別子, version)` の一意制約の違反として検出され、競合の Result で返されている。
version の制約以外の制約違反が、競合の Result に写されていない。
版で衝突を検出する集約の全ての書き込み経路で、古い version を期待した更新が競合になり、現在情報が変わっていない。
必要な業務イベントを伴う更新で、現在情報の更新と業務イベントの追記が、同じ Npgsql transaction で確定している。
競合または失敗した更新が、現在情報の更新も業務イベントの追記も outbox の記録も残していない。
業務イベントを必要としない現在情報の更新が、集約に定めた競合制御を通し、業務イベントの追記なしで `UPDATE` により書かれている。
公開する integration event の outbox への記録が、業務イベントの追記と別に、現在情報の書き込みと同じ transaction で行われている。

### 禁止事項
集約に定めた競合制御を通さず、同時の更新を上書きすること。
版で衝突を検出する集約で、条件付き `UPDATE` の影響行数 0 を、競合として扱わず成功にすること。
必要な業務イベントを、事実を追記しない現在情報の `UPDATE` だけで表すこと。
現在情報の更新と必要な業務イベントの追記を、別々の transaction で確定すること。
競合または失敗した更新の、現在情報の更新、業務イベントの追記、outbox の記録の一部だけを commit すること。
version の制約以外の制約違反を、競合の Result に写すこと。
outbox への integration event の記録を、必要な業務イベントの追記の代わりにすること。

### 行動
上位の書き込みパスに従って集約の競合制御を確認し、版で衝突を検出する集約だけに、正本に応じた version の比較を実装する。
版で衝突を検出する現在情報の行は、`SET` で `version = version + 1` に進め、`WHERE` に `version = @ExpectedVersion` を含む `UPDATE` で書き、`ExecuteAsync` の戻り値が 0 なら `WriteError.Conflict` を返す。
版で衝突を検出する事実の関係は、`(集約の識別子, version)` に名前を付けた一意制約を置き、`PostgresException` の `SqlState` が `PostgresErrorCodes.UniqueViolation` で `ConstraintName` がその名前と一致するときだけ `WriteError.Conflict` を返し、他の制約違反は競合に写さない。
更新ごとに必要な業務イベントを確かめ、必要なら同じ transaction の中で業務イベントの関係へ INSERT する。
競合または失敗では、composition が transaction を commit せず破棄する。
版で衝突を検出する集約では、同じ version の並行更新、古い version の各経路からの更新、version 以外の一意制約違反を結合テストで再現する。
親の行を排他する集約では、全経路での直列化と排他後の検証を結合テストで確認し、version の追加を要求しない。
現在情報の更新と業務イベントの追記の間の失敗は、どちらの集約でも再現する。

### 例
競合は、閉じた型付き失敗で表す。

```csharp
public abstract record WriteError
{
    private WriteError() { }

    public sealed record Conflict : WriteError;
}
```

注文の同一性は `orders` に、更新する現在情報は `order_states(order_id, status, version)` に分けている。
取消の理由と時刻を残す義務があるとき、現在情報の `UPDATE` だけで取消を表すと、取消の事実が欠落する。

```csharp
var updated = await connection.ExecuteAsync(
    "UPDATE order_states SET status = 'cancelled', version = version + 1 WHERE order_id = @OrderId AND version = @ExpectedVersion",
    new { OrderId = id, ExpectedVersion = expectedVersion },
    transaction
);
return updated == 0
    ? Result.Failure<Order, WriteError>(new WriteError.Conflict())
    : Result.Success<Order, WriteError>(order);
```

version を比較する `UPDATE` と取消の事実の `INSERT` を、同じ transaction に置く。
影響行数 0 の競合は `INSERT` の前に返す。
composition は Failure の Result と例外のどちらでも commit せず transaction を破棄するので、どちらの書き込みも残らない。

```csharp
var updated = await connection.ExecuteAsync(
    "UPDATE order_states SET status = 'cancelled', version = version + 1 WHERE order_id = @OrderId AND version = @ExpectedVersion",
    new { OrderId = id, ExpectedVersion = expectedVersion },
    transaction
);
if (updated == 0)
{
    return Result.Failure<Order, WriteError>(new WriteError.Conflict());
}
await connection.ExecuteAsync(
    "INSERT INTO order_cancellations (order_id, reason_code, occurred_at) VALUES (@OrderId, @ReasonCode, @OccurredAt)",
    new { OrderId = id, ReasonCode = reasonCode, OccurredAt = occurredAt },
    transaction
);
return Result.Success<Order, WriteError>(order);
```

正本が追記する事実の関係で、一意制約違反をすべて競合へ写すと、`(account_id, version)` 以外の一意制約の違反まで競合として返される。

```csharp
try
{
    await connection.ExecuteAsync(
        "INSERT INTO ledger_entries (account_id, version, amount) VALUES (@AccountId, @Version, @Amount)",
        new { AccountId = id, Version = expectedVersion + 1, Amount = amount },
        transaction
    );
    return Result.Success<Account, WriteError>(account);
}
catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
{
    return Result.Failure<Account, WriteError>(new WriteError.Conflict());
}
```

名前を付けた `(account_id, version)` の一意制約と、違反した制約の名前が一致するときだけ競合へ写し、他の制約違反は `when` で捕捉せず競合に写さない。

```csharp
const string LedgerVersionConstraint = "ledger_entries_account_id_version_key";

try
{
    await connection.ExecuteAsync(
        "INSERT INTO ledger_entries (account_id, version, amount) VALUES (@AccountId, @Version, @Amount)",
        new { AccountId = id, Version = expectedVersion + 1, Amount = amount },
        transaction
    );
    return Result.Success<Account, WriteError>(account);
}
catch (PostgresException exception)
    when (exception.SqlState == PostgresErrorCodes.UniqueViolation
        && exception.ConstraintName == LedgerVersionConstraint)
{
    return Result.Failure<Account, WriteError>(new WriteError.Conflict());
}
```
