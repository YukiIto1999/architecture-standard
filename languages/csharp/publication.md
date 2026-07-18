# publication

## 概要
publication は、C# で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization.md) が定める入口での評価・[security](../../concerns/security.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication.md) が定める本人性の確立と資格情報の非流出を、C# の機構で満たす。

## server

### 要求
server は ASP.NET Core の Minimal API で組み、endpoint の登録はコンテキストごとの登録に分ける。
境界の仕込みは middleware で一括して積み、認証を認可の前に、認可を業務の前に置く。

### 根拠
endpoint の登録をコンテキストごとに分ければ、面が変更理由ごとに分かれ、コンテキストが自分の endpoint を所有する。
境界の仕込みを middleware で一括して積めば、横断の関心が入口に集まる。
認証を認可の前に置けば、principal が確立してから認可が評価できる。
認可を業務の前に置けば、拒否が業務に届く前に止まる。

### 完了条件
server が、Minimal API で組まれている。
endpoint の登録が、コンテキストごとの登録に分かれている。
境界の仕込みが middleware で一括して積まれ、認証・認可・業務の順序になっている。

### 禁止事項
認可を、認証の前に置くこと。
endpoint を、一箇所にまとめてベタ書きすること。

### 行動
endpoint の登録をコンテキストごとの拡張メソッドに分け、Program.cs は合成だけにする。
middleware を認証・認可・業務の順に積む。

### 例
```csharp
// 認可を認証より前に置く。principal が未確立で評価される
app.UseAuthorization(); app.UseAuthentication();

// 認証・認可の順に積み、endpoint はコンテキストごとに登録する
app.UseAuthentication(); app.UseAuthorization(); app.UseAntiforgery();
app.MapTodoEndpoints(); app.MapUserEndpoints();
public static RouteGroupBuilder MapTodoEndpoints(this IEndpointRouteBuilder app) =>
    app.MapGroup("/todos").WithTags("Todos");
```

## BFF

### 要求
中継は YARP を使い、session は ASP.NET Core の cookie 認証、OIDC は標準の handler を使う。
token の管理は Duende.AccessTokenManagement を使う。
CSRF の検査は [concerns/authentication](../../concerns/authentication.md) に従う。
access token と refresh token は server 側に保持し、ブラウザへは session を指す識別子だけを持つ認証の cookie を渡す。
認証チケットは `ITicketStore` で `CookieAuthenticationOptions.SessionStore` に差し、retention の Valkey に保持する。

### 根拠
`SaveTokens=true` は既定で token を `AuthenticationProperties` に載せ、`SessionStore` を差さない cookie 認証はその `AuthenticationProperties` を含む認証チケットをそのまま cookie に暗号化して詰める。
`SessionStore` に `ITicketStore` を差せば、cookie は session を指す識別子だけになり、token を含む認証チケットは server 側の store に残る。
YARP が同一オリジンの中継で token を付与すれば、ブラウザは token を持たずに resource へ届く。
Duende.AccessTokenManagement は、token の保持と更新を server 側で担う。

### 完了条件
中継が YARP で、session が cookie 認証、OIDC が標準の handler で行われている。
token の管理が Duende.AccessTokenManagement で行われている。
access token・refresh token が server 側の `ITicketStore` に保持され、ブラウザへ渡る cookie が session を指す識別子だけである。
CSRF の検査が、[concerns/authentication](../../concerns/authentication.md) の方式で行われている。

### 禁止事項
access token・refresh token を、ブラウザへ渡すこと。
`SessionStore` を差さずに `SaveTokens` だけに頼り、token を含む認証チケットを cookie に詰めてブラウザへ渡すこと。
token の管理で、Duende の商用製品(BFF・IdentityServer)に踏み込むこと。
cookie の HttpOnly・Secure・SameSite を、緩めること。

### 行動
OIDC を code と PKCE で server で終端し、token を server 側に保持する。
`CookieAuthenticationOptions.SessionStore` に `ITicketStore` の実装を差し、認証チケットを retention の Valkey に保持する。
YARP で同一オリジンの中継を行い、cookie を HttpOnly・Secure・SameSite=Strict にする。
CSRF の検査は [concerns/authentication](../../concerns/authentication.md) に従って実装する。

