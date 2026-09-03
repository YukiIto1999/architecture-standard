# Testcontainers for .NET

用途は、実依存のコンテナを起動し、本物に近い依存で検証する道具である。
採用は、C# は Testcontainers for .NET である。
判断基準は、割り当てられた host と port を取得して使え、コンテナをテストの終わりに片づけられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 実依存

### 要求
実依存のコンテナは、本物に近い依存で検証しテストの終わりに片づける。これを Testcontainers for .NET で満たす。

### 根拠
実依存を mock で置き換えると、実際のドライバや SQL の振る舞いを踏まない。
Testcontainers で実依存のコンテナを起動すれば、本物に近い依存で検証でき、コンテナはテストの終わりに片づく。

### 完了条件
実依存のコンテナが、Testcontainers for .NET で起動され、テストの終わりに片づいている。

### 禁止事項
接続の host や port を、固定で書くこと。

### 行動
実依存を Testcontainers for .NET で起動し、IAsyncInitializer で起動を、IAsyncDisposable で破棄を結ぶ。
