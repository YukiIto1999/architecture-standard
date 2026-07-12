# 埋め込み surface の構造

埋め込み surface は、core を埋め込み、言語非依存の protocol を公開する surface である。
自身では起動せず、被ホストの surface を抱える host が同梱して起動する。
server を持たないローカル優先の構成で、被ホストの surface が core をローカルに使うときに置く。
埋め込み surface は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
<embedded>/
├─ endpoints/
│  └─ <operation>   protocol の要求を core の use-case へ写像する。
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

endpoint は、protocol の要求を use-case へ写像する。
endpoint は、業務判断を持たず、入力の解析と use-case の呼び出しだけを行う。
protocol の要求から operation を識別して endpoint へ振り分ける dispatch は、composition が持つ。
endpoint は、振り分け済みの単一 operation を扱い、要求に含まれる principal の素材を取り出す。
principal を actor へ写像するのは [structure/core/composition](../../core/composition.md) で、principal が自明な場合の扱いは project が ADR に明記する。
公開する protocol の binding は [contracts/protocol](../../contracts/protocol.md) に従う。

## 組み立てと起動

composition は、build_core で core を埋め込み、protocol の listener を公開する。
自身では起動せず、同梱する host の runtime が起動する。
生存と準備の面は、protocol の予約した operation で公開する。
host は準備を確認してから要求を振り分ける。
lifecycle の規律は [concerns/lifecycle](../../../concerns/lifecycle.md) に従う。
actor への写像は [structure/core/composition](../../core/composition.md) が担う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
