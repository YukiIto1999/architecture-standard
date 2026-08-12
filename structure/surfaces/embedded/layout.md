# 埋め込み surface の構造

埋め込み surface は、core を埋め込み、言語非依存の protocol を公開する surface である。
自身では起動せず、被ホストの surface を抱える host が同梱して起動する。
server を持たないローカル優先の構成で、被ホストの surface が core をローカルに使うときに置く。
埋め込み surface は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
<embedded>/
├─ endpoints/
│  └─ <operation>   protocol の要求を core API の operation へ写像する。
└─ composition      core の埋め込み・protocol の公開・起動の入口。
```

`endpoints` は、1 operation を1ファイルに置く。
`composition` は単一の組立点である。
surface の名は、公開する protocol の対話様式で付ける。

## 依存方向

依存は一方向に保つ。
composition が endpoints を組み立て、core を埋め込む。
endpoints は composition を参照しない。
埋め込み surface の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## 入口と protocol

endpoint は、protocol の要求を core API の operation へ写像する。
endpoint は、業務判断を持たず、入力の解析と operation の呼び出しだけを行う。
protocol の要求から operation を識別して endpoint へ振り分ける dispatch は、composition が持つ。
認証境界は、要求に含まれる資格情報の発行元、対象、完全性、有効性を検証して actor を一度だけ構築する。
endpoint は、振り分け済みの単一 operation と actor を受け取る。
資格情報が protocol の接続から自明な場合も、接続のどの証拠を検証して actor を構築するかを project の ADR に明記する。
endpoint と core の公開 API へ資格情報、principal、token、claim、protocol の認証方式の型を渡さない。
公開する protocol の binding は [contracts/protocol](../../contracts/protocol.md) に従う。

## 組み立てと起動

composition は、build_core で core を埋め込み、protocol の listener を公開する。
自身では起動せず、同梱する host の runtime が起動する。
生存と準備の面は、protocol の予約した operation で公開する。
host は準備を確認してから要求を振り分ける。
lifecycle の規律は [concerns/lifecycle](../../../concerns/lifecycle.md) に従う。
認証境界が構築した actor を、core の公開 API へ渡す。
要求側が指定した actor を受け入れず、actor と検証済み入力だけを core の公開 API へ渡す。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