### 例
```csharp
// ITicketStore は DI に登録し、options の構築時に解決する。cookie は識別子だけになる
builder.Services.AddSingleton<ITicketStore, ValkeyTicketStore>();
builder.Services.AddAuthentication(options => { options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme; options.DefaultChallengeScheme = "oidc"; })
    .AddCookie(options =>
    {
        options.Cookie.HttpOnly = true; options.Cookie.SecurePolicy = CookieSecurePolicy.Always; options.Cookie.SameSite = SameSiteMode.Strict;
    })
    .AddOpenIdConnect("oidc", options => { options.ResponseType = "code"; options.UsePkce = true; options.SaveTokens = true; });
builder.Services.AddOptions<CookieAuthenticationOptions>(CookieAuthenticationDefaults.AuthenticationScheme)
    .Configure<ITicketStore>((options, store) => options.SessionStore = store); // DI で解決した ITicketStore を差す
builder.Services.AddOpenIdConnectAccessTokenManagement();
builder.Services.AddReverseProxy().LoadFromConfig(config.GetSection("ReverseProxy"));

// ITicketStore は retention の Valkey(StackExchange.Redis)へチケットを保持する
public sealed class ValkeyTicketStore(IDistributedCache cache) : ITicketStore { /* StoreAsync・RenewAsync・RetrieveAsync・RemoveAsync を実装する */ }
```

## console

### 要求
console は ConsoleAppFramework で組み、コマンドを型と constructor injection で組む。

### 根拠
コマンドを型と constructor injection で組めば、依存がシグネチャに現れ、組立点だけが具象を知る。
引数を型でバインドすれば、未検証の値が内側に入らない。

### 完了条件
console が、ConsoleAppFramework で組まれている。
コマンドが型と constructor injection で組まれている。

### 禁止事項
コマンドの中で、依存を直接生成すること。

### 行動
コマンドをクラスとして登録し、依存を constructor で受ける。

### 例
```csharp
// Add<T> と constructor injection。引数は型でバインドする
var app = ConsoleApp.Create().ConfigureServices(services => services.AddSingleton<IGreetingService, GreetingService>());
app.Add<GreetCommands>(); app.Run(args);
public sealed class GreetCommands(IGreetingService greeter)
{
    public void Greet(string name, int count = 1) { for (var i = 0; i < count; i++) Console.WriteLine(greeter.Greet(name)); }
}
```

## worker

### 要求
worker は Wolverine を、PostgreSQL の queue と scheduler に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
handler の依存は constructor で受け取り、実行時の IoC 解決を使わない。

### 根拠
queue と scheduler を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
handler の依存を constructor で受ければ、依存がシグネチャに現れる。
実行時の IoC 解決は、依存をシグネチャから隠し、コンパイル時の誤りを実行時へ遅らせる。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。

### 完了条件
worker が、Wolverine を PostgreSQL の queue と scheduler に限って使っている。
handler の依存が constructor で受け取られ、実行時の IoC 解決を使っていない。
broker・durable workflow・外部の message bus として、使われていない。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
handler で、実行時に IoC から依存を解決すること。

### 行動
永続化を PostgreSQL に限り、handler の依存を constructor で受ける。
予約は durable な scheduler で行う。

### 例
```csharp
// 永続化は PostgreSQL のみ、依存は constructor injection
builder.UseWolverine(options => options.PersistMessagesWithPostgresql(connectionString));
public sealed class ShipOrderHandler(IOrderRepository repository)
{
    public async Task HandleAsync(ShipOrder message, IMessageBus bus)
    {
        await repository.MarkShippedAsync(message.OrderId);
        await bus.ScheduleAsync(new ConfirmDelivery(message.OrderId), 3.Days()); // durable scheduled
    }
}
```

## desktop の host

### 要求
C# の core を持つ desktop の host は Photino.NET とし、Tauri に C# の sidecar を載せる形は不採用とする。
UI は viewer に閉じ、native の widget を別に作らない。

### 根拠
Photino.NET は OS 内蔵の webview に viewer を載せ、C# の core を back-end にする。
UI を viewer に閉じ native の widget を別に作らなければ、面の重複と攻撃面が増えない。
Tauri に C# の sidecar を載せる形は、core の言語と host の言語が割れて構成が複雑になる。

