# structure

structure は、ターゲットプロジェクトの各部の、言語非依存の構造と、その部に固有の規律を定める。
設計原則は [principles](../principles/) に従う。
横断的な規律は [concerns](../concerns/) を参照し、再定義しない。
言語別の実現は [languages](../languages/) に置く。

## 構成

| 対象 | 内容 |
|---|---|
| [skeleton](./skeleton.md) | root の境界・命名・依存方向・workspace |
| [core](./core/layout.md) | 業務の核。コンテキストごとの domain・application・infrastructure の層と、配線に限定した composition の単位 |
| [libs](./libs/layout.md) | 言語拡張と技術基盤の機構。機構は業務を参照しない |
| [contracts](./contracts/layout.md) | 契約。layout と canonical・http・protocol・generated の層 |
| [surfaces](./surfaces/) | 対話様式ごとの入口。server・console・worker・viewer・extension・embedded |
| [runtimes](./runtimes/) | 被ホスト surface の具体 host。web・desktop・mobile・ide |
| [deploy](./deploy/layout.md) | 配備。infrastructure・delivery・provenance・secrets |
| [tests](./tests/layout.md) | root の規模の検証。layout と methods・doubles |

skeleton が root の構成の正本である。
root をまたぐ依存の規則は skeleton が持ち、各部は自身の内部だけを定める。
遵守は、skeleton の構成と依存方向表への一致と、各 layout の構成・固有規律への一致で判定する。

## 読み方

各部の地図は、core・libs・contracts・deploy・tests では layout.md、surfaces・runtimes では一覧の README.md である。
surfaces・runtimes のフォルダ構成・依存方向・固有の規律は、各 surface・runtime の layout.md で確かめる。
層や単位の中身は単位ごとのファイルで確かめる。
