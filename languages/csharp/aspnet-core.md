# ASP.NET Core

## server

用途は、HTTP の API を公開する surface の骨格である。
採用は、C# は ASP.NET Core の Minimal API である。
判断基準は、依存を組立点から handler へ注入でき、境界の仕込みを middleware で一括して積めることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止とリリースポリシーの変化を再評価のトリガーとする。

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

## server の middleware

用途は、HTTP の経路の横断処理を、層として合成する機構である。
C# は ASP.NET Core の組み込みの middleware で満たし、別の採用を持たない。
判断基準は、採用済みの server の骨格と同じ抽象で層を積め、横断処理を経路の定義から分離できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## BFF の session 管理

用途は、BFF が session を保持し cookie で運ぶ機構である。
C# は ASP.NET Core 標準の cookie 認証を使い、外部ライブラリを別に選ばない。
判断基準は、Secure・HttpOnly・SameSite=Strict の cookie 属性を、既定または明示の設定で強制できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## OIDC クライアント

用途は、OIDC の code と PKCE のフローを終端し ID Token を検証するクライアントである。
C# は ASP.NET Core 標準の handler を使い、外部ライブラリを別に選ばない。
判断基準は、authorization code と PKCE の flow を終端し、ID Token の署名、issuer、audience、nonce を検証できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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

## 公開するエラーを境界で problem+json へ写す

### 要求
`Result` から HTTP の応答への写像は handler の終端に置き、`ProblemDetails` の機構で RFC 9457 の problem+json へ写す。
未処理の例外は例外 handler の middleware が一括で problem+json へ変換する。
内部の実装の詳細を、応答に出さない。

### 根拠
エラーの写像を handler の各所に書くと、表現が揺れ重複する。
handler の終端に置き、未処理の例外を middleware で一括変換すれば、公開するエラーの形が一箇所で決まる。
problem+json の標準の形に従えば、利用側が機械的に扱える。
内部の詳細を応答に出すと、攻撃の手がかりを与える。

### 完了条件
失敗が、problem+json へ写されている。
写像が handler の終端と例外 handler の middleware に集約され、各所に散っていない。
応答に、内部の実装の詳細が出ていない。

### 禁止事項
エラーの写像を、handler の各所に散らすこと。
内部の実装の詳細を、応答に出すこと。

### 行動
`Result` から応答への写像を handler の終端に置き、`ProblemDetails` で problem+json へ写す。
未処理の例外を例外 handler の middleware で一括変換する。
