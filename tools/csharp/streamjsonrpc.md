# StreamJsonRpc

用途は、extension が接続する core のプロセスとの間で、JSON-RPC の小さい契約だけを外へ出す機構である。
採用は、C# は StreamJsonRpc である。
判断基準は、protocol と transport を担い、自前で書くのを振る舞いだけにできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## extension の接続

### 要求
extension が接続する core のプロセスは、外へ出すのを小さい契約だけにして公開する。これを StreamJsonRpc で満たす。
LSP の framing と protocol を再実装しない。

### 根拠
core を JSON-RPC の小さい契約で公開すれば、外へ出すのは契約だけになる。
StreamJsonRpc は protocol と transport を担うので、自前で書くのは振る舞いだけになる。
LSP の framing と protocol を再実装すると、手書きの処理が関心を境界の外へ漏らす。

### 完了条件
core のプロセスが、StreamJsonRpc で公開されている。
LSP の framing と protocol を、再実装していない。

### 禁止事項
JSON-RPC や LSP の framing・protocol を、再実装すること。

### 行動
core を StreamJsonRpc で公開し、target を attach して `JsonRpc.Attach<T>` の型付き proxy で呼ぶ。

### 例
target を attach し、型付き proxy で呼び出す。framing は StreamJsonRpc へ委譲する。

```csharp
public interface IExtensionServer { Task<int> AddAsync(int a, int b); }
```

```csharp
var rpc = JsonRpc.Attach<IExtensionServer>(stream, new ExtensionHandler());
int sum = await rpc.AddAsync(1, 2);
```
