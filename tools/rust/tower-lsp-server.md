# tower-lsp-server

## 言語サービスの公開

用途は、extension が接続する core のプロセスが言語機能を公開する骨格である。
採用は、tower-lsp-server である。
判断基準は、protocol と transport を枠組みが担い、自前で書くのが振る舞いだけになることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
言語サービスは Rust の役割であり、他言語の採用を持たない。

## extension が接続する core への JSON-RPC

用途は、extension が接続する core のプロセスとの間で、JSON-RPC の小さい契約だけを外へ出す機構である。
採用は、Rust は tower-lsp-server の custom method である。
判断基準は、protocol と transport を担い、自前で書くのを振る舞いだけにできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## extension の接続

### 要求
extension が接続する core のプロセスは、外へ出すのを小さい契約だけにして公開する。これを tower-lsp-server の custom method による JSON-RPC で満たし、直列化は serde を使う。
標準の言語機能は、tower-lsp-server の LanguageServer で LSP として公開する。
LSP の framing と protocol を再実装しない。

### 根拠
core を JSON-RPC の小さい契約で公開すれば、外へ出すのは契約だけになる。
tower-lsp-server の custom method は protocol と transport を担うので、自前で書くのは小さい契約の振る舞いと serde の値だけになる。
LSP の framing と protocol を再実装すると、手書きの処理が関心を境界の外へ漏らす。

### 完了条件
core のプロセスが tower-lsp-server の custom method による JSON-RPC で公開され、直列化に serde が使われている。
標準の言語機能が、tower-lsp-server の LanguageServer で公開されている。
LSP の framing と protocol を、再実装していない。

### 禁止事項
LSP の framing や protocol を、再実装すること。
tower-lsp-server の外に、extension 用の JSON-RPC framing を重ねること。

### 行動
core の小さい契約を tower-lsp-server の custom method で公開し、直列化を serde で行う。
標準の言語機能は、tower-lsp-server で LanguageServer を実装する。

### 例
標準 LSP と小さい application protocol を、同じ transport へ載せる。

```rust
let (service, socket) = LspService::build(|client| Backend { client })
    .custom_method("project/read-model", Backend::read_model)
    .finish();
Server::new(stdin(), stdout(), socket).serve(service).await;
```
