# thiserror

用途は、責務の単位でエラー型を宣言し表示と変換を導出する機構である。
採用は、Rust は thiserror である。
判断基準は、エラー型の表示と変換の定型実装を導出でき、`?` による伝播と組み合わせられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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
