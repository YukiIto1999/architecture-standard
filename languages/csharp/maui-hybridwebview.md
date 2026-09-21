# .NET MAUI の HybridWebView

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が C# のときは mobile は .NET MAUI の HybridWebView である。
判断基準は、OS 内蔵の webview に同じ viewer を載せ、core を host の back-end に置けることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化を再評価のトリガーとする。

## mobile の host

### 要求
C# の core を持つ mobile の host は .NET MAUI の HybridWebView とし、viewer を HybridWebView の中で動かす。
native の UI を別に作らない。
mobile の bridge は、host の認証 adapter が保持する資格情報を認証境界で検証して actor を構築する。
bridge は actor と資格情報を viewer から受け取らず、actor と検証済み入力だけを core へ渡す。

### 根拠
HybridWebView は viewer を web view に載せ、C# の core との通信を担う。
viewer を HybridWebView の中で動かし native の UI を別に作らなければ、面の重複と攻撃面が増えない。
host が保持する資格情報から bridge の認証境界で actor を構築すれば、viewer が actor を指定できず、core は認証方式を知らずに済む。

### 完了条件
mobile の host が、.NET MAUI の HybridWebView である。
viewer が HybridWebView の中で動き、native の UI が別に作られていない。
mobile の bridge の認証境界が、host の認証 adapter の資格情報を検証して actor を構築している。
core の公開 API が、actor と検証済み入力だけを受け取っている。

### 禁止事項
native の UI を、viewer と別に作ること。
actor または資格情報を、viewer から bridge へ渡すこと。
資格情報を、core の公開 API へ渡すこと。

### 行動
viewer を HybridWebView の中で動かし、C# の core を back-end にする。
bridge の入口で host の認証 adapter の資格情報を検証し、actor を構築する。
actor と検証済み入力だけを core の公開 API へ渡す。

### 例
モバイルでも viewer を `HybridWebView` で host し、別の native UI を作らない。

```xml
<HybridWebView x:Name="webView" HybridRoot="wwwroot" RawMessageReceived="OnRaw" />
```
