# connection

## 概要
connection は、Rust で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect/README.md) が定める効果システムを、Future・Result・環境への trait bound を言語の効果型として使い、検査で補って満たす。
自前の効果モナドを作らず、遅延を async の Future、想定内の失敗を Result、要求する依存を能力の trait bound で型に出す。
これらの型は同期関数の中の原始効果を表さず、panic による欠陥と Future の drop による取り消しは Result に現れない。
原始効果は、core の domain と application で呼ばせず、呼出位置を clippy の診断で検査し、欠陥と取り消しは後続の節と [tokio-util](./tokio-util.md) が扱う。
資源の解放は所有権と Drop が担い、[coordination](./coordination.md) に従う。
[separation](../../principles/separation/README.md) の依存の向きと [dependency](../../concerns/dependency/inward-dependencies.md) の「依存を内側へ一方向に向ける」の規律に従う。

## 効果を言語の効果型で表す

### 要求
副作用を伴う計算は、Future・Result・環境への trait bound を言語の効果型として表し、自前の効果モナドや runtime を重ねない。
非同期の副作用は `async fn` の返す Future で表し、runtime の executor が境界で poll して進める。
production の item の `async fn` でない関数が Future を返す場合は、戻り型を `impl Future`、`Pin<Box<dyn Future>>`、設定に列挙した型別名のいずれかにし、本体を async block の式(`Box::pin` で包んだものを含む)だけにして、その前に文を置かない。
production の item の Future を手で実装した型(`impl Future for`)は設定に列挙したものに限り、列挙した型を返す構築関数は、この本体の規則の対象にせず、構築では副作用を起こさない。
core の domain と application の production の item は、現在時刻・乱数・ID の生成・入出力(標準入出力を含む)・外部通信の原始効果を呼ばない。
surface・組立点・adapter・infrastructure は、[effect](../../concerns/effect/pure-core-effect-shell.md) の「純粋核と効果の殻に分ける」が定める効果の殻として呼べる。
待機(sleep・interval・timeout)は原始効果に含めず、[tokio-util](./tokio-util.md) の「取り消し」が定める期限と取り消しの機構で扱う。
production の item は、project が production として build する feature の組ごとの `cargo clippy --workspace --lib --bins --no-deps` の compile に含まれる item とする。
feature の組には default の有効・無効を含め、検査には production build と同じ `--no-default-features` と `--features` の選択引数を使う。
syn の検査はこれを近似し、その compile の dep-info の `.rs` の file のうち、item の外側の属性と、file 先頭と module の本体の先頭の内側の属性の cfg 述語を、test を偽、その feature の組を真として評価して偽にならず、`#[test]` 系の属性を持たない item を対象にする。評価できない述語は真として扱う。
`disallowed_methods` は workspace の lint で allow にし、検証入口の `--force-warn clippy::disallowed_methods` の診断だけを位置の規則と照合する。
位置の規則は、原始効果の関数の診断を core の domain と application の file で、`std::env::var` と `std::env::var_os` の診断を設定の組立点の file の外で、`tokio::task::spawn_blocking` の診断を共通 wrapper の file の外で、それぞれ拒否する。
同期の入出力は、さらに [tokio](./tokio.md) の「ブロッキング」に従う。
domain の純粋な判断は、非同期にせず同期の関数のまま保つ。

