# connection

## 概要
connection は、Rust で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect.md) が定める効果システムを、Rust が言語に持つ効果型で満たす。
自前の効果モナドを作らず、async の Future と Result と所有権を効果として使い、要求する依存は能力の trait bound で型に出す。
[separation](../../principles/separation.md) の依存の向きと [dependency](../../concerns/dependency.md) の「依存を内側へ一方向に向ける」の規律に従う。

## 効果を言語の効果型で表す

### 要求
副作用を伴う計算は、Rust が言語に持つ効果型で表し、自前の効果モナドや runtime を重ねない。
非同期の副作用は `async fn` の返す Future で表し、runtime の executor が境界で poll して進める。
domain の純粋な判断は、非同期にせず同期の関数のまま保つ。

### 根拠
Rust は async と Result と所有権を効果型として既に持つので、別の効果型を重ねると言語と二重になる。
Future は `Context` を伴う poll を受けるたびに計算を進め、完了できなければ Pending を返す。
待っていた資源が準備できて `Context` の Waker が起床されると、executor が Future を再び poll する。
await は Future を自ら実行する命令ではなく、外側の Future が対象を poll する形へ組み込む。
実行を境界の runtime に集めると、どこで副作用が起きるかが一箇所で読める。
domain を `async fn` にすると、判断が非同期の足場に侵入し、純粋さとテストの容易さが失われる。

### 完了条件
副作用を伴う計算が、言語の効果型である Future と Result と所有権で表されている。
自前の効果モナドや runtime を、言語の効果型の上に重ねていない。
非同期の実行が、runtime の境界に限られている。
domain が、同期の関数で表され Future を返していない。

### 禁止事項
言語の効果型の上に、自前の効果モナドや runtime を重ねること。
Future を、境界の外で勝手に駆動すること。
domain の純粋な判断に、`async fn` や Future を持ち込むこと。

### 行動
副作用を `async fn` の Future で表し、runtime の executor が境界で poll する形に集める。
domain は同期の関数に保ち、副作用の経路だけを `async fn` で表す。

### 例
独自の効果モナドを重ねると、言語の `Future` と効果の表現が二重になる。

```rust
struct Effect<Env, Failure, Value> { /* ... */ }
```

言語の効果型で表せば、runtime の executor が `Future` を poll して処理を進める。

```rust
async fn place_order<Env>(env: &Env, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError>
where Env: HasClock + HasOrders { /* ... */ }
```

## 失敗を Result に、欠陥を panic にする

### 要求
想定された失敗は Result で返し、エラーは thiserror の enum で責務の単位に定義して `?` で伝播する。
不変条件の違反は panic で表し、要求の経路で unwrap・expect を使わない。
domain と application は型消去したエラーを返さず、型消去は binary の最上位の報告にだけ使う。

### 根拠
想定された失敗を Result にすれば、失敗が型に現れ、呼び出し側が扱いを強制される。
thiserror は表示と変換を生成し、責務の単位のエラー型を `?` でつなげる。
不変条件の違反は回復できない欠陥なので、Result に混ぜず panic で表す。
取り消しは失敗でも欠陥でもなく、Future の drop で表すので、Result には入れない。
型消去したエラーは種別が型から消えるので、domain と application では使わず、最上位の報告にだけ使う。

### 完了条件
想定された失敗が、Result で返されている。
エラーが、thiserror の enum で責務の単位に定義されている。
不変条件の違反が panic で表され、要求の経路に unwrap・expect がない。
domain と application が、型消去したエラーを返していない。

### 禁止事項
要求の経路で、unwrap・expect を使うこと。
欠陥や取り消しを、想定された失敗の Result に混ぜること。
domain と application で、型消去したエラーを返すこと。

### 行動
想定された失敗を thiserror の enum にし、`?` で伝播する。
不変条件の違反は panic にし、型消去は最上位の報告に限る。

### 例
要求の経路で `unwrap` すると、想定された失敗がクラッシュになり、依存もシグネチャに現れない。

```rust
fn handle(repository: &impl OrderRepository, id: OrderId) -> Order { repository.find(id).unwrap() }
```

