# sqlx

用途は、SQL を型で扱いながら書く永続化アクセス層である。
採用は、Rust は sqlx である。
判断基準は、SQL を隠さず、事実の形がそのまま型に写ることである。フル ORM は SQL を不透明にしたり、変更追跡で確定の時点を暗黙にしたりするため採らない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 型付き SQL

### 要求
永続化は sqlx で書き、`query!`・`query_as!` のコンパイル時検証を使う。
sqlx の `offline` feature を有効化し、リポジトリの検証入口は offline の検証データで検証する。
`sqlx.toml` を使う場合は sqlx 側で `sqlx-toml` feature を明示的に有効化し、migration table 名と migration hash の無視文字は既定から変更しない。

### 根拠
sqlx はコンパイル時に開発の DB へ接続し、SQL を DB 自身に検証させる。
SQL を隠す抽象を入れないので、事実の形がそのまま型に写る。
sqlx の `offline` feature を有効化して offline の検証データをリポジトリの検証入口で照合すれば、スキーマと SQL のずれがビルドで止まる。
sqlx-cli の `sqlx migrate add` は既定で forward-only の migration ファイルを生成し、`sqlx migrate run` が適用済みの履歴を DB 側で追跡する。
`sqlx.toml` の migration table 名と migration hash の無視文字を既定から変えなければ、sqlx と sqlx-cli の設定差で検証対象と適用履歴がずれない。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が sqlx で書かれ、`query!`・`query_as!` のコンパイル時検証が効いている。
sqlx の `offline` feature が有効で、リポジトリの検証入口が offline の検証データで検証している。
`sqlx.toml` を使う場合は sqlx 側で `sqlx-toml` feature が有効で、migration table 名と migration hash の無視文字が既定から変更されていない。
フル ORM を使っていない。
schema の変更が、sqlx-cli の `sqlx migrate` で forward-only の migration として適用されている。

### 禁止事項
フル ORM で、SQL を隠すこと。
SQL の値を、文字列の連結で組み立てること。

### 行動
SQL を `query!`・`query_as!` で書き、sqlx の `offline` feature を有効化して、`cargo sqlx prepare` の検証データをリポジトリの検証入口で照合する。
`sqlx.toml` を使う場合は sqlx 側で `sqlx-toml` feature を明示的に有効化し、migration table 名と migration hash の無視文字を既定から変更しない。
schema の変更は `sqlx migrate add` で migration ファイルを作り、`sqlx migrate run` で適用する。

### 例
SQL を文字列で組み立てると型と schema が検査されず、値の連結は injection を招く。

```rust
let sql = format!("SELECT * FROM orders WHERE id = '{id}'");
```

`query_as!` なら schema と型をコンパイル時に検証し、値を parameter で渡せる。

```rust
let order = sqlx::query_as!(
    OrderRecord,
    "SELECT order_id AS id, status, version FROM order_states WHERE order_id = $1",
    id,
)
.fetch_one(&pool)
.await?;
```

## 書き込みパス

### 要求
composition が所有する UnitOfWork は sqlx の Transaction で実装し、store は受け取った Transaction の中で書く。

### 根拠
store が Transaction を握ると、業務判断と確定の制御が混ざり、複数の store をまたぐ一つの確定ができない。
composition が Transaction を所有し store が借りた Transaction の中で書けば、確定点が一つに定まる。
一つの確定点に集めれば、現在情報の書き込み、必要な業務イベントの追記、公開する integration event の outbox 記録を、同一のパスで確定できる。

### 完了条件
UnitOfWork が、composition の所有する sqlx の Transaction で実装されている。
store が、受け取った Transaction の中で書いている。
確定点が、一つである。

### 禁止事項
store が、Transaction の begin・commit を所有すること。

### 行動
composition で Transaction を begin し、store に渡して書かせ、composition で commit する。

### 例
組立点が transaction を所有し、現在情報の書き込みと、公開する integration event の outbox 記録を同じ書き込みパスで確定する。store は受け取った transaction の中でだけ書く。

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
[transaction](../../concerns/transaction/README.md) が定める複合 scope と同じ確定点を PostgreSQL の制約と sqlx の Transaction に写せば、同時要求の競合と部分確定を DB で止められる。
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

## 並行更新の表面

