# retention

## 概要
retention は、Rust で永続化と共有される状態を扱う実現軸である。
principles の [data](../../principles/data.md) が定める事実の追記と、concerns の [persistence](../../concerns/persistence.md) が定める永続データの設計・[transaction](../../concerns/transaction.md) が定める一つの書き込みパスと確定点を、Rust の機構で満たす。
並行更新の表面は、状態の遷移をイベントの追記として表し、version の一意制約で衝突を検出する。

## 型付き SQL

### 要求
永続化は sqlx で書き、`query!`・`query_as!` のコンパイル時検証を使う。
CI は offline の検証データで検証し、フル ORM を使わない。
schema の変更は sqlx-cli の `sqlx migrate` で、forward-only の migration として適用する。

### 根拠
sqlx はコンパイル時に開発の DB へ接続し、SQL を DB 自身に検証させる。
SQL を隠す抽象を入れないので、事実の形がそのまま型に写る。
offline の検証データを CI で照合すれば、スキーマと SQL のずれがビルドで止まる。
sqlx-cli の `sqlx migrate add` は既定で forward-only の migration ファイルを生成し、`sqlx migrate run` が適用済みの履歴を DB 側で追跡する。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が sqlx で書かれ、`query!`・`query_as!` のコンパイル時検証が効いている。
CI が、offline の検証データで検証している。
フル ORM を使っていない。
schema の変更が、sqlx-cli の `sqlx migrate` で forward-only の migration として適用されている。

### 禁止事項
フル ORM で、SQL を隠すこと。
SQL の値を、文字列の連結で組み立てること。

### 行動
SQL を `query!`・`query_as!` で書き、`cargo sqlx prepare` の検証データを CI で照合する。
schema の変更は `sqlx migrate add` で migration ファイルを作り、`sqlx migrate run` で適用する。

### 例
```rust
// SQL を文字列で組み立てる。型もスキーマも検査されず、連結は injection を招く
let sql = format!("SELECT * FROM orders WHERE id = '{id}'");

// query_as! のコンパイル時検証。DB がスキーマと型を検証し、値は parameter で渡る
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
```rust
// 競合を型付きの失敗として表す
#[derive(thiserror::Error, Debug)]
pub enum WriteError { #[error("conflict")] Conflict }

// 遷移をイベントとして追記し、(order_id, version) の UNIQUE 制約で衝突を検出する
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
```rust
// 組立点が Transaction を所有する。確定点は一つ
let mut transaction = pool.begin().await?;
order_store.insert(&mut transaction, &order).await?;
outbox.add(&mut transaction, OrderPlaced::from(&order)).await?; // 状態とイベントを同一パスで
transaction.commit().await?;                            // 唯一の確定点

// store は受け取った transaction の中で書くだけ
impl OrderStore {
    async fn insert(&self, transaction: &mut Transaction<'_, Postgres>, order: &Order) -> Result<()> {
        sqlx::query!(/* ... */).execute(&mut **transaction).await?; Ok(())
    }
}
```

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
