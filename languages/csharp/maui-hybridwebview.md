# .NET MAUI の HybridWebView

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が C# のときは mobile は .NET MAUI の HybridWebView である。
判断基準は、OS 内蔵の webview に同じ viewer を載せ、core を host の back-end に置けることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化を再評価のトリガーとする。

## mobile の host

### 要求
C# の core を持つ mobile の host は .NET MAUI の HybridWebView とし、viewer を HybridWebView の中で動かす。
native の UI を別に作らない。
mobile の bridge は、host の認証 adapter が保持する資格情報を認証境界で検証して認証主体を確定する。
bridge は認証主体と資格情報を viewer から受け取らず、host が確定した認証主体と検証済み入力を [structure/contracts/adapters](../../structure/contracts/adapters.md) の宣言された保護を適用する入口へ渡す。
core の公開 API が受け取るのは、検証済み入力と、主体を必要とする operation の認証主体から対応づけた業務入力だけにする。

### 根拠
HybridWebView は viewer を web view に載せ、C# の core との通信を担う。
viewer を HybridWebView の中で動かし native の UI を別に作らなければ、面の重複と攻撃面が増えない。
host が保持する資格情報から bridge の認証境界で認証主体を確定すれば、viewer が主体を指定できず、core は認証方式を知らずに済む。

### 完了条件
mobile の host が、.NET MAUI の HybridWebView である。
viewer が HybridWebView の中で動き、native の UI が別に作られていない。
mobile の bridge の認証境界が、host の認証 adapter の資格情報を検証して認証主体を確定している。
core の公開 API が、認証主体と資格情報を受け取らず、必要な業務入力と検証済み入力だけを受け取っている。
bridge の引数に認証主体と資格情報の型が現れないことが、構造検査で確かめられている。
資格情報から認証主体への確定と、adapter の入口が認証主体から対応づけた業務入力と検証済み入力による core の公開 API の呼出が、実行テストで確かめられている。

### 禁止事項
native の UI を、viewer と別に作ること。
認証主体または資格情報を、viewer から bridge へ渡すこと。
資格情報と認証主体を、core の公開 API へ渡すこと。

### 行動
viewer を HybridWebView の中で動かし、C# の core を back-end にする。
bridge の入口で host の認証 adapter の資格情報を検証し、認証主体を確定する。
確定した認証主体と検証済み入力を adapter の宣言された保護を適用する入口へ渡し、その入口が対応づけた業務入力と検証済み入力だけを core の公開 API へ渡す。

### 例
モバイルでも viewer を `HybridWebView` で host し、別の native UI を作らない。

```xml
<HybridWebView x:Name="webView" HybridRoot="wwwroot" RawMessageReceived="OnRaw" />
```