### 完了条件
desktop の host が、Photino.NET である。
UI が viewer に閉じ、native の widget が別に作られていない。
Tauri に C# の sidecar を載せる形が、採られていない。

### 禁止事項
native の widget を、viewer と別に作ること。
Tauri に C# の sidecar を載せる形を、採ること。

### 行動
window を Photino.NET の shell にし、UI を viewer で載せる。
業務の判断は C# の core に置く。

### 例
```csharp
// window は shell、UI は viewer。native widget を別に作らない
var window = new PhotinoWindow().SetTitle("Viewer").SetSize(new Size(1280, 800)).Center()
    .RegisterWebMessageReceivedHandler((sender, message) => ((PhotinoWindow)sender).SendWebMessage($"ack:{message}"))
    .Load("wwwroot/index.html");
window.WaitForClose();
```

## mobile の host

### 要求
C# の core を持つ mobile の host は .NET MAUI の HybridWebView とし、viewer を HybridWebView の中で動かす。
native の UI を別に作らない。

### 根拠
HybridWebView は viewer を web view に載せ、C# の core との通信を担う。
viewer を HybridWebView の中で動かし native の UI を別に作らなければ、面の重複と攻撃面が増えない。

### 完了条件
mobile の host が、.NET MAUI の HybridWebView である。
viewer が HybridWebView の中で動き、native の UI が別に作られていない。

### 禁止事項
native の UI を、viewer と別に作ること。

### 行動
viewer を HybridWebView の中で動かし、C# の core を back-end にする。

### 例
```xml
<!-- viewer を HybridWebView で host する。native UI を別に作らない -->
<HybridWebView x:Name="webView" HybridRoot="wwwroot" RawMessageReceived="OnRaw" />
```

## extension の接続

### 要求
extension が接続する core のプロセスは、外へ出すのを小さい契約だけにして公開する。これを StreamJsonRpc で満たす。
LSP を自作しない。

### 根拠
core を JSON-RPC の小さい契約で公開すれば、外へ出すのは契約だけになる。
StreamJsonRpc は protocol と transport を担うので、自前で書くのは振る舞いだけになる。
LSP を自作すると、framing の手書きが関心を境界の外へ漏らす。

### 完了条件
core のプロセスが、StreamJsonRpc で公開されている。
LSP を、自作していない。

### 禁止事項
JSON-RPC や LSP の framing・protocol を、自作すること。

### 行動
core を StreamJsonRpc で公開し、target を attach して `JsonRpc.Attach<T>` の型付き proxy で呼ぶ。

### 例
```csharp
public interface IExtensionServer { Task<int> AddAsync(int a, int b); }

// target を attach しつつ、型付き proxy(IExtensionServer)で呼ぶ。framing は委譲
var rpc = JsonRpc.Attach<IExtensionServer>(stream, new ExtensionHandler());
int sum = await rpc.AddAsync(1, 2);
```

## 可視性

### 要求
内部の実装は internal に保ち、1ファイルに閉じる型は file 修飾子で閉じる。

### 根拠
通る最も狭い可視性を既定にすれば、public が意図した API の表面に限られ、内部の実装が外から触れない。
1ファイルに閉じる型を file 修飾子で閉じれば、生成物の名前の衝突を避けつつ表面を広げない。

### 完了条件
内部の実装が、internal に保たれている。
1ファイルに閉じる型が、file 修飾子で閉じられている。

### 禁止事項
内部の実装を、public で公開すること。

### 行動
公開する API だけを public にし、内部を internal、1ファイルに閉じる型を file 修飾子で閉じる。

### 例
```csharp
internal sealed class OrderStore { }   // アセンブリの中だけ
file sealed class JsonHelper { }        // このファイルの中だけ
```

## 参照
境界と依存の向きは [separation](../../principles/separation.md)、入口での評価は [authorization](../../concerns/authorization.md)、攻撃面の最小化は [security](../../concerns/security.md)、本人性の確立と資格情報の非流出は [authentication](../../concerns/authentication.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
認証チケットの永続化は [retention](./retention.md) に従う。
