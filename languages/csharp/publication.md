# publication

## 概要
publication は、C# で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization.md) が定める入口での評価・[security](../../concerns/security.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication.md) が定める資格情報の検証と actor の構築を、C# の機構で満たす。

## server

### 要求
server は ASP.NET Core の Minimal API で組み、endpoint の登録はコンテキストごとの登録に分ける。
境界の仕込みは middleware で一括して積み、認証を認可の前に、認可を業務の前に置く。
server の認証境界は検証済み `ClaimsPrincipal` を actor へ写し、endpoint から埋め込んだ core の公開 API へ actor だけを渡す。
`ClaimsPrincipal`、token、claim を core の公開 API または業務へ渡さない。
冪等な endpoint は、認証済み actor ID、匿名の安定した session または client の opaque scope、logical system actor ID を要求の種別に応じた actor scope として retention へ渡す。
multi-tenant operation は、認証済み claim または membership、authorization 済み選択、匿名の検証済み host または route と session/client context、system の logical actor 設定のいずれかから `TenantId` を構築する。
single-tenant operation は正準な single-tenant sentinel を、tenant の概念を持たない operation は正準な no-tenant sentinel を retention へ渡す。
安定した匿名 scope がない endpoint は、server 発行の全体で一意な key と proof だけを受け付ける。

### 根拠
endpoint の登録をコンテキストごとに分ければ、面が変更理由ごとに分かれ、コンテキストが自分の endpoint を所有する。
境界の仕込みを middleware で一括して積めば、横断の関心が入口に集まる。
認証を認可の前に置けば、principal が確立してから認可が評価できる。
認可を業務の前に置けば、拒否が業務に届く前に止まる。

### 完了条件
server が、Minimal API で組まれている。
endpoint の登録が、コンテキストごとの登録に分かれている。
境界の仕込みが middleware で一括して積まれ、認証・認可・業務の順序になっている。
検証済み `ClaimsPrincipal` が server の認証境界で actor へ写され、core の公開 API が actor だけを受け取っている。
冪等な endpoint が actor と tenant の全種別を retention の scope へ写し、未検証 tenant と `TenantId`・single-tenant sentinel・no-tenant sentinel の相互混同を拒否し、proof のない別 client へ保存済み response を返さないことが結合テストで検証されている。

### 禁止事項
認可を、認証の前に置くこと。
`ClaimsPrincipal`、token、claim を core の公開 API または業務へ渡すこと。
endpoint を、一箇所にまとめてベタ書きすること。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せずに保存済み response を返すこと。
未検証の tenant context を `TenantId` として retention へ渡すこと。

### 行動
endpoint の登録をコンテキストごとの拡張メソッドに分け、Program.cs は合成だけにする。
middleware を認証・認可・業務の順に積む。
検証済み `ClaimsPrincipal` を認証 middleware で actor へ写し、endpoint から actor と検証済み入力だけを core の公開 API へ渡す。
actor と tenant の種別を retention の scope へ写し、安定した匿名 scope がなければ server 発行 key と proof を使う。
multi-tenant は認証済み、匿名、system の検証済み context から `TenantId` を構築する。
single-tenant は正準な single-tenant sentinel、tenant の概念外は正準な no-tenant sentinel を使う。
全 actor/tenant 種別の競合、未検証 tenant と三つの tenant scope 表現の相互混同、proof のない別 client への response 漏洩拒否を結合テストで確かめる。

### 例
認可を認証より先に置くと、principal が未確立のまま評価される。

```csharp
app.UseAuthorization(); app.UseAuthentication();
```

認証、認可、CSRF の順に積み、endpoint はコンテキストごとに登録する。

```csharp
app.UseAuthentication(); app.UseAuthorization(); app.UseMiddleware<CsrfMiddleware>();
app.MapTodoEndpoints(); app.MapUserEndpoints();
```

```csharp
public static RouteGroupBuilder MapTodoEndpoints(this IEndpointRouteBuilder app) =>
    app.MapGroup("/todos").WithTags("Todos");
```

## BFF

