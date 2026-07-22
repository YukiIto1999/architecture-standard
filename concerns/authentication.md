# authentication

## 概要
authentication は、本人性の確立と資格情報の非流出を全系で統べる規律である。
principles の [separation](../principles/separation.md) が定める関心を境界の内に隠す原則を、認証境界における資格情報の隔離として具象化する。
authentication は本人性の確立と資格情報の非流出を扱い、確立された principal の権限評価は [authorization](./authorization.md) が扱う。
本概念が統べるのは、利用者と system の間の本人性である。
system どうしの本人性の確立は標準が定めを持たず、project が単一の方式を ADR に記録する。

## 本人性を境界で一度確立する

### 要求
本人性の確立は、信頼境界にある単一の仲介点で行い、確立した結果を principal として一度だけ生成する。
外部の identity provider を用いる場合は、認可コードの flow を伴う OIDC で確立し、implicit と password の flow を使わない。
認可コードの flow には、PKCE を用いる。

### 根拠
本人性の確立をあちこちに散らすと、確立の方式や検証の抜けが場所ごとに食い違う。
単一の仲介点に集めれば、確立の正しさを一箇所で保証できる。
implicit の flow は、token がブラウザを経由するため、資格情報の非流出を守れない。
password の flow は、利用者の資格情報を identity provider 以外に入力させ、MFA とも両立しないため、資格情報の非流出を守れない(RFC 9700 の機序)。
認可コードの flow を伴う OIDC は、token の交換を仲介点とプロバイダの間に閉じ、ブラウザを経由させない。
PKCE は、横取りされた認可コードを、コードだけでは token に交換できなくする。

### 完了条件
本人性の確立が、信頼境界にある単一の仲介点で行われている。
確立の結果が、principal として一度だけ生成されている。
外部の identity provider を用いる認証が、認可コードの flow を伴う OIDC で行われている。
認可コードの flow が、PKCE を伴っている。

### 禁止事項
本人性の確立を、複数の場所に分散させること。
implicit と password の flow で、外部の identity provider に認証すること。

### 行動
本人性の確立の経路を洗い出し、信頼境界にある単一の仲介点に集める。
外部の identity provider を使う箇所は、認可コードの flow を伴う OIDC に統一する。

### 例
```
// 各 surface が個別に外部 identity provider と implicit flow で通信する
viewer -> idp.authorize({ response_type: "token" })

// 仲介点だけが認可コードの flow で本人性を確立する
bff -> idp.authorize({ response_type: "code" })
bff -> idp.token({ code, code_verifier })
```

## token を信頼境界の外へ出さない

### 要求
access token と refresh token は、信頼境界の内側(仲介点)に留め、ブラウザや利用者環境へ渡さない。
外部から受け取った opaque token は、内部の JWT へ交換してから業務側で使う。

### 根拠
token がブラウザや利用者環境に渡ると、XSS や利用者環境の侵害で持ち出される。
仲介点の内側に留めれば、持ち出しの面が生まれない。
外部の opaque token をそのまま内部で使い回すと、外部の失効や形式の変更に業務側が直接さらされる。
内部の JWT へ交換すれば、内部の検証は自身が発行した形式だけを扱える。

### 完了条件
access token・refresh token が、信頼境界の内側だけに存在する。
ブラウザ・利用者環境が、access token・refresh token を受け取っていない。
外部の opaque token が、内部の JWT へ交換されてから使われている。

### 禁止事項
access token・refresh token を、ブラウザや利用者環境へ渡すこと。
外部の opaque token を、交換せずに内部の業務処理へ渡すこと。

### 行動
token の流れを追い、ブラウザや利用者環境へ渡っていないか確かめる。
外部の opaque token は、仲介点で内部の JWT へ交換してから業務側へ渡す。

### 例
```
// access token を応答へ載せ、ブラウザへ渡す
respond({ accessToken, refreshToken })

// token は仲介点に留め、ブラウザへは opaque な識別子だけを渡す
setSessionCookie(opaqueSessionId) // access token・refresh token は仲介点の内部状態のまま
```

