# retention

## 概要
retention は、Rust で永続化と共有される状態を扱う実現軸である。
principles の [data](../../principles/data.md) が定める事実の追記と、concerns の [persistence](../../concerns/persistence.md) が定める永続データの設計・[transaction](../../concerns/transaction.md) が定める一つの書き込みパスと確定点を、Rust の機構で満たす。
並行更新の表面は、状態の遷移をイベントの追記として表し、version の一意制約で衝突を検出する。

## 型付き SQL

### 要求
永続化は sqlx で書き、`query!`・`query_as!` のコンパイル時検証を使う。
リポジトリの検証入口は offline の検証データで検証し、フル ORM を使わない。
schema の変更は sqlx-cli の `sqlx migrate` で、forward-only の migration として適用する。

### 根拠
sqlx はコンパイル時に開発の DB へ接続し、SQL を DB 自身に検証させる。
SQL を隠す抽象を入れないので、事実の形がそのまま型に写る。
offline の検証データをリポジトリの検証入口で照合すれば、スキーマと SQL のずれがビルドで止まる。
sqlx-cli の `sqlx migrate add` は既定で forward-only の migration ファイルを生成し、`sqlx migrate run` が適用済みの履歴を DB 側で追跡する。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が sqlx で書かれ、`query!`・`query_as!` のコンパイル時検証が効いている。
リポジトリの検証入口が、offline の検証データで検証している。
フル ORM を使っていない。
schema の変更が、sqlx-cli の `sqlx migrate` で forward-only の migration として適用されている。

### 禁止事項
フル ORM で、SQL を隠すこと。
SQL の値を、文字列の連結で組み立てること。

### 行動
SQL を `query!`・`query_as!` で書き、`cargo sqlx prepare` の検証データをリポジトリの検証入口で照合する。
schema の変更は `sqlx migrate add` で migration ファイルを作り、`sqlx migrate run` で適用する。

### 例
SQL を文字列で組み立てると型と schema が検査されず、値の連結は injection を招く。

```rust
let sql = format!("SELECT * FROM orders WHERE id = '{id}'");
```

`query_as!` なら schema と型をコンパイル時に検証し、値を parameter で渡せる。

```rust
let order = sqlx::query_as!(Order, "SELECT id, status, version FROM orders WHERE id = $1", id)
    .fetch_one(&pool).await?;
```

## 並行更新の表面

### 要求
版の衝突は、状態の遷移をイベントとして追記し、version への UNIQUE 制約違反として検出する。
制約違反は競合の Result に写す。

### 根拠
状態カラムを compare-and-set の UPDATE で上書きすると、遷移の事実そのものが行として残らず、persistence が定める事実を追記する規律に反する。
遷移をイベントとして追記し `(order_id, version)` に UNIQUE 制約を課せば、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
制約違反を検出して競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
version の衝突が、`(order_id, version)` の UNIQUE 制約違反として検出されている。
競合が、Result で返されている。
状態の遷移が、行の追記で表されている。

### 禁止事項
状態カラムを直接 UPDATE で上書きし、遷移の事実を追記せずに競合を検出すること。
version の一意制約違反を、検出せずに上書きすること。

### 行動
状態の遷移を `order_events` のようなイベント表への INSERT で表し、version を `(order_id, version)` の UNIQUE 制約の対象に含める。
挿入が一意制約違反で失敗したら、競合の Result に写す。

### 例
競合を型付きの失敗にし、状態の遷移を event として追記する。`(order_id, version)` の一意制約違反を競合へ写す。

```rust
#[derive(thiserror::Error, Debug)]
pub enum WriteError { #[error("conflict")] Conflict }

let result = sqlx::query!(
    "INSERT INTO order_events (order_id, version, payload) VALUES ($1, $2, $3)",
    order_id, expected_version + 1, payload,
).execute(&mut *transaction).await;
match result {
    Ok(_) => Ok(()),
    Err(sqlx::Error::Database(database_error)) if database_error.is_unique_violation() => Err(WriteError::Conflict),
    Err(error) => Err(error.into()),
}
```

## 書き込みパス

### 要求
composition が所有する UnitOfWork は sqlx の Transaction で実装し、store は受け取った Transaction の中で書く。

### 根拠
store が Transaction を握ると、業務判断と確定の制御が混ざり、複数の store をまたぐ一つの確定ができない。
composition が Transaction を所有し store が借りた Transaction の中で書けば、確定点が一つに定まる。
一つの確定点に集めれば、状態とイベントを同一のパスで記録できる。

### 完了条件
UnitOfWork が、composition の所有する sqlx の Transaction で実装されている。
store が、受け取った Transaction の中で書いている。
確定点が、一つである。

### 禁止事項
store が、Transaction の begin・commit を所有すること。

### 行動
composition で Transaction を begin し、store に渡して書かせ、composition で commit する。

