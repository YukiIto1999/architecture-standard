# structure

structure は、ターゲットプロジェクトを構成する各モジュールの言語非依存の骨格構造と、各部に固有の配置および境界規律を定めます。

設計の根底にある判断理由は [principles](../principles/) に従い、システム全体を貫く横断規律は [concerns](../concerns/) を参照して再定義しません。また、特定言語での実装手段は [tools](../tools/) に委ねます。

## システム構造の全体像

プロジェクトは、以下の境界と依存関係に基づいて階層化されます。

```text
 [ runtimes ]        Webブラウザ、Desktop、Mobileなどのホスト環境
      │
 [ surfaces ]        対話様式ごとの入口 / server, console, worker, viewer など
      │
      ▼
   [ core ] ───────► [ contracts ]  外界との通信・データ交換規約
  業務ロジックの核          ▲
      │                    │
      ▼                    │
   [ libs ] ───────────────┘
 業務非依存の技術基盤

 統括: [ skeleton ] がリポジトリ全体の境界、命名、依存方向を定義
 運用と検証: [ deploy ] が配備を、[ tests ] が統合検証を担う
```
## 構成

| 対象 | ファイル | 内容 |
|---|---|---|
| [skeleton](./skeleton.md) | skeleton | root の境界・命名・依存方向・workspace |
| [core](./core/layout.md) | layout・domain・application・infrastructure・composition | 業務の核。コンテキストごとの層と、配線に限定した composition の単位 |
| [libs](./libs/layout.md) | layout | 言語拡張と技術基盤の機構。機構は業務を参照しない |
| [contracts](./contracts/layout.md) | layout・canonical・http・protocol・generated | 契約 |
| [surfaces](./surfaces/) | 一覧の [README](./surfaces/README.md) が定める | 対話様式ごとの入口。server・console・worker・viewer・extension・embedded |
| [runtimes](./runtimes/) | 一覧の [README](./runtimes/README.md) が定める | 被ホスト surface の具体 host。web・desktop・mobile・ide |
| [deploy](./deploy/layout.md) | layout | 配備。infrastructure・delivery・provenance・secrets は layout の節である |
| [tests](./tests/layout.md) | layout・methods・doubles | root の規模の検証 |

## 統治と正本の原則

skeleton.md がリポジトリ全体の構成と境界の正本です。プロジェクト全域をまたぐ依存の規則は skeleton が一元管理し、各モジュールは自身の内部構造のみを定めます。
適合は、skeleton が定義する境界と依存方向表への一致、および各部の layout.md が定める固有規律への合致をもって判定します。

## 読み方と各部の詳細

各モジュールの詳細を調べる際は、以下のファイルを参照します。

- 各部のレイアウト: core、libs、contracts、deploy、tests ではそれぞれの layout.md、surfaces と runtimes では各一覧の README.md が地図の役割を果たします。
- 内部構造と依存方向: surfaces および runtimes のフォルダ構成、依存方向、固有の規律は、各 surface や runtime ごとの layout.md で確認します。
- 固有の規律: レイヤーや単位ごとの具体的な仕様は、単位ごとの個別ファイルで確認します。構成表のファイル列が各部の本文ファイルの正本であり、台帳にない本文ファイルを置かず、台帳にあるファイルを欠かしてはなりません。