## 利用者へは opaque な session cookie だけを渡す

### 要求
利用者へ渡す認証の状態は、httpOnly・Secure・SameSite を備えた session cookie だけとする。
cookie の値は、仲介点の外から意味を読めない opaque な識別子にする。
CSRF token の受け渡しは認証の状態でなく、CSRF の検査の規律が定める形で行う。

### 根拠
httpOnly は JavaScript からの読み出しを防ぎ、XSS による持ち出しを塞ぐ。
Secure は暗号化された経路だけへ cookie を送らせ、SameSite は他サイトからの送出を絞る。
cookie の値が opaque であれば、cookie を奪われても中身の情報は得られず、仲介点側の失効だけで無効化できる。

### 完了条件
利用者へ渡る cookie が、httpOnly・Secure・SameSite を備えている。
cookie の値が、意味を持たない opaque な識別子である。

### 禁止事項
httpOnly・Secure・SameSite を欠いた cookie を、利用者へ渡すこと。
cookie の値に、token やクレームなど意味のある情報をそのまま載せること。

### 行動
利用者へ渡す cookie の属性を確かめ、httpOnly・Secure・SameSite を備えさせる。
cookie の値を、意味を持たない識別子に置き換える。

### 例
```
// クレームを含む値をそのまま cookie にする。奪われると中身が読める
setCookie("session", encodeJwt(claims))

// 仲介点だけが意味を知る opaque な識別子を、安全な属性で渡す
setCookie("session", randomOpaqueId(), { httpOnly: true, secure: true, sameSite: "strict" })
```

## session を発行し期限で失効させる

### 要求
session の識別子は、推測できない乱数で生成し、意味を持たせない。
権限の水準が変わる時、特に認証の成功時に、識別子を再生成する。
session には、無操作の期限と絶対の期限の二つを持たせ、期限の値は project が定める。
失効した session は、共有ストアから削除する。

### 根拠
意味を持つ識別子は、情報を漏らし、推測の手がかりになる。
認証の前から続く識別子を使い続けると、攻撃者が事前に植え付けた識別子で確立後の session を乗っ取れる。
認証の成功で再生成すれば、確立前の識別子は確立後の session に届かない。
無操作の期限は放置された session の悪用の窓を絞り、絶対の期限は盗まれた session の有効な期間を有限にする。
cookie の破棄は利用者側の状態にすぎず、共有ストアから消して初めて server 側で失効する。

### 完了条件
session の識別子が、推測できない乱数で生成され、意味を持っていない。
認証の成功時に、識別子が再生成されている。
session に、無操作の期限と絶対の期限がある。
失効した session が、共有ストアから削除されている。

### 禁止事項
認証の前後で、同じ session の識別子を使い続けること。
期限のない session を発行すること。
logout や失効を、cookie の破棄だけで済ませること。

### 行動
session の発行・再生成・失効を仲介点に集め、失効は共有ストアの削除まで行う。
無操作と絶対の期限を定め、期限切れの session を刈り取る。

## 状態を変える要求は CSRF 検査を通す

### 要求
session cookie を伴って状態を変える要求は、CSRF の検査を通らなければ業務の処理へ到達させない。
CSRF の検査は、session に保持した予測不能な token と、要求の専用 header で返された値の一致を確かめる synchronizer token の方式で行う。
token は session の確立と再生成の時に発行し、session の失効とともに破棄する。
token を cookie・URL・ログへ載せない。

