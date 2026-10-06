# structure

structure は、ターゲットプロジェクト全体と各部の責務、境界、依存方向、配置、および各部固有の設計規律を言語非依存に定めます。

設計の判断基準と一般規律は [principles](../principles/) に従い、特定概念の性質と保証は [concerns](../concerns/) に従って再定義しません。
特定言語での実装手段は [languages](../languages/) が定めます。

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
| [tests](./tests/layout.md) | layout・methods・doubles | root の規模の検証と、検証技法およびダブルの設計 |

## 統治と正本の原則

skeleton.md がリポジトリ全体の構成と境界の正本です。
root をまたぐ具体的な許可依存は skeleton が一元管理し、各部の内部構造は各 layout が定めます。
依存が満たす一般的な性質と保証は concerns が所有し、適用されるモジュール数では正本を分けません。
適合は、skeleton が定義する境界と依存方向表への一致、および構成表の各部の本文が定める固有の設計規律への合致をもって判定します。
検証技法の選択、性質から型・静的検査・実行テスト・計測への割当、mutation・coverage・実行範囲は [tests/methods.md](./tests/methods.md) が所有します。

## 読み方と各部の詳細

各モジュールの詳細を調べる際は、以下のファイルを参照します。

- 各部のレイアウト: core、libs、contracts、deploy、tests ではそれぞれの layout.md、surfaces と runtimes では各一覧の README.md が地図の役割を果たします。
- 内部構造と依存方向: surfaces および runtimes のフォルダ構成、依存方向、固有の規律は、各 surface や runtime ごとの layout.md で確認します。
- 固有の規律: レイヤーや単位ごとの具体的な仕様は、単位ごとの個別ファイルで確認します。構成表のファイル列が各部の本文ファイルの正本であり、台帳にない本文ファイルを置かず、台帳にあるファイルを欠かしてはなりません。
