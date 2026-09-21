# tower-sessions

## BFF の token 管理

用途は、BFF が保持する token の交換と更新を担う機構である。
採用は、Rust は tower-sessions のサーバー側セッションと openidconnect のトークンエンドポイントクライアントである。
トークンエンドポイントクライアントの分担は [openidconnect](./openidconnect.md) が受け持つ。
判断基準は、token set と expiry を server 側に保持し、期限前の更新で得た token set を同じ session へ置き換えられることである。
撤回条件は、判断基準を満たさなくなることであり、ライセンス、リリースポリシー、session と token endpoint の互換性の変化を再評価のトリガーとする。

## BFF の session 管理

用途は、BFF が session を保持し cookie で運ぶ機構である。
採用は、Rust は tower-sessions である。
判断基準は、Secure・HttpOnly・SameSite=Strict の cookie 属性を、既定または明示の設定で強制できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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