### 根拠
cookie はブラウザが自動で送るため、利用者が意図しない他サイトからの送信でも付いてしまう。
CSRF の検査を通さないと、利用者の cookie を借りた偽の要求が状態を変えてしまう。
検査を要求の入口に置けば、偽の要求は業務の処理に届く前に止まる。
仲介点は共有ストアに session を持つので、token を session に束ねる保持に新しい状態の基盤は要らない。
cookie を借りただけの第三者は session に保持された token を知らないので、専用 header の値との一致の検査で拒める。
cookie に別の値を載せて一致を確かめる方式は、cookie を書き込める攻撃者が両方の値を差し替えて迂回できる。
方式を単一に固定すれば、言語や surface ごとに検査の強度が割れない。

### 完了条件
session cookie を伴う状態を変える要求が、CSRF の検査を通っている。
CSRF の検査が、session に保持した token と専用 header の値の一致で行われている。
token が、session の確立と再生成の時に発行され、session の失効とともに破棄されている。
token が、cookie・URL・ログに載っていない。
検査を通らない要求が、業務の処理に到達していない。

### 禁止事項
session cookie を伴う状態を変える要求を、CSRF の検査なしに業務の処理へ通すこと。
CSRF の検査を、synchronizer token 以外の方式で行うこと。
token を cookie・URL・ログへ載せること。

### 行動
状態を変える要求の経路を洗い出し、入口に synchronizer token の CSRF の検査を置く。
session の確立と再生成で token を発行し、応答で利用者側へ渡し、状態を変える要求の専用 header で返させる。
検査を通らない要求は、業務の処理へ進める前に拒否する。

### 例
```
// cookie があれば通す。他サイトからの偽の要求も通る
if (hasSessionCookie(request)) handle(request)

// session の token と専用 header の値の一致を確かめてから業務へ進める
if (hasSessionCookie(request) && request.header("x-csrf-token") == session.csrfToken) handle(request)
else reject()
```

## token の交換と保持を仲介点に集める

### 要求
交換で得た token・session・認証 flow の一時状態・token の交換の対応と失効の記録は、仲介点に集めてプロセス外の共有ストアへ持つ。
ストアの採用は [persistence](./persistence.md) に従う。
token の更新は、競合を単一の更新に制御する。
外部からの logout の通知を受けたら、session を失効させる。

### 根拠
仲介点の外や個々のプロセス内に状態を持つと、複数のプロセスの間で状態が食い違い、再起動で失われる。
プロセス外の共有ストアに集めれば、どのプロセスが応じても同じ状態を参照できる。
token の更新を並行に許すと、競合した更新が互いを上書きし、有効な token を失う。
単一の更新に制御すれば、競合しても一方だけが反映される。
外部からの logout を session の失効に反映しないと、失効したはずの認証が使われ続ける。

### 完了条件
交換で得た token・session・認証 flow の一時状態・token の交換の対応と失効の記録が、仲介点からプロセス外の共有ストアに保持されている。
token の更新が、単一の更新に制御されている。
外部からの logout の通知で、session が失効している。

### 禁止事項
token の交換・session・認証 flow の一時状態を、個々のプロセス内やプロセスの生存期間に閉じた場所へ持つこと。
token の更新を、競合の制御なく並行に許すこと。
外部からの logout の通知を、session の失効に反映しないこと。

### 行動
仲介点が扱う状態を洗い出し、プロセス外の共有ストアへ集める。
token の更新経路に、単一の更新に絞る制御を入れる。
外部からの logout の通知を受ける経路を用意し、session の失効につなげる。

### 例
```
// token をプロセス内のメモリに持つ。再起動や複数プロセスで状態が失われる
const sessions = new Map()
sessions.set(sessionId, tokens)

// 仲介点がプロセス外の共有ストアへ状態を持つ。ストアの採用は persistence に従う
await store.set(sessionId, tokens, { ttl })
```

## 参照
境界を内に隠す原則は [separation](../principles/separation.md)、確立した principal の権限評価は [authorization](./authorization.md)、session store の採用は [persistence](./persistence.md)、安全の姿勢は [security](./security.md) に従う。
仲介点の置き場は [structure/surfaces/server/layout](../structure/surfaces/server/layout.md)、言語別の実現は [languages](../languages/) が定める。