### 要求
同じ集約への同時の更新は [transaction](../../concerns/transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従って制御し、版で衝突を検出する集約では競合の Result に写す。
版で衝突を検出し、正本が現在情報の行である集約では、`UPDATE` の `WHERE` で期待する version を比較して同じ文で version を進め、影響行数が 0 のときを競合とする。
版で衝突を検出し、正本が追記する事実の関係である集約では、名前を付けた `(集約の識別子, version)` の UNIQUE 制約の違反だけを競合とし、他の制約違反は競合に写さない。
版で競合を検出する集約の現在情報を書く全ての書き込み経路は、正本に応じた同じ検出を通す。
必要な業務イベントは、現在情報の書き込みと同じ sqlx の Transaction で追記する。
業務イベントを必要としない現在情報の更新は、集約に定めた競合制御を通し、業務イベントを追記せず `UPDATE` で書いてよい。
競合または失敗のとき、composition は Transaction を commit せず、現在情報の更新、業務イベントの追記、outbox の記録のどれも残さない。
公開する integration event は、業務イベントの追記と別に、現在情報の書き込みと同じ Transaction で outbox へ記録する。

### 根拠
同時の更新を検出しなければ、後の書き込みが前の更新を黙って失わせる。
version を `WHERE` で比較して同じ文で進める楽観的ロックなら、同じ version を期待する二つの更新のうち片方だけが行を更新し、他方は影響行数 0 になる。
正本が追記する事実の関係なら、`(集約の識別子, version)` に UNIQUE 制約を課すと、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
一意制約違反は冪等 key や重複を許さない値の制約でも起きるので、違反の種類だけで競合と判定すると、version 以外の違反を競合へ誤って写す。
sqlx の `DatabaseError::constraint()` は、PostgreSQL の driver が違反した制約の名前を返すので、version の制約に付けた名前と照合すれば競合だけを識別できる。
どちらで検出するかは正本が何かで決まるので、書き込みごとに選ばない。
業務イベントが必要かどうかは [data](../../principles/data/preserve-facts-and-current-state.md) の「業務事実と現在情報を分けて保持する」に従う。
プロフィールの表示名や現在の所属のような可変な現在情報は、業務イベントを必要としない限り、`UPDATE` で更新してよい。
現在情報の更新と必要な業務イベントの追記を同じ Transaction で確定すれば、片方だけが確定して現在情報と事実が食い違うことがない。
競合や失敗で commit しなければ、競合した更新の書き込みは現在情報にも業務イベントにも outbox にも残らない。
業務イベントは集約の内側で起きた事実であり、コンテキストの外へ公開する integration event の outbox 記録とは別なので、一方を他方の代わりにしない。
domain event と integration event の区別は [messaging](../../concerns/messaging/domain-integration-events.md) に従う。
影響行数 0 と制約違反を競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
版で衝突を検出し、正本が現在情報の行である集約で、同じ version を期待する並行更新の片方だけが確定し、他方が競合の Result で返されている。
版で衝突を検出する集約で、条件付き `UPDATE` の影響行数 0 が、競合の Result に写されている。
版で衝突を検出し、正本が追記する事実の関係である集約で、同じ version の重複追記が、名前を付けた `(集約の識別子, version)` の UNIQUE 制約の違反として検出され、競合の Result で返されている。
version の制約以外の制約違反が、競合の Result に写されていない。
版で衝突を検出する集約の全ての書き込み経路で、古い version を期待した更新が競合になり、現在情報が変わっていない。
必要な業務イベントを伴う更新で、現在情報の更新と業務イベントの追記が、同じ sqlx の Transaction で確定している。
競合または失敗した更新が、現在情報の更新も業務イベントの追記も outbox の記録も残していない。
業務イベントを必要としない現在情報の更新が、集約に定めた競合制御を通し、業務イベントの追記なしで `UPDATE` により書かれている。
公開する integration event の outbox への記録が、業務イベントの追記と別に、現在情報の書き込みと同じ Transaction で行われている。

### 禁止事項
集約に定めた競合制御を通さず、同時の更新を上書きすること。
版で衝突を検出する集約で、条件付き `UPDATE` の影響行数 0 を、競合として扱わず成功にすること。
必要な業務イベントを、事実を追記しない現在情報の `UPDATE` だけで表すこと。
現在情報の更新と必要な業務イベントの追記を、別々の Transaction で確定すること。
競合または失敗した更新の、現在情報の更新、業務イベントの追記、outbox の記録の一部だけを commit すること。
version の制約以外の制約違反を、競合の Result に写すこと。
outbox への integration event の記録を、必要な業務イベントの追記の代わりにすること。

### 行動
上位の書き込みパスに従って集約の競合制御を確認し、版で衝突を検出する集約だけに、正本に応じた version の比較を実装する。
版で衝突を検出する現在情報の行は、`SET` で `version = version + 1` に進め、`WHERE` に `version = $2` を含む `UPDATE` で書き、`rows_affected()` が 0 なら `WriteError::Conflict` を返す。
版で衝突を検出する事実の関係は、`(集約の識別子, version)` に名前を付けた UNIQUE 制約を置き、`sqlx::Error::Database` の `is_unique_violation()` が真で `constraint()` がその名前と一致するときだけ `WriteError::Conflict` に写し、他の制約違反は `WriteError::Database` で返す。
更新ごとに必要な業務イベントを確かめ、必要なら同じ Transaction の中で業務イベントの関係へ INSERT する。
競合または失敗では、composition が Transaction を commit せず破棄する。
版で衝突を検出する集約では、同じ version の並行更新、古い version の各経路からの更新、version 以外の一意制約違反を結合テストで再現する。
親の行を排他する集約では、全経路での直列化と排他後の検証を結合テストで確認し、version の追加を要求しない。
現在情報の更新と業務イベントの追記の間の失敗は、どちらの集約でも再現する。

### 例
競合と失敗は、閉じた型付きの失敗で表す。

```rust
#[derive(thiserror::Error, Debug)]
pub enum WriteError {
    #[error("conflict")]
    Conflict,
    #[error("database")]
    Database(#[from] sqlx::Error),
}
```

注文の同一性は `orders` に、更新する現在情報は `order_states(order_id, status, version)` に分けている。
取消の理由と時刻を残す義務があるとき、現在情報の `UPDATE` だけで取消を表すと、取消の事実が欠落する。

```rust
let updated = sqlx::query!(
    "UPDATE order_states SET status = 'cancelled', version = version + 1 WHERE order_id = $1 AND version = $2",
    order_id,
    expected_version,
)
.execute(&mut **transaction)
.await?;
if updated.rows_affected() == 0 {
    return Err(WriteError::Conflict);
}
Ok(())
```

version を比較する `UPDATE` と取消の事実の `INSERT` を、同じ Transaction に置く。
影響行数 0 の競合は `INSERT` の前に返す。
composition は Err の Result を受けたら commit せず Transaction を破棄するので、どちらの書き込みも残らない。

```rust
let updated = sqlx::query!(
    "UPDATE order_states SET status = 'cancelled', version = version + 1 WHERE order_id = $1 AND version = $2",
    order_id,
    expected_version,
)
.execute(&mut **transaction)
.await?;
if updated.rows_affected() == 0 {
    return Err(WriteError::Conflict);
}
sqlx::query!(
    "INSERT INTO order_cancellations (order_id, reason_code, occurred_at) VALUES ($1, $2, $3)",
    order_id,
    reason_code,
    occurred_at,
)
.execute(&mut **transaction)
.await?;
Ok(())
```

正本が追記する事実の関係で、一意制約違反をすべて競合へ写すと、`(account_id, version)` 以外の一意制約の違反まで競合として返される。

```rust
let result = sqlx::query!(
    "INSERT INTO ledger_entries (account_id, version, amount) VALUES ($1, $2, $3)",
    account_id,
    expected_version + 1,
    amount,
)
.execute(&mut **transaction)
.await;
match result {
    Ok(_) => Ok(()),
    Err(sqlx::Error::Database(database_error)) if database_error.is_unique_violation() => {
        Err(WriteError::Conflict)
    }
    Err(error) => Err(error.into()),
}
```

名前を付けた `(account_id, version)` の UNIQUE 制約と、違反した制約の名前が一致するときだけ競合へ写し、他の制約違反は `WriteError::Database` で返す。

```rust
const LEDGER_VERSION_CONSTRAINT: &str = "ledger_entries_account_id_version_key";

let result = sqlx::query!(
    "INSERT INTO ledger_entries (account_id, version, amount) VALUES ($1, $2, $3)",
    account_id,
    expected_version + 1,
    amount,
)
.execute(&mut **transaction)
.await;
match result {
    Ok(_) => Ok(()),
    Err(sqlx::Error::Database(database_error))
        if database_error.is_unique_violation()
            && database_error.constraint() == Some(LEDGER_VERSION_CONSTRAINT) =>
    {
        Err(WriteError::Conflict)
    }
    Err(error) => Err(error.into()),
}
```
