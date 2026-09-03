# Photino.NET

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が C# のときは desktop は Photino.NET である。
判断基準は、OS 内蔵の webview に同じ viewer を載せ、core を host の back-end に置けることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化を再評価のトリガーとする。

## desktop の host

### 要求
C# の core を持つ desktop の host は Photino.NET とし、Tauri に C# の sidecar を載せる形は不採用とする。
UI は viewer に閉じ、native の widget を別に作らない。
desktop の bridge は、host の認証 adapter が保持する資格情報を認証境界で検証して actor を構築する。
bridge は actor と資格情報を viewer から受け取らず、actor と検証済み入力だけを core へ渡す。

### 根拠
Photino.NET は OS 内蔵の webview に viewer を載せ、C# の core を back-end にする。
UI を viewer に閉じ native の widget を別に作らなければ、面の重複と攻撃面が増えない。
Tauri に C# の sidecar を載せる形は、core の言語と host の言語が割れて構成が複雑になる。
host が保持する資格情報から bridge の認証境界で actor を構築すれば、viewer が actor を指定できず、core は認証方式を知らずに済む。

### 完了条件
desktop の host が、Photino.NET である。
UI が viewer に閉じ、native の widget が別に作られていない。
Tauri に C# の sidecar を載せる形が、採られていない。
desktop の bridge の認証境界が、host の認証 adapter の資格情報を検証して actor を構築している。
core の公開 API が、actor と検証済み入力だけを受け取っている。

### 禁止事項
native の widget を、viewer と別に作ること。
Tauri に C# の sidecar を載せる形を、採ること。
actor または資格情報を、viewer から bridge へ渡すこと。
資格情報を、core の公開 API へ渡すこと。

### 行動
window を Photino.NET の shell にし、UI を viewer で載せる。
bridge の入口で host の認証 adapter の資格情報を検証し、actor を構築する。
actor と検証済み入力だけを core の公開 API へ渡す。
業務の判断は C# の core に置く。

### 例
ウィンドウは shell、UI は viewer とし、別の native widget を作らない。

```csharp
var window = new PhotinoWindow().SetTitle("Viewer").SetSize(new Size(1280, 800)).Center()
    .RegisterWebMessageReceivedHandler((sender, message) => ((PhotinoWindow)sender).SendWebMessage($"ack:{message}"))
    .Load("wwwroot/index.html");
window.WaitForClose();
```