### 根拠
Rust は遅延する Future と、想定内の失敗を型に出す Result と、要求を宣言する trait bound を既に持つので、別の効果型を重ねると言語と二重になる。
Future は `Context` を伴う poll を受けるたびに計算を進め、完了できなければ Pending を返す。
待っていた資源が準備できて `Context` の Waker が起床されると、executor が Future を再び poll する。
await は Future を自ら実行する命令ではなく、外側の Future が対象を poll する形へ組み込む。
`async fn` は呼んでも本体を実行せず、引数を捕捉した Future を作り、poll されて初めて本体を実行する。
`async fn` でない関数は、async block より前の文を呼出し時に実行するので、遅延は本体が async block だけの形に限って保たれる。
Result は想定内の失敗だけを型に出し、trait bound は宣言した依存だけを型に出す。
同期関数の中の時刻・乱数・入出力は型に現れず、Future にも包まれずに呼出し時に実行されるので、型だけでは要求と本体の実際の効果が一致する保証にならない。
workspace の lint で `disallowed_methods` を allow にすれば、通常の build は診断を出さず、位置の規則を満たす呼出しに `#[allow]` を要しない。
`--force-warn` は属性にも workspace の lint level にも優先するので、検証入口では抑止の有無に依らず全ての呼出しが診断になる。
診断の file と呼ばれた関数の組を位置の規則と照合すれば、一つの lint を共有する原始効果・環境変数・spawn_blocking の位置を、同じ検査で拒否できる。
disallowed_methods は列挙した関数と method の呼出しと参照だけを診断するので、列挙に無い関数による迂回はレビューで確かめる。
`--no-deps` を付ければ、選んだ package だけが lint され、依存として compile される member の診断は出ない。
test の code は production の compile に入らず、原始効果を直接呼べるので、実依存を測る test が使える。
compile が読む file と cfg の結果は feature の組で変わり、dep-info は file 先頭の内側の `#![cfg(test)]` を持つ file も列挙するので、production として build する feature の組ごとに検査し、syn が cfg 述語を評価して item を絞る。
`async fn` と async block の遅延は言語が保証するので、実行テストの対象にしない。
戻り型が `impl Future`・`Pin<Box<dyn Future>>`・列挙した型別名の関数は、syn が Future を返す関数として識別でき、本体の形を構文で判定できる。
clippy の manual_async_fn は、先頭の bound が Future の `impl Future` を返し、全ての lifetime を捕捉して、本体が async block だけの自由関数と impl の method を診断する。
手で実装した Future は構築が任意の処理を持てるので、`impl Future for` を syn で列挙して設定の一覧に限る。
列挙した型を返す構築関数は、`fn new(env: &Env) -> Self` のように戻り型が三つの形のどれでもないので、本体の規則では判定できず、実行テストで確かめる。
実行を境界の runtime に集めると、どこで副作用が起きるかが一箇所で読める。
domain を `async fn` にすると、判断が非同期の足場に侵入し、純粋さとテストの容易さが失われる。

### 完了条件
副作用を伴う計算が、言語の効果型である Future と Result と環境への trait bound で表されている。
自前の効果モナドや runtime を、言語の効果型の上に重ねていない。
production の item の `async fn` でない関数が `Future` を返す場合に、列挙した手書きの `Future` 型を返す構築関数を除き、戻り型が `impl Future`・`Pin<Box<dyn Future>>`・設定に列挙した型別名のいずれかで、本体が async block の式だけである。
production の item の `impl Future for` で定義した型が設定の一覧に限られ、列挙した各型を返す構築関数が、呼んだだけでは副作用を起こさず、poll した後にだけ始まることが実行テストで確認されている。
現在時刻・乱数・ID の生成・入出力・外部通信の原始効果の関数が、clippy.toml の disallowed-methods に関数ごとに列挙されている。
workspace の lint で `disallowed_methods` が allow になっている。
production として build する全ての feature の組の `--force-warn clippy::disallowed_methods` の診断が、位置の規則に反していない。
非同期の実行が、runtime の境界に限られている。
domain が、同期の関数で表され Future を返していない。

### 禁止事項
言語の効果型の上に、自前の効果モナドや runtime を重ねること。
Future を、境界の外で勝手に駆動すること。
production の item で、`async fn` でない関数が、列挙した手書きの Future 型を返す構築関数を除き、列挙した形の外の戻り型で、または async block の前に文を置いた本体で、Future を返すこと。
production の item に、設定の一覧に無い型を `impl Future for` で定義すること。
位置の規則に反して、disallowed-methods に列挙した関数を呼ぶこと。
domain の純粋な判断に、`async fn` や Future を持ち込むこと。

