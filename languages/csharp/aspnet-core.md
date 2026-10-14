# ASP.NET Core

## server

用途は、HTTP の API を公開する surface の骨格である。
採用は、C# は ASP.NET Core の Minimal API である。
判断基準は、依存を組立点から handler へ注入でき、境界の仕込みを middleware で一括して積めることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止とリリースポリシーの変化を再評価のトリガーとする。

### 要求
server は ASP.NET Core の Minimal API で組み、endpoint の登録はコンテキストごとの登録に分ける。
境界の仕込みは middleware で一括して積み、認証を認可の前に、認可を業務の前に置く。
server の認証境界は検証済み `ClaimsPrincipal` を認証主体へ確定し、認証主体と資格情報の許可範囲を認証と認可の内側に保持する。
`ClaimsPrincipal`、token、claim、認証主体を core の公開 API または業務へ渡さず、core の公開 API が受け取るのは、検証済み入力と、主体を必要とする operation の認証主体から対応づけた業務入力だけにする。
認可は [declarative-access-guards](../../concerns/authorization/declarative-access-guards.md) の「認可の宣言を公開入口で強制する」に従い、endpoint は [structure/contracts/adapters](../../structure/contracts/adapters.md) が公開する宣言された保護を適用する入口だけを呼び、認証主体をその入口へ渡す。
endpoint は `RequireAuthorization()` で認証済みの主体を要求するか `AllowAnonymous` で匿名公開を宣言し、どちらもない endpoint は `AuthorizationOptions.FallbackPolicy` の拒否 policy で拒否する。
操作と対象の policy は adapter の入口が適用し、endpoint の `RequireAuthorization()` だけで満たしたとみなさず、handler は認可を呼ばず許可結果を受け取らない。
handler の契約のデータは generated の DTO で受け渡し、形式と制約を通った入力を契約 adapter の保護された公開入口へ渡す。
生成 DTO の decode と未知項目の捕捉は [translation](./translation.md)、DTO と application の写像の所有者は [structure/contracts/adapters](../../structure/contracts/adapters.md) に従う。
冪等な endpoint は、認証主体の ID、匿名の安定した session または client の opaque scope、logical system actor の ID を、要求の種別に応じた actor scope として retention へ渡す。
actor scope は冪等 key を主体の種別ごとに分ける retention の scope 識別であり、core の業務入力でも業務のモデリングの役割でもない。
multi-tenant operation は、認証済み claim または membership、authorization 済み選択、匿名の検証済み host または route と session/client context、system の logical actor 設定のいずれかから `TenantId` を構築する。
single-tenant operation は正準な single-tenant sentinel を、tenant の概念を持たない operation は正準な no-tenant sentinel を retention へ渡す。
安定した匿名 scope がない endpoint は、server 発行の全体で一意な key と proof だけを受け付ける。

### 根拠
endpoint の登録をコンテキストごとに分ければ、面が変更理由ごとに分かれ、コンテキストが自分の endpoint を所有する。
境界の仕込みを middleware で一括して積めば、横断の関心が入口に集まる。
認証を認可の前に置けば、認証主体が確定してから認可が評価できる。
認可を業務の前に置けば、拒否が業務に届く前に止まる。
認証主体を認証と認可の内側に保ち、主体を必要とする operation にだけ業務入力を対応づければ、core は token と認証方式を知らず、主体を使わない operation の署名が認証の変更に巻き込まれない。
認証の要求と匿名公開を endpoint に宣言し、宣言のない endpoint を fallback で拒否すれば、保護の抜けが公開のまま残らず、匿名公開は意図した宣言として区別できる。
操作と対象の policy を adapter の入口が適用すれば、HTTP 以外の呼び出し元も同じ保護を通り、endpoint の認証の要求だけで対象の単位の認可を満たしたとみなさずに済む。

### 完了条件
server が、Minimal API で組まれている。
endpoint の登録が、コンテキストごとの登録に分かれている。
境界の仕込みが middleware で一括して積まれ、認証・認可・業務の順序になっている。
検証済み `ClaimsPrincipal` が server の認証境界で認証主体へ確定されて境界内に保持され、core の公開 API が認証に関する値を受け取らず、主体を必要とする operation の業務入力だけが認証主体から対応づけられている。
全 endpoint が `RequireAuthorization()` か `AllowAnonymous` の宣言を持ち、宣言のない endpoint が fallback policy で拒否され、endpoint が adapter の宣言された保護を適用する入口だけを呼び、handler が認可を呼ばず許可結果を受け取っていない。
冪等な endpoint が actor scope と tenant の全種別を retention の scope へ写し、未検証 tenant と `TenantId`・single-tenant sentinel・no-tenant sentinel の相互混同を拒否し、proof のない別 client へ保存済み response を返さないことが結合テストで検証されている。

