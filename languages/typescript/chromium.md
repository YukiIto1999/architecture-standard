# Chromium

用途は、extension とその UI を動かす browser-extension の host である。
採用は、Chromium の Manifest V3 と拡張 API である。
判断基準は、利用者が選んだ tab の操作を host port で実装でき、拡張ページに viewer を載せ、実行 context ごとの権限と寿命を分離できることである。
撤回条件は、判断基準を満たせなくなることであり、manifest、拡張 API、対象 browser の対応範囲の変化を再評価のトリガーとする。

## 実行 context ごとに組み立てる

### 要求
browser-extension の host は、[structure/runtimes/browser-extension](../../structure/runtimes/browser-extension/layout.md) に従う。
manifest で宣言する background service worker と拡張ページの entry、静的に登録する content script、必要な権限を定め、対象 Chrome の対応版を決定の記録に固定する。
動的に登録または注入する content script は、manifest の静的な content_scripts と区別し、登録または注入の呼出しが参照する build asset に対応づける。
各 entry の composition が、その context の adapters を組み立て、surface の公開する port と起動の入口へ注入する。
拡張ページの UI は viewer を再利用し、mount と build は [vite](./vite.md) に従う。
service worker を起動する event listener は entry の同期実行中に登録し、非同期の状態復元を待ってから登録しない。
event handler は依存の準備を待ってから操作を実行し、準備失敗や資格情報の欠落を成功扱いしない。
worker の global 変数、拡張ページ、content script の寿命を同一視せず、worker を常駐させるための keepalive を状態保持の仕組みにしない。
操作の tab、frame と document は event の対象と照合し、非同期処理の途中で別の現在 tab へ操作を向けない。

### 根拠
context ごとの entry で組み立てれば、DOM を持たない worker と UI の mount を、一つの実行環境へ押し込めずに済む。
listener の同期登録と handler 内の非同期準備を分ければ、worker の再起動で event の受信を失わず、復元前の状態も使わない。
event の対象を保持して照合すれば、tab の切り替えやページ遷移によって別の document を操作することを防げる。

### 完了条件
manifest で宣言する entry と、動的な登録または注入で参照する content script が build の出力に対応し、対象 Chrome 版で利用する API が対応している。
各 context の composition が port を注入し、surface が Chrome の global API や型へ依存していない。
listener が非同期の準備より先に登録され、worker の停止と再開後も handler が準備済みの依存を使っている。
準備の失敗、資格情報の欠落、対象 document の変更が操作の失敗として観測されている。

### 禁止事項
surface に Chrome の分岐や global API の呼出しを置くこと。
listener を storage の読み込みや認証の完了後に登録すること。
一つの composition を、全 context で共有する常駐 global instance と扱うこと。
worker の停止で失われる値を、保管済みの状態と扱うこと。

### 行動
manifest の宣言、動的な登録または注入、各 context の組立点を build の出力に対応づけ、event listener の登録と非同期の準備を分ける。
worker の停止と再開、拡張ページの閉鎖、ページ遷移を別々に操作し、要求が正しい対象へ到達することと失敗時の表示を確認する。
外部 I/O と待機は [connection](./connection.md) と [coordination](./coordination.md) の Effect と期限の機構に通す。

## 権限と message の操作を限定する

### 要求
manifest の API 権限と host permission は、実装する操作と通信先に必要なものだけを宣言する。
利用者が選んだ tab への一時的な操作には activeTab と必要な scripting の権限を使い、全サイトへの常時アクセスを既定にしない。
権限の拒否、撤回、注入を許されないページでは操作を拒否し、権限を追加して黙って再実行しない。
context 間の通信は runtime.sendMessage または runtime.connect の adapter で行い、JSON で表す判別子つき union の schema を [valibot](./valibot.md) で検証する。
受信側は sender の拡張 ID、origin、tab、frame と document のうち操作の許可に必要な属性を検証し、message の操作、対象と入力の検証を通った要求だけを実行する。
content script と外部ページからの message は低信頼の入力として扱い、許可する操作と通信先を host 側で固定する。
資格情報や他の origin の秘密を content script と外部ページへ返さず、client オブジェクトや関数を message で送らない。
認証や資格情報の読み取りを必要としない拡張ページには、その操作を公開しない。

