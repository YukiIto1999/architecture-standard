# vscode-jsonrpc

用途は、extension が接続する core のプロセスとの間で、JSON-RPC の小さい契約だけを外へ出す機構である。
採用は、TypeScript は vscode-jsonrpc である。
判断基準は、protocol と transport を担い、自前で書くのを振る舞いだけにできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## core への接続

### 要求
extension が接続する core のプロセスへは、外へ出すのを小さい契約だけにして接続する。これを vscode-jsonrpc で満たす。

### 根拠
メソッドを型で宣言し protocol をライブラリに委ねれば、外へ出すのは小さい契約だけになり、framing を手書きしない。

### 完了条件
core のプロセスへの接続が、vscode-jsonrpc で行われている。

### 禁止事項
JSON-RPC の framing や protocol を、再実装すること。

### 行動
メソッドを RequestType・NotificationType で型宣言し、vscode-jsonrpc で接続して listen する。

### 例
メソッドを型で宣言し、framing を `vscode-jsonrpc` に委ねる。

```typescript
const EchoRequest = new rpc.RequestType<{ text: string }, { echoed: string }, void>("echo");
const connection = rpc.createMessageConnection(new rpc.StreamMessageReader(stdout), new rpc.StreamMessageWriter(stdin));
connection.listen();
const response = await connection.sendRequest(EchoRequest, { text: "hi" });
```