### 要求
session は ASP.NET Core の cookie 認証、OIDC は標準の handler を使う。
token の管理は Duende.AccessTokenManagement を使う。
CSRF の検査は、session に保持した token と専用 header の一致を検査する CSRF middleware で行う([structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う)。
access token と refresh token は server 側に保持し、ブラウザへは session を指す識別子だけを持つ認証の cookie を渡す。
認証チケットは `ITicketStore` で `CookieAuthenticationOptions.SessionStore` に差し、retention の Valkey に保持する。
認証 middleware は、検証済みの `ClaimsPrincipal` を `ActorMapper` で actor へ写す。
認証 middleware は、actor を request-scoped `ActorRequestContext` へ格納する。
request-scoped の `Actor` は、同じ `ActorRequestContext` から DI で解決する。
BFF の route は、request-scoped の `Actor` を引数として注入され、境界で検証した入力とともに埋め込んだ core の公開 API へ渡す。
BFF の route は、`ClaimsPrincipal` を参照しない。
`ActorMapper` は、認証 middleware からだけ呼び出す。

### 根拠
`SaveTokens=true` は既定で token を `AuthenticationProperties` に載せ、`SessionStore` を差さない cookie 認証はその `AuthenticationProperties` を含む認証チケットをそのまま cookie に暗号化して詰める。
`SessionStore` に `ITicketStore` を差せば、cookie は session を指す識別子だけになり、token を含む認証チケットは server 側の store に残る。
Duende.AccessTokenManagement は、token の保持と更新を server 側で担う。
principal を認証境界で actor へ写せば、core は token と認証方式を知らず、検証済みの主体だけを受け取る。
actor を request-scoped context に一度格納し、DI で同じ actor を route へ渡せば、認証境界と route が別の主体を構築しない。
route が埋め込んだ core の公開 API を呼べば、認証境界と業務処理を同じ process の型付き呼出で接続できる。

### 完了条件
session が cookie 認証、OIDC が標準の handler で行われている。
token の管理が Duende.AccessTokenManagement で行われている。
access token・refresh token が server 側の `ITicketStore` に保持され、ブラウザへ渡る cookie が session を指す識別子だけである。
検証済みの `ClaimsPrincipal` が、認証 middleware の `ActorMapper` で actor へ写されている。
認証 middleware が、actor を request-scoped `ActorRequestContext` へ格納している。
DI が同じ `ActorRequestContext` から `Actor` を解決し、BFF の route へ注入している。
BFF の route が、注入された actor と検証済みの入力を、埋め込んだ core の公開 API へ渡している。
BFF の route が、`ClaimsPrincipal` を参照していない。
`ActorMapper` が、認証 middleware からだけ呼び出されている。
CSRF の検査が、[structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) の方式で行われている。

### 禁止事項
access token・refresh token を、ブラウザへ渡すこと。
`SessionStore` を差さずに `SaveTokens` だけに頼り、token を含む認証チケットを cookie に詰めてブラウザへ渡すこと。
token の管理で、Duende の商用製品(BFF・IdentityServer)に踏み込むこと。
ASP.NET Core の Antiforgery を CSRF の検査に使い、期待値の保持を cookie に頼ること。
cookie の HttpOnly・Secure・SameSite を、緩めること。
BFF の route から、埋め込んだ core の公開 API 以外の業務処理を呼ぶこと。
token または未検証の principal を、core へ渡すこと。
BFF の route で、`ClaimsPrincipal` を受け取ること。
認証 middleware の外から、`ActorMapper` を呼び出すこと。
認証 middleware が格納した actor と異なる actor を、BFF の route で構築すること。

### 行動
OIDC を code と PKCE で server で終端し、token を server 側に保持する。
`CookieAuthenticationOptions.SessionStore` に `ITicketStore` の実装を差し、認証チケットを retention の Valkey に保持する。
cookie を HttpOnly・Secure・SameSite=Strict にする。
認証 middleware で検証済みの `ClaimsPrincipal` を `ActorMapper` へ渡し、得た actor を request-scoped `ActorRequestContext` へ格納する。
同じ `ActorRequestContext` から request-scoped の `Actor` を DI で解決する。
BFF の route は、DI で注入された `Actor` と検証済みの入力を埋め込んだ core の公開 API へ渡す。
BFF の route から `ClaimsPrincipal` と `ActorMapper` の参照を除く。
CSRF の検査は、session の token と専用 header の一致を CSRF middleware で検査する。

### 例
チケットは retention の Valkey に保持し、cookie には識別子だけを置く。`ITicketStore` は DI に登録し、options 構築時に解決する。検証済み principal は actor へ写して request scope に保持し、route から検証済み入力とともに core へ渡す。

```csharp
builder.Services.AddSingleton<ITicketStore, ValkeyTicketStore>();
builder.Services.AddAuthentication(options => { options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme; options.DefaultChallengeScheme = "oidc"; })
    .AddCookie(options =>
    {
        options.Cookie.HttpOnly = true; options.Cookie.SecurePolicy = CookieSecurePolicy.Always; options.Cookie.SameSite = SameSiteMode.Strict;
    })
    .AddOpenIdConnect("oidc", options => { options.ResponseType = "code"; options.UsePkce = true; options.SaveTokens = true; });
builder.Services.AddOptions<CookieAuthenticationOptions>(CookieAuthenticationDefaults.AuthenticationScheme)
    .Configure<ITicketStore>((options, store) => options.SessionStore = store);
builder.Services.AddOpenIdConnectAccessTokenManagement();
builder.Services.AddScoped<ActorRequestContext>();
builder.Services.AddScoped(sp => sp.GetRequiredService<ActorRequestContext>().RequiredActor);

app.UseAuthentication();
app.Use(async (context, next) =>
{
    var authentication = await context.AuthenticateAsync();
    if (authentication.Succeeded && authentication.Principal is not null)
    {
        context.RequestServices.GetRequiredService<ActorRequestContext>()
            .Set(ActorMapper.FromVerified(authentication.Principal));
    }
    await next(context);
});
app.UseAuthorization();

app.MapPost("/orders", async (CreateOrderRequest request, Actor actor, ICoreApi core) =>
    await core.CreateOrderAsync(actor, request)).RequireAuthorization();

public sealed class ValkeyTicketStore(IDistributedCache cache) : ITicketStore { }
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
`Add<T>` で command を登録し、依存は constructor、引数は型でバインドする。

```csharp
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
handler の依存は、`IMessageBus` を含め constructor で受け取る。
handler で、実行時の IoC 解決を使わない。
handler は CancellationToken を受け取り、token を受ける全ての非同期 API へ渡す。
再配送契約を持つ source の event は durable inbox の容量を予約し、payload の commit 後だけ upstream delivery ack を返す。
inbox processing completion と処理 item の削除は、処理結果と処理済み記録の commit 後だけ行う。
外部効果には、配備上の consumer 名に依存しない安定した effect operation の識別子と event ID から作る冪等キーを渡す。
外部効果が成功した後に処理済み記録を commit し、その後に inbox processing completion を行う。
durable inbox が満杯なら nack または再試行可能な失敗を返し、使用量、上限、backlog、nack を監視へ出す。

### 根拠
queue と scheduler を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
handler の依存を constructor で受ければ、依存がシグネチャに現れる。
`IMessageBus` を method parameter で受けず constructor に揃えると、handler の依存が一箇所に現れる。
CancellationToken を下流へ渡せば、worker の停止と期限切れが非同期処理の末端まで伝わる。
実行時の IoC 解決は、依存をシグネチャから隠し、コンパイル時の誤りを実行時へ遅らせる。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。
payload commit 後だけ upstream delivery ack を返せば、前段の停止で未確定になった event を source から再配送できる。
処理結果と処理済み記録の commit 後だけ inbox processing completion を行えば、後段の停止で item を再処理できる。
外部効果の境界へ安定した冪等キーを渡せば、効果成功後から処理済み記録前の停止でも再配送の結果を一度分にできる。
容量を予約できない event を nack すれば、必要な入力を受領済みとして失わない。

### 完了条件
worker が、Wolverine を PostgreSQL の queue と scheduler に限って使っている。
handler の依存が、`IMessageBus` を含め constructor で受け取られている。
handler で、実行時の IoC 解決が使われていない。
CancellationToken が、token を受ける全ての非同期 API へ渡されている。
broker・durable workflow・外部の message bus として、使われていない。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
外部効果に安定した effect operation の識別子と event ID から作った冪等キーが渡され、効果成功後に処理済み記録が確定している。
payload commit と、外部効果成功と、処理済み記録 commit の各前後で停止して再配送しても、結果が一度分になることが実行テストで検証されている。
durable inbox の容量上限で nack または再試行可能な失敗が返され、使用量、上限、backlog、nack が監視されている。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
handler で、実行時に IoC から依存を解決すること。
`IMessageBus` を、handler method の parameter で受け取ること。
token を受ける非同期 API への CancellationToken の伝播を途切れさせること。
payload の durable inbox への commit 前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit 前に、inbox processing completion または処理 item の削除を行うこと。
外部効果の成功前に、処理済みを記録すること。
配備上の consumer 名を、外部効果の冪等キーに使うこと。
durable inbox が満杯の event を受領済みとして捨てること。

### 行動
永続化を PostgreSQL に限り、`IMessageBus` を含む handler の依存を constructor で受ける。
handler の CancellationToken を、token を受ける全ての非同期 API へ渡す。
予約は durable な scheduler で行う。
受領時に durable inbox の容量を予約し、payload を commit してから upstream delivery ack を返す。
処理結果と処理済み記録を retention の同じ transaction で確定してから、inbox processing completion を行う。
外部効果へ安定した effect operation の識別子と event ID の組を冪等キーとして渡し、成功後に処理済み記録を commit する。
payload commit、外部効果成功、処理済み記録 commit の各直前と直後へ停止を注入し、再配送後の結果が一度分であることをテストする。
容量を予約できない場合は nack または再試行可能な失敗を返し、inbox の使用量、上限、backlog、nack を観測する。

### 例
永続化は PostgreSQL に閉じ、`IMessageBus` を含む依存は constructor で受ける。token を受けない API の直前で取り消しを確認する。inbox は payload の durable commit、delivery ack、外部効果、処理済み記録、完了の順に進める。

```csharp
builder.UseWolverine(options => options.PersistMessagesWithPostgresql(connectionString));
public sealed class ShipOrderHandler(IOrderRepository repository, IMessageBus bus)
{
    public async Task HandleAsync(ShipOrder message, CancellationToken cancellationToken)
    {
        await repository.MarkShippedAsync(message.OrderId, cancellationToken);
        cancellationToken.ThrowIfCancellationRequested();
        await bus.ScheduleAsync(new ConfirmDelivery(message.OrderId), 3.Days());
    }
}

public sealed class ProjectionHandler(IDurableInbox inbox, IEventSource source, IPaymentPort payment)
{
    public async Task HandleAsync(ProjectOrder message, CancellationToken cancellationToken)
    {
        var permit = await inbox.TryReserveAsync(cancellationToken) ?? throw new RetryableReceiveException();
        var item = await inbox.CommitPayloadAsync(permit, message, cancellationToken);
        await source.DeliveryAckAsync(message.Id, cancellationToken);
        var effectKey = EffectKey.Create("capture-payment", message.Id);
        await payment.CaptureAsync(message.Amount, effectKey, cancellationToken);
        await inbox.RecordProcessedAsync(item, cancellationToken);
        await inbox.CompleteAsync(item, cancellationToken);
    }
}
```

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
アセンブリ内だけで使う型は `internal`、1ファイルに閉じる型は `file` にする。

```csharp
internal sealed class OrderStore { }
file sealed class JsonHelper { }
```

## 参照
境界と依存の向きは [separation](../../principles/separation.md)、入口での評価は [authorization](../../concerns/authorization.md)、攻撃面の最小化は [security](../../concerns/security.md)、資格情報の検証と actor の構築は [authentication](../../concerns/authentication.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
認証チケットの永続化は [retention](./retention.md) に従う。