### 行動
副作用を `async fn` の Future で表し、runtime の executor が境界で poll する形に集める。
`async fn` でない関数で Future を返す場合は、列挙した手書きの Future 型を返す構築関数を除き、戻り型を列挙した形にし、本体を async block の式だけにする。
`impl Future for` を構造検査で列挙し、設定の一覧に無い型を拒否して、列挙した型を返す構築関数が呼んだだけでは副作用を起こさないことを実行テストで確かめる。
原始効果の関数を clippy.toml の disallowed-methods に関数ごとに列挙し、workspace の lint で `disallowed_methods` を allow にする。
production として build する feature の組ごとに、`cargo clippy --workspace --lib --bins --no-deps <production と同じ feature 選択引数> --message-format json -- --force-warn clippy::disallowed_methods` で検査し、診断の file と呼ばれた関数の組を位置の規則と照合する。
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

bound に無い時刻を本体が直接取得すると、型が示す要求と実際の依存が食い違う。

```rust
async fn place_order<Env>(env: &Env, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError>
where Env: HasOrders { let placed_at = SystemTime::now(); /* ... */ }
```

時刻を `HasClock` から受ければ、要求が型に現れ、テストで時刻を固定できる。

```rust
async fn place_order<Env>(env: &Env, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError>
where Env: HasClock + HasOrders { let placed_at = env.now(); /* ... */ }
```

原始効果の関数は、関数ごとに clippy.toml へ列挙する。
乱数と ID の生成の関数は、project が採用した crate のものを同じ形で列挙する。

```toml
disallowed-methods = [
  { path = "std::time::SystemTime::now", reason = "時刻は環境の HasClock から受ける" },
  { path = "std::time::Instant::now", reason = "時刻は環境の HasClock から受ける" },
  { path = "std::fs::read_to_string", reason = "入出力は core の domain と application で呼ばない" },
  { path = "std::net::TcpStream::connect", reason = "外部通信は core の domain と application で呼ばない" },
]
```

通常の build の診断は、workspace の lint で止める。

```toml
[workspace.lints.clippy]
disallowed_methods = "allow"
```

`async fn` でない関数が async block の前に処理を置くと、Future を作った時点でその処理が実行される。

```rust
fn find_order<'a, Env: HasOrders>(env: &'a Env, id: OrderId) -> Pin<Box<dyn Future<Output = Result<Order, OrderError>> + 'a>> {
    record_access(&id);
    Box::pin(async move { let order = env.orders().find(id).await?; Ok(order) })
}
```

本体を `Box::pin` で包んだ async block の式だけにすれば、poll するまで処理は始まらない。

```rust
fn find_order<'a, Env: HasOrders>(env: &'a Env, id: OrderId) -> Pin<Box<dyn Future<Output = Result<Order, OrderError>> + 'a>> {
    Box::pin(async move { let order = env.orders().find(id).await?; Ok(order) })
}
```

## 要求する依存を能力の trait bound で型に出す

### 要求
効果が要求する依存は、能力の trait として宣言し、計算の型引数の環境への trait bound で、必要な分だけ要求する。
本番とテストで、環境の実装を差し替える。
use-case と workflow を含む効果を記述する計算は環境への trait bound で依存を宣言し、port を保持する struct のフィールドと構成子注入は、adapter どうしの組み立てや環境の実装のような効果を持たない構成要素の配線に限る。

### 根拠
能力の trait bound を環境に課すと、計算が何を要求するかが型に出て、不足が型検査に出る。
計算ごとに必要な能力だけを bound にすると、全部入りの単一の環境にならない。
環境を差し替えると、時刻と乱数と外部依存をテストで制御できる。
dependency の規律([dependency](../../concerns/dependency/README.md))は、要求を型に宣言する効果の記述には環境の提供を組立点で行わせ、効果を持たない構成要素の配線には構成子注入を用いさせる。
Rust では前者を関数の環境への trait bound が、後者を struct が保持する port のフィールドが担い、二つの機構が対象で住み分ける。

### 完了条件
効果が要求する依存が、環境への能力の trait bound で型に出ている。
各計算が、必要な能力だけを bound にしている。
本番とテストで、環境の実装を差し替えられる。
use-case と workflow の依存が環境の trait bound で宣言され、port を保持する struct のフィールドが効果を持たない構成要素の配線に限られている。

