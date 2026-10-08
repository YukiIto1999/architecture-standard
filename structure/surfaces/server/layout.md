# server の構造

server は、API の surface である。
core を埋め込み、http を公開し、Web BFF を提供する場合は token を仲介する。
自己ホストであり、自身でプロセスを起動する。
server は [skeleton](../../skeleton.md) の依存と命名に従う。
資格情報の検証と actor の構築は [concerns/authentication](../../../concerns/authentication/README.md) に、操作と対象への許可の評価は [concerns/authorization](../../../concerns/authorization/README.md) に、資格情報の取得と保持は [concerns/secrets](../../../concerns/secrets/README.md) に従う。

## フォルダ構成

```
server/
├─ routes/
│  └─ <route>       http の handler。要求を core API の operation へ写像する。
├─ authentication/
│  ├─ boundary      資格情報の検証と actor の構築を公開する interface。
│  └─ adapters      受理する資格情報ごとの検証と、認可評価への許可範囲の引き渡し。
├─ bff/
│  ├─ session       session と cookie の発行・更新・失効。
│  ├─ token         Web frontend に代わる OIDC と OAuth の client、token broker。
│  ├─ csrf          CSRF の検査。
│  └─ throttle      流入制限のカウンタの adapter。
└─ composition      core の埋め込み・境界の仕込み・request context の構築・http の起動。
```

`routes` は、1 route を1ファイルに置く。
`authentication` は、server が受理する資格情報を検証し、actor を構築する共通の認証境界を置く。
`bff` は、Web frontend に代わる OAuth と、server 側の token と session の lifecycle を所有する。
認証と Web BFF は別の interface とし、token の取得・更新と、API の要求で受け取る資格情報の検証を同じ公開操作へ束ねない。
`authentication` と `bff` は内部の機構を外へ公開せず、抽象の interface だけを公開する。
`composition` は単一の組立点である。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が routes、authentication、bff を組み立て、core を埋め込む。
routes、authentication、bff は、composition を参照しない。
受理する資格情報の具体的な検証 adapter と、Web BFF の session を照会する interface は composition が認証境界へ注入し、routes は認証方式と token broker の具象を参照しない。
server の外との依存は [skeleton](../../skeleton.md) に従う。
server 自身の技術的な処理は、[libs](../../libs/layout.md) の公開 API を直接使え、core の operation を仲介にしない。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## 入口と handler

handler は、http の要求を生成 DTO として decode し、binding 固有の path、header、query と body を core API の operation の入出力へ写像する。
handler は、契約の形式と制約を通った生成 DTO を operation へ渡し、その結果の生成 DTO を応答へ encode する。
公開契約の DTO とコンテキストの application 入出力の写像は [core/composition](../../core/composition.md) が所有し、handler は業務判断やドメイン型への変換を持たない。
生成 DTO と通信 client の分離、未知項目の扱い、生成能力の不足の解消は [contracts/generated](../../contracts/generated.md) に従う。
API の様式と表現の形式は [contracts/http](../../contracts/http.md) に、操作の意味は [contracts/canonical](../../contracts/canonical.md) に従う。
認可の規律は [concerns/authorization](../../../concerns/authorization/README.md) に従う。
composition が仕込む認証境界と入口の認可評価を通った要求だけを handler へ渡し、handler は資格情報の許可範囲を広げない。
port は [structure/core/application](../../core/application.md) に、engine は [structure/core/infrastructure](../../core/infrastructure.md) に従う。

## 共通の認証境界

共通の認証境界は、server が受理する資格情報の検証と actor の構築を担当し、Web BFF の有無に依存しない。
session cookie と API の access token は、それぞれの契約を検証する具体的な adapter から同じ認証の interface へ接続する。
access token の検証を提供することと、Web frontend に代わる OAuth client を提供することは別の責務であり、どちらも一方だけを理由に導入しない。
認証境界は、actor と検証済み資格情報の許可範囲を分け、後者は server の境界内で入口の認可評価へ渡す。
route は actor と契約の形式と制約を通った生成 DTO だけを core の公開 API へ渡し、資格情報、principal、token、claim、認証方式の型を渡さない。

## Web BFF の OAuth と session

Web BFF は、Web frontend に代わる confidential OAuth client として OIDC の authorization code flow と PKCE を終端する。
OIDC の callback は ID Token の署名、issuer、audience、期限、nonce を検証し、`at_hash` がある場合は access token との対応も検証してから、認証済み session を確立する。
session の資格情報から actor への写像は共通の認証境界で一度だけ行い、callback と route に別の actor 構築を置かない。
implicit grant と resource owner password credentials grant を使わない。
同一 domain の frontend と API が認証済み session で接続することだけを理由に、自分の API 向けの access token 発行を追加しない。

token broker は access token と refresh token の交換、保持、更新、失効を担う。
token と認証 flow の一時状態は server 側の session に保持し、ブラウザへは session を指す推測不能で opaque な cookie だけを渡す。
token broker が行う認証付き通信は、許可された操作と resource server への対応を固定し、任意の URL、method、header を受け取る代理機能にしない。
session と token の状態、外部 logout の対応、失効記録はプロセス外の共有 store に置く。
token の更新は単一の更新に制御し、logout では cookie の破棄に加えて共有 store の session を失効させる。
identity provider から logout の通知を受けた場合は、通知の発行元、対象、完全性、有効性を検証し、対応する session を共有 store で失効させる。

session cookie は Secure、HttpOnly、SameSite=Strict、Path=/ とし、Domain 属性を設定せず、名前を `__Host-` で始める。
認証の成功時と権限の変更時に session ID を再生成する。
session に idle expiry と absolute expiry を設定する。

session cookie を伴う状態変更の要求は、session に保持した予測不能な CSRF token と専用 request header の値を照合してから route へ渡す。
CSRF token は session の確立と再生成時に発行して専用 response header でブラウザへ渡し、session の失効時に破棄する。
CSRF token を cookie、URL、ログへ載せず、照合に失敗した要求を core へ到達させない。

Web BFF の OAuth client、token 仲介、session の責務の区別は [RFC 10017 の 6.1 節](https://www.rfc-editor.org/rfc/rfc10017.html#section-6.1) に、同一 domain の session に不要な OAuth の責務を加えない判断は [7.1 節](https://www.rfc-editor.org/rfc/rfc10017.html#section-7.1) に従う。
RFC 10017 は Web BFF の責務と配置範囲を支え、すべての host の資格情報取得方式を同一にする根拠にはしない。
authorization code と PKCE の安全要件は [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html)、ID Token の検証は [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)、cookie、session、CSRF の要件は OWASP の [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) と [CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) にも従う。
資格情報から actor までの共通契約は [concerns/authentication](../../../concerns/authentication/README.md) に、token の保管と保持は [concerns/secrets](../../../concerns/secrets/README.md) に、session store は [concerns/persistence](../../../concerns/persistence/README.md) に従い、言語別の機構は [languages](../../../languages/) が定める。

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
設定の読み込みは [concerns/configuration](../../../concerns/configuration/README.md) に、設定由来の secret の解決と対話認証で取得する資格情報の扱いは [concerns/secrets](../../../concerns/secrets/README.md) に従う。