### 例
組立点が transaction を所有し、状態と event を同じ書き込みパスで確定する。store は受け取った transaction の中でだけ書く。

```rust
let mut transaction = pool.begin().await?;
order_store.insert(&mut transaction, &order).await?;
outbox.add(&mut transaction, OrderPlaced::from(&order)).await?;
transaction.commit().await?;

impl OrderStore {
    async fn insert(&self, transaction: &mut Transaction<'_, Postgres>, order: &Order) -> Result<()> {
        sqlx::query!(/* ... */).execute(&mut **transaction).await?; Ok(())
    }
}
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
request fingerprint と初回 response は、冪等 key と業務の書き込みと同じ sqlx の Transaction で保存する。
同じ scope と key の再実行は、fingerprint が一致する場合だけ保存済み response を返し、不一致なら conflict を返す。

### 根拠
[transaction](../../concerns/transaction.md) が定める複合 scope と同じ確定点を PostgreSQL の制約と sqlx の Transaction に写せば、同時要求の競合と部分確定を DB で止められる。
actor scope を検索条件へ含めれば、別の主体へ保存済み response を返さない。
actor の種別ごとに [transaction](../../concerns/transaction.md) の scope を写せば、匿名や system を汎用 sentinel へ潰さない。
tenant の出所を認証、認可、host、route、logical actor の検証済み context に限れば、要求者が指定した未検証 tenant へ scope を切り替えられない。

### 完了条件
operation、actor scope、tenant、key の全列が NOT NULL で、複合一意制約を持っている。
認証済み actor、匿名の安定した opaque scope、logical system actor が actor の種別に応じて記録されている。
multi-tenant operation に、認証済み tenant、匿名の検証済み host または route と session/client tenant context、logical system actor の設定済み tenant が `TenantId` として記録されている。
single-tenant operation に、正準な single-tenant sentinel が記録されている。
tenant の概念を持たない operation に、正準な no-tenant sentinel が記録されている。
安定した匿名 scope がない場合に、server 発行の全体で一意な key と proof が使われ、proof のない別 client へ保存済み response が返らないことが漏洩テストで検証されている。
request fingerprint、初回 response、業務の書き込みが、同じ sqlx の Transaction で確定している。
同じ scope と key の同時要求が一件だけ業務を書き、異なる fingerprint が conflict になっている。
別の actor scope から保存済み response を取得できないことが、漏洩テストで検証されている。

### 禁止事項
冪等 key の競合を、sqlx の事前 SELECT だけで判定すること。
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
`applied_requests` に複合一意制約を置き、sqlx の同じ Transaction で業務の書き込み、fingerprint、response を保存する。
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
処理結果と inbox の処理済み記録は、同じ sqlx の Transaction で確定する。
処理 item の inbox processing completion と削除は、Transaction の commit が成功した後だけ行う。
inbox が容量上限に達した場合は、受領せず nack または再試行可能な失敗を返す。
inbox の使用量、上限、backlog、nack を監視へ出す。

### 根拠
payload の commit 前に upstream delivery ack を返さず、満杯を nack すれば、前段の停止で event を source から失わない。
処理結果と処理済み記録の commit 前に inbox processing completion を行わなければ、後段の停止で item を再処理できる。

### 完了条件
durable inbox が scope と event ID の複合一意制約を持っている。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
処理結果と処理済み記録が、同じ sqlx の Transaction で確定している。
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
処理結果と処理済み記録を同じ sqlx の Transaction で書き、commit 成功後に inbox processing completion を確定して処理 item を完了または削除する。
容量を予約できない場合は nack または再試行可能な失敗を返し、使用量、backlog、nack を記録する。
payload commit と処理結果 commit の各直前・直後の停止、および容量上限を再現する結合テストを実行する。

## 一時データ

### 要求
session や cache のような寿命の短い共有状態は永続化の DB と分けて扱い、Valkey への接続は fred で行う。

### 根拠
fred は Valkey と Redis の両方を公式に対象にした非同期クライアントで、接続の pooling と backoff 付きの自動再接続を組み込みで持つ。
接続を fred の一つの機構に固定すれば、寿命の短い共有状態への接続の作法が Rust の中で割れない。

### 完了条件
寿命の短い一時データが、永続化の DB と分けて Valkey で扱われている。
Valkey への接続が、fred で行われている。

### 禁止事項
寿命の短い一時データを、永続化の DB に置くこと。

### 行動
一時データを Valkey に置き、接続を fred で行う。

## 参照
事実の追記は [data](../../principles/data.md)、永続データの設計は [persistence](../../concerns/persistence.md)、確定点は [transaction](../../concerns/transaction.md)、UnitOfWork の所有は [structure/core/composition](../../structure/core/composition.md)、永続化の置き場は [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。