### 禁止事項
全部入りの単一の環境を、全ての計算に要求させること。
依存を、グローバルな static から引くこと。
use-case や workflow を、port を field に保持する struct の method として書き、依存を環境の trait bound の外に置くこと。

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
環境の実装と効果を持たない構成要素は依存を constructor の引数で受け取り、配線は composition root に置く。
本番の環境を composition root で組み、Future の実行を runtime の境界に集める。
executor の起動は、runtime の構築(`Runtime::new` と `Builder` の構築)、`block_on`、`#[tokio::main]`、`#[tokio::test]` を含めて、production の item では composition root に限る。
グローバルな static や lazy な初期化で依存を解決せず、業務の核で具象を生成しない。
production の item の `static`・`thread_local!`・`lazy_static!`・`tokio::task_local!` の宣言は、設定に列挙したものに限り、列挙した各宣言は依存を保持しない。

### 根拠
constructor の引数で受ければ、依存がシグネチャに現れ、組立点だけが具象を知る。
配線を composition root の一点に集めれば、組み立てが一箇所で見渡せる。
本番の環境を組立点で組み、境界で Future を駆動すると、副作用の起動が境界に閉じる。
グローバルな static や lazy な初期化は、依存を隠して実行時にその場で引く service locator になる。
executor の起動が composition root の外にあると、Future の実行が境界の外へ散り、副作用の起動を一箇所で読めなくなる。
`#[tokio::main]` と `#[tokio::test]` は展開した本体で runtime の構築と `block_on` を呼び、clippy の disallowed_methods はこの展開された呼出しも診断する。
executor の起動を disallowed_methods に載せると全ての async test が抑止を要するので、構文検査で production の item の位置に限り、test の code が抑止なしに `#[tokio::test]` で実行テストを書けるようにする。
`static` の宣言と `thread_local!`・`lazy_static!`・`tokio::task_local!` の呼出しは構文で列挙できるが、宣言が依存を保持するかは型の意味を読まなければ判定できない。
`tokio::task_local!` は macro の呼出しなので `static` item に見えず、macro の path で識別する。
境界の `scope` で入れた依存を核が `with` で引く形は、`thread_local!` と同じく、グローバルから依存を取得する形になる。
宣言を設定の一覧と照合し、一覧の各項目が依存を保持しないことをレビューで確かめれば、`thread_local!` の `RefCell` や型別名で包んだ型のように型名の一覧から漏れる宣言も、一覧に無い宣言として拒否できる。

### 完了条件
環境の実装と効果を持たない構成要素の依存が、constructor の引数で受け取られている。
配線が composition root に置かれ、Future の実行が runtime の境界に集まっている。
グローバルな static や lazy な初期化で、依存を解決していない。
Runtime の構築・`block_on`・`#[tokio::main]`・`#[tokio::test]` が、production の item では composition root にだけある。
production の item の `static`・`thread_local!`・`lazy_static!`・`tokio::task_local!` の宣言が、設定に列挙したものに限られ、列挙した各宣言が依存を保持していない。

### 禁止事項
業務の核で、具象を生成すること。
グローバルな static や lazy な初期化で、依存を解決すること。
executor を、production の item で composition root の外で起動すること。
設定に列挙していない `static`・`thread_local!`・`lazy_static!`・`tokio::task_local!` の宣言を、production の item に置くこと。