`thiserror` の enum を `?` で伝播すれば、欠陥は panic、取り消しは `Future` の drop、依存は引数に現れる。

```rust
#[derive(thiserror::Error, Debug)]
pub enum OrderError { #[error("not found")] NotFound }
fn handle(repository: &impl OrderRepository, id: OrderId) -> Result<Order, OrderError> { repository.find(id) }
```

## 要求する依存を能力の trait bound で型に出す

### 要求
効果が要求する依存は、能力の trait として宣言し、計算の型引数の環境への trait bound で、必要な分だけ要求する。
本番とテストで、環境の実装を差し替える。
効果を記述する計算は環境への trait bound で依存を宣言し、効果を持たない構成要素(adapter どうしの組み立てなど)の配線は、port を保持する struct のフィールドと構成子注入で行う。

### 根拠
能力の trait bound を環境に課すと、計算が何を要求するかが型に出て、不足が型検査に出る。
計算ごとに必要な能力だけを bound にすると、全部入りの単一の環境にならない。
環境を差し替えると、時刻と乱数と外部依存をテストで制御できる。
dependency の規律([dependency](../../concerns/dependency.md))は、要求を型に宣言する効果の記述には環境の提供を組立点で行わせ、効果を持たない構成要素の配線には構成子注入を用いさせる。
Rust では前者を関数の環境への trait bound が、後者を struct が保持する port のフィールドが担い、二つの機構が対象で住み分ける。

### 完了条件
効果が要求する依存が、環境への能力の trait bound で型に出ている。
各計算が、必要な能力だけを bound にしている。
本番とテストで、環境の実装を差し替えられる。
効果を記述する計算と、効果を持たない構成要素の配線が、環境の trait bound と構成子注入で住み分けられている。

### 禁止事項
全部入りの単一の環境を、全ての計算に要求させること。
依存を、グローバルな static から引くこと。

### 行動
能力を trait で宣言し、計算の環境に必要な分だけ trait bound を課す。
本番とテストで、環境の実装を差し替える。

### 例
必要な能力だけを trait bound にする。

```rust
pub trait HasClock { fn now(&self) -> SystemTime; }
pub trait HasOrders { fn orders(&self) -> &dyn OrderRepository; }

async fn place_order<Env>(env: &Env, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError>
where Env: HasClock + HasOrders { /* ... */ }
```

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

## 配線を組立点に置き、境界で実行する

### 要求
依存は constructor の引数で受け取り、配線は composition root に置く。
本番の環境を composition root で組み、Future の実行を runtime の境界に集める。
グローバルな static や lazy な初期化で依存を解決せず、業務の核で具象を生成しない。

### 根拠
constructor の引数で受ければ、依存がシグネチャに現れ、組立点だけが具象を知る。
配線を composition root の一点に集めれば、組み立てが一箇所で見渡せる。
本番の環境を組立点で組み、境界で Future を駆動すると、副作用の起動が境界に閉じる。
グローバルな static や lazy な初期化は、依存を隠して実行時にその場で引く service locator になる。

### 完了条件
依存が、constructor の引数で受け取られている。
配線が composition root に置かれ、Future の実行が runtime の境界に集まっている。
グローバルな static や lazy な初期化で、依存を解決していない。

### 禁止事項
業務の核で、具象を生成すること。
グローバルな static や lazy な初期化で、依存を解決すること。

### 行動
依存を constructor の引数で受け、配線を composition root に集める。
本番の環境を組立点で組み、Future の実行を境界に置く。

### 例
核がグローバルから依存を取得すると、依存関係がシグネチャから消える。

```rust
fn run() {
    let database = GLOBAL_POOL.get();
    use_database(database);
}
```

依存は constructor で受け、具象の環境は組立点だけで構築し、境界で実行する。

```rust
#[tokio::main]
async fn main() {
    let environment = ProductionEnvironment::new(connection);
    serve(environment).await;
}
```

## 参照
効果システムは [effect](../../concerns/effect.md)、依存の向きは [dependency](../../concerns/dependency.md) に従う。
取り消しは [coordination](./coordination.md)、資源は [retention](./retention.md)、組立点の構造は [structure/core/composition](../../structure/core/composition.md) に従う。
