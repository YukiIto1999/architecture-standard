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
取り消しは [coordination](./coordination.md)、資源は [sqlx](./sqlx.md)、組立点の構造は [structure/core/composition](../../structure/core/composition.md) に従う。
