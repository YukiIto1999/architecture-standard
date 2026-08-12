# publication

## 概要
publication は、Rust で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization.md) が定める入口での評価・[security](../../concerns/security.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication.md) が定める資格情報の検証と actor の構築を、Rust の機構で満たす。

## server

### 要求
server は axum で組み、依存は State で handler へ渡す。
router はコンテキストごとに分けて合成し、境界の仕込みは tower の middleware で一括して積む。
認証は route の一致時にだけ走る層に置く。
server の認証境界は検証済み principal を actor へ写し、route から埋め込んだ core の公開 API へ actor だけを渡す。
principal、token、claim を core の公開 API または業務へ渡さない。
server の想定内の失敗は、RFC 9457 の problem+json へ `IntoResponse` の実装で写す。
server の未処理の panic は、`CatchPanicLayer` で捕捉して内部の詳細を含まない problem+json へ写す。
server の取り消しは、想定内の失敗の応答へ変換しない。
冪等な endpoint は、認証済み actor ID、匿名の安定した session または client の opaque scope、logical system actor ID を要求の種別に応じた actor scope として retention へ渡す。
multi-tenant operation は、認証済み claim または membership、authorization 済み選択、匿名の検証済み host または route と session/client context、system の logical actor 設定のいずれかから `TenantId` を構築する。
single-tenant operation は正準な single-tenant sentinel を、tenant の概念を持たない operation は正準な no-tenant sentinel を retention へ渡す。
安定した匿名 scope がない endpoint は、server 発行の全体で一意な key と proof だけを受け付ける。

### 根拠
依存を State で handler へ渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
router をコンテキストごとに分けて合成すれば、面が変更理由ごとに分かれる。
境界の仕込みを tower の middleware で一括して積めば、横断の関心が入口に集まる。
認証を route の一致時にだけ走る層に置けば、未一致の要求が 404 のまま留まり、認証で 404 が 401 に化けて対象の存在を露出しない。
`IntoResponse` に集約すれば、想定内の失敗の HTTP 表現が handler ごとに揺れない。
`CatchPanicLayer` で server の最上位を覆えば、欠陥を個々の handler で想定内の失敗に変えずに報告できる。

### 完了条件
server が axum で組まれ、依存が State で handler へ渡されている。
router が、コンテキストごとに合成されている。
境界の仕込みが middleware で一括して積まれ、認証が route の一致時にだけ走る層に置かれている。
検証済み principal が server の認証境界で actor へ写され、core の公開 API が actor だけを受け取っている。
想定内の失敗が、`IntoResponse` の実装で problem+json へ写されている。
未処理の panic が、`CatchPanicLayer` で内部の詳細を含まない problem+json へ写されている。
取り消しが、想定内の失敗の応答へ変換されていない。
冪等な endpoint が actor と tenant の全種別を retention の scope へ写し、未検証 tenant と `TenantId`・single-tenant sentinel・no-tenant sentinel の相互混同を拒否し、proof のない別 client へ保存済み response を返さないことが結合テストで検証されている。

### 禁止事項
認証を、route の一致に関わらず走る層に置き、404 を 401 に化けさせること。
principal、token、claim を core の公開 API または業務へ渡すこと。
依存を、handler の中で直接生成すること。
想定内の失敗の写像を、handler ごとに散らすこと。
未処理の panic の内部詳細を、problem+json に出すこと。
取り消しを、想定内の失敗の problem+json へ写すこと。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せずに保存済み response を返すこと。
未検証の tenant context を `TenantId` として retention へ渡すこと。

