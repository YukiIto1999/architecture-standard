# 埋め込み surface の構造

埋め込み surface は、core を埋め込み、言語非依存の protocol を公開する surface である。
自身では起動せず、被ホストの surface を抱える host が同梱して起動する。
server を持たないローカル優先の構成で、被ホストの surface が core をローカルに使うときに置く。
埋め込み surface は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
<embedded>/
├─ endpoints/
│  └─ <operation>   protocol の要求を契約 adapter の保護された公開入口へ渡す。
└─ composition      core の埋め込み・protocol の公開・起動の入口。
```

`endpoints` は、1 operation を1ファイルに置く。
`composition` は単一の組立点である。
surface の名は、公開する protocol の対話様式で付ける。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が endpoints を組み立て、core を埋め込む。
endpoints は composition を参照しない。
埋め込み surface の外との依存は [skeleton](../../skeleton.md) に従う。
埋め込み surface 自身の技術的な処理は、[libs](../../libs/layout.md) の公開 API を直接使え、core の operation を仲介にしない。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## 入口と protocol

endpoint は、protocol の要求を生成 DTO として decode し、契約 adapter の保護された公開入口へ渡し、生成 DTO の結果を protocol の応答へ encode する。
endpoint は契約の形式と制約の検証と入口の呼び出しを担い、業務判断やドメイン型への変換を持たない。
公開契約と application 入出力の写像は [contracts/adapters](../../contracts/adapters.md) が所有する。
提供側 stub とデータ型の分離、未知項目の扱い、生成能力の不足の解消は [contracts/generated](../../contracts/generated.md) に従う。
protocol の要求から operation を識別して endpoint へ振り分ける dispatch は、composition が持つ。
認証境界は、要求の資格情報の発行元、対象、完全性、有効性を検証し、認証主体と資格情報の許可範囲を確定する。
endpoint は、振り分け済みの単一 operation へ接続する保護された呼び出し口を受け取る。
資格情報が protocol の接続から自明な場合も、接続のどの証拠で認証主体を確定するかを project の決定の記録に明記する。
endpoint と core の公開 API へ資格情報、principal、token、claim、protocol の認証方式の型を渡さない。
公開する protocol の binding は [contracts/protocol](../../contracts/protocol.md) に従う。

## 組み立てと起動

composition は、build_core で core を埋め込み、protocol の listener を公開する。
自身では起動せず、同梱する host の runtime が起動する。
生存と準備の面は、protocol の予約した operation で公開する。
host は準備を確認してから要求を振り分ける。
lifecycle の規律は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。
検証済みの認証文脈を契約 adapter の保護された入口へ結び付け、業務に必要な主体だけをコンテキストの入力へ対応付ける。
要求側が指定した認証主体を信頼せず、実行の期限、取消、相関は業務入力から分けて必要な効果へ渡す。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration/README.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
