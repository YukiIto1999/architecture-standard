# server の構造

server は、API の surface である。
core を埋め込み、http を公開し、token を仲介する。
自己ホストであり、自身でプロセスを起動する。
server は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
server/
├─ routes/
│  └─ <route>       http の handler。要求を core API の operation へ写像する。
├─ bff/
│  ├─ session       session と cookie の発行・更新・失効。
│  ├─ token         OIDC と token broker。
│  ├─ csrf          CSRF の検査。
│  └─ throttle      流入制限のカウンタの adapter。
└─ composition      core の埋め込み・境界の仕込み・request context の構築・http の起動。
```

`routes` は、1 route を1ファイルに置く。
`bff` は、Web の資格情報を検証し、token を仲介する認証境界を置く。
`bff` は、検証済み principal を actor へ写し、actor と検証済み入力だけを routes と core へ渡す。
`bff` は、内部の機構を外へ公開せず、抽象の interface だけを公開する。
`composition` は単一の組立点である。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が routes と bff を組み立て、core を埋め込む。
routes と bff は、composition を参照しない。
server の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## 入口と handler

handler は、http の要求を core API の operation へ写像する。
handler は、業務判断を持たず、入力の変換と operation の呼び出しだけを行う。
API の様式と表現の形式は [contracts/http](../../contracts/http.md) に、操作の意味は [contracts/canonical](../../contracts/canonical.md) に従う。
認可の規律は [concerns/authorization](../../../concerns/authorization/README.md) に従う。
port は [structure/core/application](../../core/application.md) に、engine は [structure/core/infrastructure](../../core/infrastructure.md) に従う。

## Web BFF の認証境界

server は、Web BFF として OIDC の authorization code flow と PKCE を終端する。
認証境界は ID Token の署名、issuer、audience、期限、nonce を検証し、`at_hash` がある場合は access token との対応も検証してから principal を actor へ一度だけ写す。
implicit grant と resource owner password credentials grant を使わない。
route は actor と検証済み入力だけを core の公開 API へ渡し、資格情報、principal、token、claim、認証方式の型を渡さない。

token broker は access token と refresh token の交換、保持、更新、失効を担う。
token と認証 flow の一時状態は server 側の session に保持し、ブラウザへは session を指す推測不能で opaque な cookie だけを渡す。
session と token の状態、外部 logout の対応、失効記録はプロセス外の共有 store に置く。
token の更新は単一の更新に制御し、logout では cookie の破棄に加えて共有 store の session を失効させる。
identity provider から logout の通知を受けた場合は、通知の発行元、対象、完全性、有効性を検証し、対応する session を共有 store で失効させる。

session cookie は Secure、HttpOnly、SameSite=Strict、Path=/ とし、Domain 属性を設定せず、名前を `__Host-` で始める。
認証の成功時と権限の変更時に session ID を再生成する。
session に idle expiry と absolute expiry を設定する。

session cookie を伴う状態変更の要求は、session に保持した予測不能な CSRF token と専用 request header の値を照合してから route へ渡す。
CSRF token は session の確立と再生成時に発行して専用 response header でブラウザへ渡し、session の失効時に破棄する。
CSRF token を cookie、URL、ログへ載せず、照合に失敗した要求を core へ到達させない。

Web BFF を server に置く範囲の根拠には、[OAuth 2.0 for Browser-Based Applications draft v27](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps-27) を draft として用いる。
この draft は BFF の配置範囲だけを支え、規律の唯一の根拠にしない。
authorization code と PKCE の安全要件は [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html)、ID Token の検証は [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)、cookie、session、CSRF の要件は OWASP の [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) と [CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) にも従う。
資格情報から actor までの共通契約は [concerns/authentication](../../../concerns/authentication/README.md)、session store の採用は [concerns/persistence](../../../concerns/persistence/README.md)、言語別の機構は [tools](../../../tools/) が定める。

## 安全の境界

security header の仕込みは、境界の層に置き、業務の処理へ持ち込まない。
CSP・HSTS などの security header を、境界で一括して付ける。
cookie に __Host- 接頭辞を使う。
外部との境界は、TLS を前提にする。
境界の流入の上限は [concerns/resilience](../../../concerns/resilience/README.md) に従う。
流入制限のカウンタは、一時データの store に bff の adapter として持つ。
ストアの採用は [concerns/persistence](../../../concerns/persistence/README.md) に従う。
応答は、定めた形式の encoder で組み立て、文字列の連結で作らない。
安全の姿勢は [concerns/security](../../../concerns/security/README.md) に従う。

## 観測

観測の規律は [concerns/observability](../../../concerns/observability/README.md)、request context の規律は [concerns/context-propagation](../../../concerns/context-propagation/README.md) に従う。

## 生存と準備

server は、生存と準備の面を公開する。
面の handler は routes に置かず、composition が組み立てる。
判定と応答の規律は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。

## 組み立てと起動

composition は、build_core で core を埋め込む。
http の serve を組み立て、自身でプロセスを起動する。
composition は、認証境界が構築した actor から [request context](../../../concerns/context-propagation/README.md) を組み立て、core へ渡す。
core の公開 API へ資格情報、principal、token、claim、認証方式の型を渡さない。
終了の規律は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration/README.md) に従う。
