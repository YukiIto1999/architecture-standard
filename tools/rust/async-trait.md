# async-trait

用途は、実行時に差し替える非同期の port を動的ディスパッチで扱う機構である。
採用は、Rust は async-trait である。
判断基準は、edition のネイティブな async trait が dyn に乗らない制約を補い、trait の非同期メソッドを dyn で差し替え可能にすることである。
撤回条件は、判断基準を満たさなくなることであり、edition のネイティブな async trait が dyn に対応することを再評価のトリガーとする。

## port を trait で宣言する

### 要求
port は trait で宣言し、業務の核はその trait だけに依存する。
実装を実行時に差し替える port は `Arc<dyn Port>` で渡し、単一の実装で静的に解決できる所は generics で渡す。
dyn で差し替える非同期の port は、async-trait で書く。

### 根拠
trait は技術に依存しない契約で、核はそれだけに依存すれば実装から切れる。
実行時に差し替える port は `Arc<dyn>` の動的ディスパッチで、一つの変数に複数の具象を保持できる。
単一の実装で静的に解ける所は generics の単態化で、呼び出しの最適化が効く。
edition 2024 の native な async trait は dyn に乗らないので、dyn で差し替える非同期の port は async-trait でボックス化する。

### 完了条件
port が trait で宣言され、核が trait だけに依存している。
差し替える port が `Arc<dyn>` で、単一の実装が generics で渡されている。
非同期の port が、dyn で渡せる形になっている。

### 禁止事項
業務の核を、具象の実装に依存させること。

### 行動
port を trait で宣言し、差し替えは `Arc<dyn>`、単一の実装は generics で渡す。

### 例
具象の repository を field に持つと、核が技術の実装へ依存する。

```rust
struct OrderService { repository: PostgresOrderRepository }
```

port の trait だけに依存させる。単一実装は generics で渡し、実行時に差し替える非同期 port は `async-trait` と `Arc<dyn>` で渡す。

```rust
#[async_trait]
pub trait OrderRepository { async fn save(&self, order: &Order) -> Result<(), RepositoryError>; }
struct OrderService<R: OrderRepository> { repository: R }
struct Router { repository: Arc<dyn OrderRepository> }
```