### 行動
環境の実装と効果を持たない構成要素の依存を constructor の引数で受け、配線を composition root に集める。
本番の環境を組立点で組み、Future の実行を境界に置く。
Runtime の構築と `block_on` と `#[tokio::main]` を composition root に置き、test の code は `#[tokio::test]` で executor を起動する。
production の item の `static`・`thread_local!`・`lazy_static!`・`tokio::task_local!` の宣言を構造検査で列挙し、設定の一覧に無い宣言を拒否して、一覧の各項目が依存を保持しないことをレビューする。

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
    let connection = connect().await;
    let environment = ProductionEnvironment::new(connection);
    serve(environment).await;
}
```

業務の関数が自分で runtime を起動すると、executor の起動が境界の外へ散る。

```rust
fn place_order_sync<Env>(env: &Env, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError>
where Env: HasClock + HasOrders {
    let runtime = tokio::runtime::Runtime::new().map_err(PlaceOrderError::Runtime)?;
    runtime.block_on(place_order(env, command))
}
```

test の code では `#[tokio::test]` が executor を起動するので、親の module と環境の記録用実装を取り込めば、実行テストを書ける。

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::fakes::{RecordingEnvironment, sample_command};

    #[tokio::test]
    async fn place_order_saves_the_order() {
        let environment = RecordingEnvironment::new();
        let placed = place_order(&environment, sample_command()).await;
        assert!(placed.is_ok());
    }
}
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
取り消しは業務の失敗の Result に混ぜず、協調取消の完了と Future の drop の扱いは [tokio-util](./tokio-util.md) の「取り消し」に従う。
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
要求の経路で `unwrap` すると、想定された失敗がクラッシュになり、失敗がシグネチャに現れない。

```rust
async fn find_order<Env: HasOrders>(env: &Env, id: OrderId) -> Order { env.orders().find(id).await.unwrap() }
```

thiserror の enum を `?` で伝播すれば、想定内の失敗は Result、欠陥は panic に分かれ、依存は環境の trait bound に現れる。

```rust
#[derive(thiserror::Error, Debug)]
pub enum OrderError { #[error("not found")] NotFound }
async fn find_order<Env: HasOrders>(env: &Env, id: OrderId) -> Result<Order, OrderError> {
    let order = env.orders().find(id).await?;
    Ok(order)
}
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

use-case は環境の trait bound で port を要求し、port の trait だけに依存させる。
単一実装の組み立ては generics で、実行時に差し替える非同期 port は `async-trait` と `Arc<dyn>` で環境の実装に持たせる。

```rust
#[async_trait]
pub trait OrderRepository { async fn save(&self, order: &Order) -> Result<(), RepositoryError>; }
async fn place_order<Env: HasOrders>(env: &Env, command: PlaceOrderCommand) -> Result<OrderId, PlaceOrderError> { /* ... */ }
struct CachedOrders<R: OrderRepository> { inner: R }
struct AppEnv { orders: Arc<dyn OrderRepository> }
impl HasOrders for AppEnv { fn orders(&self) -> &dyn OrderRepository { self.orders.as_ref() } }
```


## FFI を安全な境界に閉じる

### 要求
C ABI との FFI は、infrastructure の専用 module に閉じ、公開面には safe な Rust の型だけを出す。
unsafe block は、成立している不変条件をコメントで示し、FFI を含む最小の item に限る。
FFI が返す null・エラーコード・sentinel は、境界で Result へ写す。
FFI が渡す資源(handle・C 文字列・buffer)の解放は、Drop を実装した wrapper 型で保証する。

### 根拠
unsafe を境界の module に閉じれば、健全性の検査対象が狭まり、利用側は型だけで安全を得る。
null とエラーコードを境界で Result に写せば、失敗が型に現れ、呼び出し側が扱いを強制される。
Drop の wrapper は、解放漏れと二重解放を型の寿命で防ぐ。

### 完了条件
FFI の呼び出しと unsafe が、infrastructure の専用 module に閉じている。
公開面に、raw pointer と C の型が出ていない。
FFI の資源が、Drop を実装した wrapper で解放されている。

### 禁止事項
unsafe を、FFI の境界 module の外に散らすこと。
FFI のエラーコードを、検査せずに握り潰すこと。

### 行動
FFI ごとに wrapper module を作り、extern の呼び出し・型変換・解放をその中に閉じる。
公開 API は safe な型と Result で宣言し、unsafe には不変条件のコメントと `#[allow(unsafe_code)]` を付ける。

## 参照
効果システムは [effect](../../concerns/effect/README.md)、依存の向きは [dependency](../../concerns/dependency/README.md) に従う。
取り消しは [coordination](./coordination.md)、資源は [sqlx](./sqlx.md)、組立点の構造は [structure/core/composition](../../structure/core/composition.md) に従う。