### 行動
依存を State で渡し、router をコンテキストごとに nest・merge で合成する。
境界の仕込みを ServiceBuilder で積み、認証は route の一致時にだけ走る層に置く。
検証済み principal を認証 middleware で actor へ写し、route から actor と検証済み入力だけを core の公開 API へ渡す。
想定内の失敗を `IntoResponse` の実装で problem+json へ写す。
`CatchPanicLayer` を ServiceBuilder に積み、未処理の panic を内部詳細のない problem+json へ写す。
actor と tenant の種別を retention の scope へ写し、安定した匿名 scope がなければ server 発行 key と proof を使う。
multi-tenant は認証済み、匿名、system の検証済み context から `TenantId` を構築する。
single-tenant は正準な single-tenant sentinel、tenant の概念外は正準な no-tenant sentinel を使う。
全 actor/tenant 種別の競合、未検証 tenant と三つの tenant scope 表現の相互混同、proof のない別 client への response 漏洩拒否を結合テストで確かめる。

### 例
認証 middleware を router 全体へ置くと、未一致の要求に返すべき 404 が 401 に変わる。

```rust
let app = Router::new().route("/", get(handler)).layer(middleware::from_fn(auth));
```

依存は `State` で渡し、router はコンテキストごとに分け、認証は route が一致した後だけ適用する。

```rust
#[derive(Clone)] struct AppState { /* ... */ }
impl IntoResponse for ApiError {
    fn into_response(self) -> Response { /* ... */ }
}
let app = Router::new()
    .nest("/api", api_router())
    .route_layer(middleware::from_fn(auth))
    .layer(ServiceBuilder::new()
        .layer(CatchPanicLayer::custom(problem_without_internal_detail))
        .layer(TraceLayer::new_for_http()))
    .with_state(state);
```

## BFF