### 禁止事項
認可を、認証の前に置くこと。
`ClaimsPrincipal`、token、claim、認証主体を core の公開 API または業務へ渡すこと。
認証主体の確定を汎用の業務の主体の型の構築と同一視し、全ての operation へ引数として渡すこと。
宣言のない endpoint を、許可で開いたままにすること。
endpoint の `RequireAuthorization()` だけで、操作と対象の認可を満たしたとみなすこと。
handler に認可の呼出と許可結果の引数を置くこと。
adapter の保護を適用する入口を通さず、endpoint から core の公開 API を直接呼ぶこと。
endpoint を、一箇所にまとめてベタ書きすること。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せずに保存済み response を返すこと。
未検証の tenant context を `TenantId` として retention へ渡すこと。

### 行動
endpoint の登録をコンテキストごとの拡張メソッドに分け、Program.cs は合成だけにする。
middleware を認証・認可・業務の順に積む。
検証済み `ClaimsPrincipal` を認証 middleware で認証主体へ確定して server の境界内に保持し、endpoint から契約の形式と制約を通った生成 DTO と認証主体を adapter の宣言された保護を適用する入口へ渡す。
adapter の入口が認証主体から対応づけた業務入力と検証済み入力だけを core の公開 API へ渡す。
全 endpoint に `RequireAuthorization()` か `AllowAnonymous` を宣言し、`AuthorizationOptions.FallbackPolicy` に拒否 policy を置く。
actor scope と tenant の種別を retention の scope へ写し、安定した匿名 scope がなければ server 発行 key と proof を使う。
multi-tenant は認証済み、匿名、system の検証済み context から `TenantId` を構築する。
single-tenant は正準な single-tenant sentinel、tenant の概念外は正準な no-tenant sentinel を使う。
全 actor scope と tenant の種別の競合、未検証 tenant と三つの tenant scope 表現の相互混同、proof のない別 client への response 漏洩拒否を結合テストで確かめる。

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

宣言のない endpoint は fallback policy で拒否し、匿名公開は `AllowAnonymous` で宣言する。

```csharp
builder.Services.AddAuthorization(options =>
    options.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAssertion(_ => false).Build());
app.MapGet("/health", () => Results.Ok()).AllowAnonymous();
```

## server の middleware

用途は、HTTP の経路の横断処理を、層として合成する機構である。
採用は、C# は ASP.NET Core の組み込みの middleware であり、別の機構を重ねない。
判断基準は、採用済みの server の骨格と同じ抽象で層を積め、横断処理を経路の定義から分離できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## BFF の session 管理

用途は、BFF が session を保持し cookie で運ぶ機構である。
採用は、C# は ASP.NET Core 標準の cookie 認証であり、別の機構を重ねない。
判断基準は、Secure・HttpOnly・SameSite=Strict の cookie 属性を、既定または明示の設定で強制できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## OIDC クライアント

用途は、OIDC の code と PKCE のフローを終端し ID Token を検証するクライアントである。
採用は、C# は ASP.NET Core 標準の OpenID Connect handler であり、別の機構を重ねない。
判断基準は、authorization code と PKCE の flow を終端し、ID Token の署名、issuer、audience、nonce を検証できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## BFF

