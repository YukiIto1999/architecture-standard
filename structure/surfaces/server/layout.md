# server の構造

server は、API の surface である。
core を埋め込み、http を公開し、token を仲介する。
自己ホストであり、自身でプロセスを起動する。
server は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
server/
├─ routes/
│  └─ <route>       http の handler。要求を use-case へ写像する。
├─ bff/
│  ├─ session       session の取り出しと保存。
│  ├─ token         外部 token と内部 token の交換。
│  ├─ csrf          CSRF の検査。
│  └─ throttle      流入制限のカウンタの adapter。
└─ composition      core の埋め込み・境界の仕込み・request context の構築・http の起動。
```

`routes` は、1 route を1ファイルに置く。
`bff` は、token を仲介する認証境界を置く。
`bff` は、内部の機構を外へ公開せず、抽象の interface だけを公開する。
`composition` は単一の組立点である。

## 依存方向

依存は一方向に保つ。
composition が routes と bff を組み立て、core を埋め込む。
routes と bff は、composition を参照しない。
server の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## 入口と handler

handler は、http の要求を use-case へ写像する。
handler は、業務判断を持たず、入力の変換と use-case の呼び出しだけを行う。
API の様式と表現の形式は [contracts/http](../../contracts/http.md) に、操作の意味は [contracts/canonical](../../contracts/canonical.md) に従う。
認可の規律は [concerns/authorization](../../../concerns/authorization.md) に従う。
port は [structure/core/application](../../core/application.md) に、engine は [structure/core/infrastructure](../../core/infrastructure.md) に従う。

## token の仲介

server は、BFF として token を仲介する。
本人性の確立・token の非流出・session cookie・CSRF の検査・token の交換と保持の規律は [concerns/authentication](../../../concerns/authentication.md) に従う。
session store の採用は [concerns/persistence](../../../concerns/persistence.md) に従う。
session store・token 交換・CSRF の機構は [languages](../../../languages/) に従う。

## 安全の境界

security header の仕込みは、境界の層に置き、業務の処理へ持ち込まない。
CSP・HSTS などの security header を、境界で一括して付ける。
cookie に __Host- 接頭辞を使う。
外部との境界は、TLS を前提にする。
境界の流入の上限は [concerns/resilience](../../../concerns/resilience.md) に従う。
流入制限のカウンタは、一時データの store に bff の adapter として持つ。
ストアの採用は [concerns/persistence](../../../concerns/persistence.md) に従う。
応答は、定めた形式の encoder で組み立て、文字列の連結で作らない。
安全の姿勢は [concerns/security](../../../concerns/security.md) に従う。

## 観測

観測と request context の規律は [concerns/observability](../../../concerns/observability.md) に従う。

## 生存と準備

server は、生存と準備の面を公開する。
面の handler は routes に置かず、composition が組み立てる。
判定と応答の規律は [concerns/lifecycle](../../../concerns/lifecycle.md) に従う。

## 組み立てと起動

composition は、build_core で core を埋め込む。
http の serve を組み立て、自身でプロセスを起動する。
composition は、認証の結果から request context を組み立て、core へ渡す。
principal の actor への写像は [structure/core/composition](../../core/composition.md) が担う。
終了の規律は [concerns/lifecycle](../../../concerns/lifecycle.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration.md) に従う。