### 要求
session は tower-sessions で扱い、store は fred で Valkey に保持する。
OIDC の code・PKCE・token の交換と更新は、openidconnect を使う。
CSRF の検査は、session に保持した token と専用 header の一致を検査する CSRF middleware で行う([structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う)。
access token と refresh token は server 側の session に保持し、ブラウザへは session を指す cookie だけを渡す。
session cookie の名前は、`__Host-` で始める。
session cookie は、Secure=true、HttpOnly=true、SameSite=Strict、Path=/ を明示する。
session cookie の Domain 属性は、設定しない。
認証の成功時と権限の変更時に、session ID を再生成する。
session には、idle expiry と absolute expiry の両方を設定する。
logout では、共有 store から session を削除する。
back-channel logout token は、署名、issuer、audience、発行時刻、期限、back-channel logout の event claim を検証する。
back-channel logout token の token ID は、一度だけ受理して replay を拒否する。
back-channel logout token に sid があれば `(issuer, sid)` で、なければ `(issuer, subject)` で共有 store の session を特定して失効させる。
token ID の replay 防止記録と session の失効は、共有 store の同じ原子的な操作で確定する。
token の更新は、単一の更新に制御し、競合による上書きを防ぐ。
検証済みの principal は、BFF の認証境界で actor へ写す。
BFF の route は、actor と境界で検証した入力を、埋め込んだ core の公開 API へ渡す。

### 根拠
BFF が token を server 側で保持し、ブラウザへ session を指す cookie だけを渡せば、token がブラウザに出ず、持ち出しの面が消える。
`__Host-` で始まる cookie を Secure、Path=/、Domain 未設定にすれば、host 全体に限定した session cookie を別の domain や狭い path から上書きできない。
HttpOnly は script からの cookie の読み取りを防ぎ、SameSite=Strict は cross-site の要求へ cookie を送らない。
session の store を fred で Valkey に保持すれば、複数のプロセスの間で session の状態が一致し、[structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) が定めるプロセス外の共有ストアへの保持を満たす。
OIDC の ID Token で nonce を検証し、at_hash がある場合に access token との対応を検証すれば、token のすり替えを防げる。
openidconnect で token の交換と更新を同じ OIDC client に閉じれば、protocol の検証と更新経路が分かれない。
認証の成功時と権限の変更時に session ID を再生成すれば、認証前に固定された ID を認証後へ持ち越さない。
idle expiry は使われない session を閉じ、absolute expiry は使われ続ける session にも寿命の上限を置く。
logout で共有 store から削除すれば、別の process も同じ session を受理しない。
back-channel logout token の署名と claim を検証すれば、偽造した通知による session の失効を防げる。
issuer を sid または subject と組にすれば、異なる identity provider の同じ値を取り違えない。
token ID を一度だけ受理すれば、同じ logout token の replay を拒否できる。
replay 防止記録と session 失効を一つの確定点にすれば、停止後の再配送を拒否しながら session だけが残る状態を作らない。
token の更新を単一の更新に制御すれば、競合した更新が互いを上書きせず、有効な token を失わない。
principal を認証境界で actor へ写せば、core は token と認証方式を知らず、検証済みの主体だけを受け取る。
route が埋め込んだ core の公開 API を呼べば、認証境界と業務処理を同じ process の型付き呼出で接続できる。

### 完了条件
session が tower-sessions で扱われ、fred で Valkey に保持されている。
OIDC の code・PKCE・token の交換と更新が openidconnect で行われ、ID Token の nonce と、at_hash がある場合の access token との対応が検証されている。
access token・refresh token が server 側の session に保持され、ブラウザへ token が出ていない。
session cookie の名前が、`__Host-` で始まっている。
session cookie が、Secure=true、HttpOnly=true、SameSite=Strict、Path=/ になっている。
session cookie に、Domain 属性がない。
認証の成功時と権限の変更時に、session ID が再生成されている。
session に、idle expiry と absolute expiry が設定されている。
logout した session が、共有 store から削除されている。
back-channel logout token の署名、issuer、audience、発行時刻、期限、back-channel logout の event claim が検証されている。
back-channel logout token の token ID が、一度だけ受理されている。
sid がある logout token は `(issuer, sid)` で、sid がない token は `(issuer, subject)` で共有 store の session を失効させている。
token ID の replay 防止記録と session の失効が、共有 store の同じ原子的な操作で確定している。
token の更新が、単一の更新に制御されている。
検証済みの principal が、BFF の認証境界で actor へ写されている。
BFF の route が、actor と検証済みの入力を、埋め込んだ core の公開 API へ渡している。
CSRF の検査が、[structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) の方式で行われている。

### 禁止事項
access token・refresh token を、ブラウザへ渡すこと。
`__Host-` で始まらない名前を、session cookie に使うこと。
session cookie の Secure、HttpOnly、SameSite=Strict、Path=/ のいずれかを、省くこと。
session cookie に、Domain 属性を設定すること。
認証前または権限変更前の session ID を、その後も使い続けること。
idle expiry または absolute expiry の片方だけで、session の寿命を決めること。
logout で cookie だけを消し、共有 store の session を残すこと。
未検証の back-channel logout token で、session を失効させること。
back-channel logout token の raw な subject だけで、session を特定すること。
受理済みの token ID を持つ back-channel logout token を、再び処理すること。
token ID の replay 防止記録を、session の失効より先に別の確定点で保存すること。
token の更新を、競合の制御なく並行に許すこと。
BFF の route から、埋め込んだ core の公開 API 以外の業務処理を呼ぶこと。
token または未検証の principal を、core へ渡すこと。

### 行動
openidconnect で OIDC の code と PKCE を server で終端し、token を交換・更新して、ID Token の nonce と、at_hash がある場合の access token との対応を検証する。
token を server 側の session に保持し、ブラウザへは session を指す cookie だけを渡す。
session の store を fred backed の実装に差し、Valkey に保持する。
SessionManagerLayer の builder で、cookie の名前、Secure、HttpOnly、SameSite、Path を明示する。
SessionManagerLayer の builder では、Domain を設定しない。
認証の成功時と権限の変更時に、session ID を再生成する。
idle expiry と absolute expiry を設定する。
logout では共有 store から session を削除する。
back-channel logout token の署名、issuer、audience、発行時刻、期限、event claim を検証する。
sid があれば `(issuer, sid)` を使い、なければ `(issuer, subject)` を使って共有 store の session を失効させる。
検証した token ID の期限付き replay 防止記録と session の失効を、共有 store の同じ原子的な操作で確定する。
token の更新経路に、単一の更新に絞る制御を入れる。
検証済みの principal を認証境界で actor へ写す。
BFF の route から、actor と検証済みの入力を埋め込んだ core の公開 API へ渡す。
CSRF の検査は、session の token と専用 header の一致を CSRF middleware で検査する。

### 例
token をブラウザへ渡すと、持ち出しの面が開く。

```rust
Json(TokenResponse { access_token, refresh_token })
```

cookie 属性を builder で明示し、Domain 属性は設定しない。OIDC の claim と token の対応を検証し、認証後に session ID を再生成して、principal を actor へ写す。

```rust
let session_layer = SessionManagerLayer::new(store)
    .with_name("__Host-session")
    .with_secure(true)
    .with_http_only(true)
    .with_same_site(SameSite::Strict)
    .with_path("/");
let claims = id_token.claims(&client.id_token_verifier(), &nonce)?;
if let Some(at_hash) = claims.access_token_hash() {
    verify_at_hash(at_hash, &access_token)?;
}
regenerate_session_id(&session).await?;
set_session_expiry(&session, idle_expiry, absolute_expiry).await?;
session.insert("actor", to_actor(claims)).await?;

let actor = session.required_actor().await?;
let result = state.core.register(actor, request.try_into()?).await;

delete_session_on_logout(&session, session_store).await?;
let logout = verify_backchannel_logout_token(raw_token, expected_issuer, client_id)?;
let key = match logout.sid() {
    Some(sid) => SessionKey::IssuerSid(logout.issuer(), sid),
    None => SessionKey::IssuerSubject(logout.issuer(), logout.required_subject()?),
};
invalidate_session_once(session_store, logout.token_id(), logout.expires_at(), key).await?;
```

## console

### 要求
console は clap で組み、引数を型で宣言して境界で一度 parse する。

### 根拠
引数を型で宣言し境界で一度 parse すれば、引数が型に現れ、未検証の値が内側に入らない。
文字列のキーで引数を取り出すと、型に現れず手で復元することになる。

### 完了条件
console が clap で組まれている。
引数が型で宣言され、境界で一度 parse されている。

### 禁止事項
引数を、文字列のキーで取り出すこと。

### 行動
引数を struct・enum と derive で宣言し、入口で一度 parse する。

### 例
文字列のキーで引数を取り出すと、引数が型に現れず、手作業での復元が必要になる。

```rust
let matches = Command::new("app").arg(Arg::new("verbose")).get_matches();
```

derive で引数の型を宣言し、入口の一度の parse で構造化する。

```rust
#[derive(Parser)] struct Cli { #[arg(short, long)] verbose: bool, #[command(subcommand)] command: Commands }
let cli = Cli::parse();
```

## worker

### 要求
worker は apalis を、PostgreSQL を backend にした queue と scheduler に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
handler の依存は `Data` extractor で受け取り、handler の中で直接生成しない。
再配送契約を持つ source の event は durable inbox の容量を予約し、payload の commit 後だけ upstream delivery ack を返す。
inbox processing completion と処理 item の削除は、処理結果と処理済み記録の commit 後だけ行う。
外部効果には、配備上の consumer 名に依存しない安定した effect operation の識別子と event ID から作る冪等キーを渡す。
外部効果が成功した後に処理済み記録を commit し、その後に inbox processing completion を行う。
durable inbox が満杯なら nack または再試行可能な失敗を返し、使用量、上限、backlog、nack を監視へ出す。

### 根拠
queue を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
apalis の cron 機構を scheduler に使えば、定期実行も同じ PostgreSQL backend の queue に閉じる。
job の処理を queue から受ける形にすれば、副作用が処理の中に集まる。
`Data` extractor で依存を渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。
payload commit 後だけ upstream delivery ack を返せば、前段の停止で未確定になった event を source から再配送できる。
処理結果と処理済み記録の commit 後だけ inbox processing completion を行えば、後段の停止で item を再処理できる。
外部効果の境界へ安定した冪等キーを渡せば、効果成功後から処理済み記録前の停止でも再配送の結果を一度分にできる。
容量を予約できない event を nack すれば、必要な入力を受領済みとして失わない。

### 完了条件
worker が、apalis を PostgreSQL を backend にした queue と scheduler に限って使っている。
broker・durable workflow・外部の message bus として、使われていない。
handler の依存が、`Data` extractor で受け取られ、handler の中で直接生成されていない。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
外部効果に安定した effect operation の識別子と event ID から作った冪等キーが渡され、効果成功後に処理済み記録が確定している。
payload commit と、外部効果成功と、処理済み記録 commit の各前後で停止して再配送しても、結果が一度分になることが実行テストで検証されている。
durable inbox の容量上限で nack または再試行可能な失敗が返され、使用量、上限、backlog、nack が監視されている。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
handler の中で、依存を直接生成すること。
payload の durable inbox への commit 前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit 前に、inbox processing completion または処理 item の削除を行うこと。
外部効果の成功前に、処理済みを記録すること。
配備上の consumer 名を、外部効果の冪等キーに使うこと。
durable inbox が満杯の event を受領済みとして捨てること。

### 行動
queue を PostgreSQL の backend に限り、apalis で enqueue と worker を組む。
定期実行は apalis の cron 機構で scheduler として組む。
worker の起動は WorkerBuilder で組み、apalis の Monitor で走らせる。
handler の依存は `Data` extractor で渡す。
受領時に durable inbox の容量を予約し、payload を commit してから upstream delivery ack を返す。
処理結果と処理済み記録を retention の同じ Transaction で確定してから、inbox processing completion を行う。
外部効果へ安定した effect operation の識別子と event ID の組を冪等キーとして渡し、成功後に処理済み記録を commit する。
payload commit、外部効果成功、処理済み記録 commit の各直前と直後へ停止を注入し、再配送後の結果が一度分であることをテストする。
容量を予約できない場合は nack または再試行可能な失敗を返し、inbox の使用量、上限、backlog、nack を観測する。

### 例
queue は PostgreSQL backend に閉じる。`PostgresStorage::push` は可変参照を要求するため、storage を可変束縛にする。worker の起動は `WorkerBuilder` と apalis の `Monitor` で組むが、版によって変わる具体の呼び出し形はここでは固定しない。

```rust
let mut storage = PostgresStorage::new(&pool);
storage.push(SendEmail { to }).await?;
let permit = inbox.try_reserve().ok_or(ReceiveError::Retryable)?;
let item = inbox.commit_payload(permit, event).await?;
source.delivery_ack(item.event_id()).await?;
let key = EffectKey::new("capture-payment", item.event_id());
payment.capture(item.amount(), key).await?;
record_processed_in_transaction(item.id()).await?;
inbox.complete(item.id()).await?;
```

## desktop と mobile の host

### 要求
Rust の core を持つ desktop と mobile の host は Tauri とし、同じ viewer と同じ core を desktop と mobile の shell で共有する。
desktop と mobile の各 shell は、host の認証 adapter が保持する資格情報を IPC の認証境界で検証して actor を構築する。
IPC の command は actor と資格情報を frontend から受け取らず、認証境界が構築した actor と検証済み入力だけを core へ渡す。
認証の資格情報は host の認証 adapter に置き、業務の secret と判断は core に置いて frontend に出さない。

### 根拠
Tauri は core のプロセスが唯一の入口として IPC を一元に統べ、webview は viewer を動かす。
host が保持する資格情報から IPC の認証境界で actor を構築すれば、frontend が actor を指定できず、core は認証方式を知らずに済む。
認証の資格情報を host の認証 adapter に置き、業務の secret と判断を core に置けば、frontend へ秘密が出ない。
同じ viewer と core を両方の shell で共有すれば、面の重複が避けられる。

### 完了条件
desktop と mobile の host が、Tauri である。
同じ viewer と core が、両方の shell で共有されている。
desktop と mobile の各 IPC の認証境界が、host の認証 adapter の資格情報を検証して actor を構築している。
core の公開 API が、actor と検証済み入力だけを受け取っている。
認証の資格情報が host の認証 adapter に、業務の secret と判断が core に置かれ、frontend に出ていない。

### 禁止事項
secret や業務の判断を、frontend に置くこと。
actor または資格情報を、frontend から IPC の command へ渡すこと。
資格情報を、core の公開 API へ渡すこと。

### 行動
host を Tauri にし、IPC を型付きの command で一元化する。
desktop と mobile の各 IPC の入口で host の認証 adapter の資格情報を検証し、actor を構築する。
actor と検証済み入力だけを core の公開 API へ渡す。
認証の資格情報を host の認証 adapter に、業務の secret と判断を core に置く。

### 例
資格情報は host 側で actor へ写し、frontend の入力と actor だけを core へ渡す。

```rust
#[tauri::command]
fn place_order(state: State<AppState>, request: OrderRequest) -> Result<OrderId, AppError> {
    let actor = state.authentication.verify_and_map()?;
    state.core.place_order(actor, request.try_into()?)
}
```

## extension の接続

### 要求
extension が接続する core のプロセスは、外へ出すのを小さい契約だけにして公開する。これを tower-lsp-server の custom method による JSON-RPC で満たし、直列化は serde を使う。
標準の言語機能は、tower-lsp-server の LanguageServer で LSP として公開する。
LSP の framing と protocol を再実装しない。

### 根拠
core を JSON-RPC の小さい契約で公開すれば、外へ出すのは契約だけになる。
tower-lsp-server の custom method は protocol と transport を担うので、自前で書くのは小さい契約の振る舞いと serde の値だけになる。
LSP の framing と protocol を再実装すると、手書きの処理が関心を境界の外へ漏らす。

### 完了条件
core のプロセスが tower-lsp-server の custom method による JSON-RPC で公開され、直列化に serde が使われている。
標準の言語機能が、tower-lsp-server の LanguageServer で公開されている。
LSP の framing と protocol を、再実装していない。

### 禁止事項
LSP の framing や protocol を、再実装すること。
tower-lsp-server の外に、extension 用の JSON-RPC framing を重ねること。

### 行動
core の小さい契約を tower-lsp-server の custom method で公開し、直列化を serde で行う。
標準の言語機能は、tower-lsp-server で LanguageServer を実装する。

### 例
標準 LSP と小さい application protocol を、同じ transport へ載せる。

```rust
let (service, socket) = LspService::build(|client| Backend { client })
    .custom_method("project/read-model", Backend::read_model)
    .finish();
Server::new(stdin(), stdout(), socket).serve(service).await;
```

## 可視性

### 要求
公開面は crate の境界で閉じ、crate の外へ出すもの以外は pub(crate) 以下に保つ。
skeleton の境界の分割と依存方向の検証は、inspection の構造検査に従う。

### 根拠
crate の境界で公開面を閉じ、外へ出すもの以外を pub(crate) 以下に保てば、内部の実装が外から触れない。
skeleton の境界を workspace の crate に分けて依存方向を Cargo の依存で強制する検証は inspection が正本として持ち、publication では重ねて定めない。

### 完了条件
公開面が、crate の境界で閉じている。
crate の外へ出すもの以外が、pub(crate) 以下である。

### 禁止事項
内部の実装を、crate の外から触れる形で公開すること。

### 行動
外向きの API だけを pub にし、内部を pub(crate) 以下に保つ。

### 例
内部の実装まで `pub` にすると、crate の外から直接触れられる。

```rust
pub struct Connection { pub raw_handle: RawHandle }
```

外向き API だけを `pub` にし、内部は `pub(crate)` 以下に保つ。

```rust
pub struct Connection { pub(crate) raw_handle: RawHandle }
pub fn open() -> Connection { open_internal() }
```

## 参照
境界と依存の向きは [separation](../../principles/separation.md)、入口での評価は [authorization](../../concerns/authorization.md)、攻撃面の最小化は [security](../../concerns/security.md)、資格情報の検証と actor の構築は [authentication](../../concerns/authentication.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
認証チケットの永続化は [retention](./retention.md) に従う。