### 根拠
host permission は browser の到達範囲であり、server の操作認可や URL path 単位の権限を代替しない。
message の型だけでなく sender と操作を照合すれば、ページに接する低信頼の context が worker の権限を自由に使う経路を閉じられる。
client と関数は message の JSON 表現にならないため、各 context に adapter を置き、検証済みの操作の入出力だけを伝える。

### 完了条件
manifest が必要な API と host に限定され、権限の拒否と撤回が操作の失敗になる。
sender と message をそれぞれ検証し、未許可の操作、対象、通信先が実行されない。
content script とページが、資格情報を取得したり、任意 URL への資格情報付き通信を要求したりできない。

### 禁止事項
host permission の path 指定を、server の操作認可と扱うこと。
同じ拡張から届いた message であることだけで、要求を信頼すること。
任意の URL、HTTP method、header、拡張 API の引数を低信頼の呼出元から受けて実行する汎用 proxy を公開すること。
型アサーションだけで受信値を検証済みと扱うこと。

### 行動
manifest と message の操作集合を対応づけ、外部 message の入口は必要なものだけ登録する。
未許可の sender、操作、対象と通信先を送って拒否を確認し、ページへ返す値に資格情報が含まれないことを確認する。
Chrome の global API の禁止は import の検査だけに頼らず、[inspection](./inspection.md) の banned API 検査で surface からの呼出しも拒否する。

## 資格情報を host の通信 adapter に閉じる

### 要求
資格情報の保管、許可された利用者、期限と失効は [concerns/secrets/sealed-secret-type](../../concerns/secrets/sealed-secret-type.md) に従う。
非秘密の設定と資格情報を同じ storage の record に置かず、remote の通信 adapter が資格情報を使用する。
非永続の資格情報を保持する adapter は chrome.storage.session を使い、値を置く前に setAccessLevel で TRUSTED_CONTEXTS に限定し、content script へ公開しない。
chrome.storage.session は DOM の sessionStorage と区別し、拡張 origin の context からアクセスできるメモリ領域として扱う。
資格情報を chrome.storage.local、chrome.storage.sync、一般設定、localStorage、IndexedDB に平文で永続保存しない。
永続保管の仕組みが必要な project は、共通保証を満たす単一の仕組みと利用できない場合の拒否を決定の記録に定め、session の値を平文の永続領域へ自動退避しない。
worker 停止後は session の値を期限と利用先を再確認して復元し、browser 再起動、拡張の reload、update、disable による消失後は認証済みと扱わない。
logout は保持値を破棄し、server 側の失効との対応を確認する。
通信先の変更では旧資格情報を新しい origin へ転送せず、対象の issuer と API に対応した資格情報を取得する。

### 根拠
session の保持は worker の global 変数と異なる寿命を持つため、worker の停止のたびに永続保管へ退避する必要はない。
TRUSTED_CONTEXTS はアクセス範囲であり、暗号化した永続保管や侵害された拡張 context からの保護を保証しない。
資格情報の破棄と期限切れと失効を分ければ、手元の値を消しただけで流出済み token も無効になったと誤認しない。

### 完了条件
非秘密の設定だけが一般の状態 port に現れ、資格情報は通信 adapter の許可された利用箇所に限られている。
session のアクセス範囲が値の保存前に設定され、content script が資格情報を読み取れない。
worker の再開では有効な値だけが使われ、session の消失、期限切れ、失効では操作を拒否して再認証へ導いている。
local、sync、設定、ログ、通常業務の応答へ資格情報が混入していない。

### 禁止事項
TRUSTED_CONTEXTS、短い期限、または nonextractable な WebCrypto key だけで、資格情報の安全な保管が証明されたと扱うこと。
暗号文と同じ profile に置いた鍵だけを、profile の漏洩から保護する根拠にすること。
資格情報の欠落時に、平文 PAT の永続保存へ fallback すること。

