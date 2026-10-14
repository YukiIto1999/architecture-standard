# PhotinoX

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が C# のときは desktop は PhotinoX である。
判断基準は、[desktop](../../structure/runtimes/desktop/layout.md) が定める対象の OS すべてで内蔵 webview に同じ viewer を載せ、core を host の back-end に置き、採用している .NET の版を target し、web の host と同じ viewer の成果物を custom scheme でそのまま配信できることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化、保守の停止、採用している .NET の版を target しなくなること、保守が単独の保守者に依存する状態の継続、同じ判断基準を満たす複数保守者の機構の出現を再評価のトリガーとする。

## desktop の host

### 要求
C# の core を持つ desktop の host は PhotinoX とし、core の言語と host の言語を割らない。
UI は viewer に閉じ、native の widget を別に作らない。
desktop の bridge は、host の認証 adapter が保持する資格情報を認証境界で検証して認証主体を確定する。
bridge は認証主体と資格情報を viewer から受け取らず、host が確定した認証主体と検証済み入力を [structure/contracts/adapters](../../structure/contracts/adapters.md) の宣言された保護を適用する入口へ渡す。
core の公開 API が受け取るのは、検証済み入力と、主体を必要とする operation の認証主体から対応づけた業務入力だけにする。

### 根拠
PhotinoX は OS 内蔵の webview に viewer を載せ、C# の core を back-end にする。
UI を viewer に閉じ native の widget を別に作らなければ、面の重複と攻撃面が増えない。
core の言語と host の言語が割れると、同じ機能の配線が二つの言語へまたがり構成が複雑になる。
host が保持する資格情報から bridge の認証境界で認証主体を確定すれば、viewer が主体を指定できず、core は認証方式を知らずに済む。

### 完了条件
desktop の host が、PhotinoX である。
UI が viewer に閉じ、native の widget が別に作られていない。
core の言語と host の言語が、割れていない。
desktop の bridge の認証境界が、host の認証 adapter の資格情報を検証して認証主体を確定している。
bridge の引数に認証主体と資格情報の型が現れないことが、構造検査で確かめられている。
資格情報から認証主体への確定と、adapter の入口が認証主体から対応づけた業務入力と検証済み入力による core の公開 API の呼出が、実行テストで確かめられている。
core の公開 API が、認証主体と資格情報を受け取らず、必要な業務入力と検証済み入力だけを受け取っている。

### 禁止事項
native の widget を、viewer と別に作ること。
core を別の言語の host の sidecar として載せること。
認証主体または資格情報を、viewer から bridge へ渡すこと。
資格情報と認証主体を、core の公開 API へ渡すこと。

### 行動
window を PhotinoX の shell にし、UI を viewer で載せる。
bridge の入口で host の認証 adapter の資格情報を検証し、認証主体を確定する。
確定した認証主体と検証済み入力を adapter の宣言された保護を適用する入口へ渡し、その入口が対応づけた業務入力と検証済み入力だけを core の公開 API へ渡す。
業務の判断は C# の core に置く。

### 例
ウィンドウは shell、UI は viewer とし、別の native widget を作らない。

```csharp
var app = new PhotinoApplication();
var window = new PhotinoWindow()
    .SetTitle("Viewer")
    .Load("wwwroot/index.html");
app.Run(window);
```
