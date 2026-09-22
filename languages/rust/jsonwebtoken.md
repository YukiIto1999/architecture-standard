# jsonwebtoken

用途は、OIDC の back-channel logout token を検証する JWT の検証機構である。
採用は、Rust は jsonwebtoken であり、暗号の provider は `aws_lc_rs` の feature とする。
判断基準は、JWKS の鍵から検証鍵を構築し、許可する署名 algorithm を集合で限定して JWS の署名を検証し、issuer・audience・期限と必須 claim の存在を判定できることである。採用済みの OIDC client が公開 API に持たない logout token の検証を、これで満たせることを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、JWKS からの検証鍵の構築の廃止、署名 algorithm の限定の廃止、採用済みの OIDC client が logout token の検証を公開 API で提供することを再評価のトリガーとする。

## logout token の検証

### 要求
back-channel logout token は、jsonwebtoken で検証する。
検証鍵は、openidconnect の provider metadata が示す jwks_uri から取得した JWKS の鍵を `DecodingKey::from_jwk` で構築する。
鍵は logout token の `kid` で選び、未知の `kid` では JWKS を取り直し、それでも見つからなければ拒否する。
許可する署名 algorithm は、provider metadata の id_token_signing_alg_values_supported が示す非対称鍵の algorithm に限り、`Validation` の algorithms へ与える。
issuer と audience と期限は、`set_issuer`・`set_audience`・validate_exp で判定する。
`typ` header を持つ token は、値が `logout+jwt` でなければ拒否する。
iat・jti・events・sid・sub・nonce は `Validation` が扱わないため、claim を受ける型の必須と禁止で判定する。
claim を受ける型は、events に back-channel logout の member を必須とし、nonce を持つ token を拒否し、sid と sub の少なくとも一方を要求する。
iat は、許容する発行時刻の範囲を project が定めて判定する。
理解できない claim は、拒否せず無視する。
検証済みの logout token で session を特定して失効させる分担は、[tower-sessions](./tower-sessions.md) が受け持つ。

### 根拠
logout token は ID Token と別の JWT で、nonce を持たず sub を持たない場合があるため、ID Token の検証器では検証できない。
採用済みの OIDC client は RP-Initiated Logout の要求だけを扱い、logout token の検証を公開 API に持たない。
JWKS からの鍵構築と algorithm の限定を道具に任せれば、JWS の分解・鍵の選択・algorithm の取り違えを自作せずに済む。
alg が none の token は、jsonwebtoken の algorithm の集合に none が無いため header の parse で落ちる。
`typ` の検査は、別種の JWT を logout token として受理する取り違えを防ぐ。
jsonwebtoken の必須 claim の設定は exp・nbf・aud・iss・sub しか見ないため、iat・jti・events の存在は型で要求する。
`rust_crypto` の provider が引き込む rsa crate には修正版の無い timing 側 channel の advisory が残り、既知脆弱性の検査で release が止まる。
署名と claim を同じ検証点で確かめれば、未検証の通知で session が失効しない。

### 完了条件
back-channel logout token の署名が、jwks_uri から取得した JWKS の鍵で検証されている。
鍵が `kid` で選ばれ、未知の `kid` で JWKS の取り直しと拒否が行われている。
許可する署名 algorithm が、id_token_signing_alg_values_supported の非対称鍵の algorithm に限られている。
issuer・audience・期限が、jsonwebtoken の `Validation` で判定されている。
`typ` header を持つ token で、`logout+jwt` 以外が拒否されている。
iat・jti・events の存在と、nonce の不在と、sid または sub の存在が、claim を受ける型で判定されている。
iat の許容する発行時刻の範囲が、project の決定の記録に残されている。
理解できない claim が、拒否されず無視されている。

### 禁止事項
logout token を、ID Token の検証器で検証すること。
署名の検証に、token の header が示す algorithm をそのまま使うこと。
JWKS を、provider metadata の jwks_uri 以外から取得すること。
nonce を持つ token を、logout token として受理すること。
events の member を確かめずに、session を失効させること。
暗号の provider に、既知脆弱性の検査を通らない実装を選ぶこと。

### 行動
provider metadata の jwks_uri から JWKS を取得し、`jsonwebtoken::jwk::JwkSet` として保持する。
logout token の header を `decode_header` で読み、`typ` と `kid` を確かめる。
`kid` に対応する鍵を `DecodingKey::from_jwk` で構築する。
許可する algorithm・issuer・audience を与えた `Validation` で `decode` を呼ぶ。
claim を受ける型で iat・jti・events を必須にし、nonce を拒否し、sid と sub の少なくとも一方を要求する。
検証済みの結果を、[tower-sessions](./tower-sessions.md) の session の失効へ渡す。

### 例
header を読んで鍵と `typ` を確かめ、algorithm を限定して claim を型で受ける。

```rust
let header = decode_header(raw_token)?;
if header.typ.as_deref().is_some_and(|typ| typ != "logout+jwt") {
    return Err(LogoutTokenError::UnexpectedType);
}
let kid = header.kid.ok_or(LogoutTokenError::MissingKeyId)?;
let jwk = keys.find(&kid).ok_or(LogoutTokenError::UnknownKeyId)?;
let mut validation = Validation::new(header.alg);
validation.algorithms = allowed_algorithms.clone();
validation.set_issuer(&[expected_issuer.as_str()]);
validation.set_audience(&[client_id.as_str()]);
validation.set_required_spec_claims(&["exp", "iss", "aud"]);
let token = decode::<LogoutTokenClaims>(raw_token, &DecodingKey::from_jwk(jwk)?, &validation)?;
let logout = LogoutToken::try_from(token.claims)?;
```