### 行動
取得、保持、使用、期限切れ、破棄、server 側の失効、再取得の遷移を通信 adapter の契約として定める。
worker の停止と browser 再起動を分けて確認し、資格情報を失った後の操作が成功扱いにならないことを確認する。
永続保管を選ぶ場合は、鍵の所在、backend の実状態、lock と利用不可時の拒否を検証し、API 名だけで保護を認定しない。

## 認証の取得経路と API の権限を照合する

### 要求
認証方式と取得経路は project が単一の決定として記録し、Chrome の identity API の存在を認証基盤の対応の証明にしない。
public OAuth client を使う場合は、配布物へ client secret を埋め込まず、authorization code と PKCE S256、transaction に結び付けた state、issuer と正確な redirect URI の照合を行う。
非 Google の flow に launchWebAuthFlow を使う場合は、local と配布 channel の拡張 ID、getRedirectURL の callback、認証基盤への登録を対応づける。
getAuthToken の Google 向け取得と cache を、任意の issuer や自分の API に使える token の発行と同一視しない。
取得した資格情報の audience、許可操作、期限と失効条件を server の受理契約と照合し、ID Token を API の access token として流用しない。
短命 token の限定 scope を採る場合も、同じ拡張が owner の cookie や別の資格情報でより広い操作へ到達できないことを確認する。
cookie を使う経路では、対象 browser の設定、host permission、送信条件と CSRF を実測し、届かないことを理由に SameSite や CSRF を弱めない。

### 根拠
Chrome の認証 API は flow の開始や redirect の取得を提供するが、issuer の登録、API の audience や scope、失効の契約は提供しない。
PKCE は code の交換を保護し、発行済み token の漏洩や侵害された拡張コードの操作を防ぐ保証とは異なる。
限定 token と広い cookie が同時に使える構成では、token の scope だけで拡張の権限を限定したことにならない。

### 完了条件
選んだ取得経路が対象の認証基盤と配布 channel で動き、未許可の API 操作が拒否されている。
public OAuth client を採る場合は、callback 不一致、code の再利用と PKCE 不一致が拒否されている。
資格情報の期限、失効と再認証の条件が具体化され、許可操作を越える別経路も拒否されている。
認証基盤が未対応の取得方式や、検証していない cookie の送信を前提にしていない。

### 禁止事項
identity API があることだけで、issuer の public client や PKCE の対応を採用済みと扱うこと。
限定 scope、PKCE、session の保持のいずれかだけで、侵害された拡張 context から安全と扱うこと。
利用者指定の任意 origin や redirect 先へ旧資格情報を送ること。

### 行動
manifest、拡張 ID、認証基盤、API の受理条件と許可操作を照合し、選んだ取得経路を実行して確認する。
期限切れ、失効、未許可の操作と別資格情報による迂回を確認する。
public OAuth client の経路では、配布 channel ごとの callback の対応、不一致、code の再利用と PKCE 不一致の拒否も確認する。

## 参照

権限と message の実現は Chrome の [Stay secure](https://developer.chrome.com/docs/extensions/develop/security-privacy/stay-secure)、[Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/messaging)、[Match patterns](https://developer.chrome.com/docs/extensions/develop/concepts/match-patterns) が定める。
worker の登録と寿命は Chrome の [Service worker events](https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/events) と [Lifecycle](https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle)、context の分離は MDN の [Background scripts](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Background_scripts) が定める。
storage と認証 API は Chrome の [Storage](https://developer.chrome.com/docs/extensions/reference/api/storage) と [Identity](https://developer.chrome.com/docs/extensions/reference/api/identity) が定める。
短命化と失効の限界は [An in-depth look at refresh tokens in the browser](https://pragmaticwebsecurity.com/articles/oauthoidc/refresh-token-protection-implications)、拡張の権限を最小化する根拠は [Protecting Browsers from Extension Vulnerabilities](https://ptolemy.berkeley.edu/projects/truststc/pubs/650.html) と [拡張の権限を悪用した実演](https://mattfrisbie.substack.com/p/spy-chrome-extension) に照らす。
OAuth の code と PKCE の安全要件は [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html) に従う。