### 要求
session は ASP.NET Core の cookie 認証、OIDC は標準の handler を使う。
token の管理は Duende.AccessTokenManagement を使う。
CSRF の検査は、session に保持した token と専用 header の一致を検査する CSRF middleware で行う([structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う)。
access token と refresh token は server 側に保持し、ブラウザへは session を指す識別子だけを持つ認証の cookie を渡す。
認証チケットは `ITicketStore` で `CookieAuthenticationOptions.SessionStore` に差し、retention の Valkey に保持する。
認証 middleware は、検証済みの `ClaimsPrincipal` を `SubjectMapper` で認証主体へ確定する。
認証 middleware は、認証主体を server の境界内の request-scoped `SubjectAccessor` へ格納する。
request-scoped の `AuthenticatedSubject` は、同じ `SubjectAccessor` から DI で解決する。
BFF の route は、`AuthenticatedSubject` と境界で検証した入力を、[structure/contracts/adapters](../../structure/contracts/adapters.md) の宣言された保護を適用する入口へ渡し、core の公開 API へは渡さない。
BFF の route は、`ClaimsPrincipal` を参照しない。
`SubjectMapper` は、認証 middleware からだけ呼び出す。

### 根拠
`SaveTokens=true` は既定で token を `AuthenticationProperties` に載せ、`SessionStore` を差さない cookie 認証はその `AuthenticationProperties` を含む認証チケットをそのまま cookie に暗号化して詰める。
`SessionStore` に `ITicketStore` を差せば、cookie は session を指す識別子だけになり、token を含む認証チケットは server 側の store に残る。
Duende.AccessTokenManagement は、token の保持と更新を server 側で担う。
principal を認証境界で認証主体へ確定して境界内に保てば、core は token と認証方式を知らず、主体を必要とする operation だけが adapter の対応づけた業務入力として主体を受け取る。
認証主体を request-scoped の `SubjectAccessor` に一度格納し、DI で同じ認証主体を adapter の入口へ渡せば、認証境界と route が別の主体を構築しない。
route が埋め込んだ core の公開 API を呼べば、認証境界と業務処理を同じ process の型付き呼出で接続できる。

### 完了条件
session が cookie 認証、OIDC が標準の handler で行われている。
token の管理が Duende.AccessTokenManagement で行われている。
access token・refresh token が server 側の `ITicketStore` に保持され、ブラウザへ渡る cookie が session を指す識別子だけである。
検証済みの `ClaimsPrincipal` が、認証 middleware の `SubjectMapper` で認証主体へ確定されている。
認証 middleware が、認証主体を request-scoped `SubjectAccessor` へ格納している。
DI が同じ `SubjectAccessor` から `AuthenticatedSubject` を解決し、BFF の route へ注入している。
BFF の route が、注入された `AuthenticatedSubject` と検証済みの入力を adapter の宣言された保護を適用する入口へ渡し、core の公開 API を直接呼んでいない。
BFF の route が、`ClaimsPrincipal` を参照していない。
`SubjectMapper` が、認証 middleware からだけ呼び出されている。
CSRF の検査が、[structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) の方式で行われている。

### 禁止事項
access token・refresh token を、ブラウザへ渡すこと。
`SessionStore` を差さずに `SaveTokens` だけに頼り、token を含む認証チケットを cookie に詰めてブラウザへ渡すこと。
token の管理で、Duende の商用製品(BFF・IdentityServer)に踏み込むこと。
ASP.NET Core の Antiforgery を CSRF の検査に使い、期待値の保持を cookie に頼ること。
cookie の HttpOnly・Secure・SameSite を、緩めること。
BFF の route から、埋め込んだ core の公開 API 以外の業務処理を呼ぶこと。
token、未検証の principal、認証主体を、core へ渡すこと。
BFF の route で、`ClaimsPrincipal` を受け取ること。
BFF の route で、adapter の保護を適用する入口を通さず core の公開 API を呼ぶこと。
認証 middleware の外から、`SubjectMapper` を呼び出すこと。
認証 middleware が格納した認証主体と異なる主体を、BFF の route で構築すること。

### 行動
OIDC を code と PKCE で server で終端し、token を server 側に保持する。
`CookieAuthenticationOptions.SessionStore` に `ITicketStore` の実装を差し、認証チケットを retention の Valkey に保持する。
cookie を HttpOnly・Secure・SameSite=Strict にする。
認証 middleware で検証済みの `ClaimsPrincipal` を `SubjectMapper` へ渡し、得た認証主体を request-scoped `SubjectAccessor` へ格納する。
同じ `SubjectAccessor` から request-scoped の `AuthenticatedSubject` を DI で解決する。
BFF の route は、DI で注入された `AuthenticatedSubject` と検証済みの入力を adapter の宣言された保護を適用する入口へ渡す。
BFF の route から `ClaimsPrincipal` と `SubjectMapper` の参照を除く。
CSRF の検査は、session の token と専用 header の一致を CSRF middleware で検査する。

### 例
チケットは retention の Valkey に保持し、cookie には識別子だけを置く。`ITicketStore` は DI に登録し、options 構築時に解決する。検証済み principal は認証主体へ確定して request scope に保持し、route から検証済み入力とともに adapter の入口へ渡す。

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
builder.Services.AddScoped<SubjectAccessor>();
builder.Services.AddScoped(sp => sp.GetRequiredService<SubjectAccessor>().RequiredSubject);

app.UseAuthentication();
app.Use(async (context, next) =>
{
    var authentication = await context.AuthenticateAsync();
    if (authentication.Succeeded && authentication.Principal is not null)
    {
        context.RequestServices.GetRequiredService<SubjectAccessor>()
            .Set(SubjectMapper.FromVerified(authentication.Principal));
    }
    await next(context);
});
app.UseAuthorization();

```

保護された契約 adapter を呼ぶ handler の本体には、要求の境界で生成した絶対期限と、ASP.NET Core が要求から渡す取消を個別に渡す。
認証主体と実行 metadata を一つの入力型にまとめない。

```csharp
Task<IResult> CreateOrder(
    CreateOrderRequest request,
    AuthenticatedSubject subject,
    ICreateOrderAdapter adapter,
    Deadline deadline,
    CancellationToken cancellationToken) =>
    adapter.InvokeAsync(subject, request, deadline, cancellationToken);
```

## 公開するエラーを境界で problem+json へ写す

### 要求
`Result` から HTTP の応答への写像は handler の終端に置き、binding から生成したエラーの DTO を RFC 9457 の problem+json として返す。
HTTP status、header、content type は Minimal API の応答で組み立て、`ProblemDetails` の機構の出力にも生成したエラーの契約を適用する。
公開契約の field を、別の手書き DTO へ写し直さない。
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
公開契約のエラーの body が binding から生成した DTO に従い、handler がコンテキストの domain エラーや内部詳細を直接公開していない。

### 禁止事項
エラーの写像を、handler の各所に散らすこと。
内部の実装の詳細を、応答に出すこと。

### 行動
契約 adapter の公開入口が返す生成されたエラーの DTO と binding を使い、handler の終端で HTTP status と problem+json の応答を組み立てる。
`ProblemDetails` の機構の serializer と例外 handler も、公開する body が generated の契約に一致するように設定する。
未処理の例外を例外 handler の middleware で一括変換する。
