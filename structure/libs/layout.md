# libs の構造

libs は、root に置く境界であり、言語拡張と技術基盤の機構を収める。
機構は、業務を参照しない。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
libs は [skeleton](../skeleton.md) の依存と命名に従う。

## フォルダ構成

libs 直下は、機構ごとのフォルダである。

```
libs/
└─ <mechanism>/
   ├─ domain/
   ├─ application/
   ├─ infrastructure/
   └─ spec.md
```

`<mechanism>/` の直下に置ける層は domain・application・infrastructure の3層であり、必要な層のみを置く。
`spec.md` は、機構ごとに置く。

## 境界の役割

libs は、言語拡張と技術基盤の機構の置き場である。
機構は、公開してもよいリリース単位として凝集させる。
単一のコンテキストの中で port の実装を与えるだけの技術接続は、libs に切り出さず、コンテキストの infrastructure の adapter に置く。
判断を持たず境界の殻で行う横断の関心は、libs にせず composition の観測に置く。

## 機構の単位と粒度

libs 直下の単位は、一つの技術機構である。
機構の境界は、提供する目的が決める。
機構の中身は、目的を実現する型と判断の凝集である。
全文検索の索引、ジョブのスケジューリング、識別子の採番のように、純粋な判断と自前の port を持つ技術の subsystem が、機構にあたる。
機構は、公開してもよいリリース単位として凝集させる(REP)。
一緒にリリースし、一緒に変わる機構を一つにまとめる(CCP)。
一緒に使う機構を一つにまとめる(CRP)。
単一の機能ごとに割らず、雑多な寄せ集めにもしない。
名は提供する能力を表す記述的で精密なものにし、effect・clock・common・util のような一般名を付けない。

## 業務非参照

機構は、業務を参照しない。
機構は、core のコンテキスト・shared・composition を参照しない。

## 内部の層

機構の公開面は、純粋な判断と値を表す domain と、効果を宣言する application の port に分かれる。
機構が domain を公開面に含めるのは、業務判断を内に隠すコンテキストとは非対称であり、機構が技術の再利用部品である点に由来する。
infrastructure は、機構の公開面に含まれない。
機構の内部では、参照は infrastructure から application、application から domain へ向かう。

## 消費範囲と arch test

各機構は、spec.md を持つ。
spec.md の front-matter は、その機構を参照してよい境界の消費範囲を宣言する。
front-matter の書式は、`consumers:` に [skeleton](../skeleton.md) の root 境界名を列挙する形とする。
消費範囲を宣言していない境界からの参照を、認めない。

```yaml
---
consumers:
  - core
  - server
---
```
[tests/arch](../tests/layout.md) は、宣言された消費範囲と実際の参照を照合し、宣言を超えた参照を機械検証する。

## compile 時ツール

型の網羅の検査、値オブジェクトの生成、効果の規律の強制のように、言語に欠ける compile 時の検査と生成を補う仕組みは、ビルド時のツールであって実行時の単位ではない。
これは実行時の層に属さず、出荷物にも含まれず、対象とは別のコンパイル単位になる。
compile 時のツールは、libs の機構として置く。
compile 時のツールは、ビルド時にだけ参照され、実行時の依存に現れない。
言語ごとの検査と生成の機構、およびその構築と参照の仕方は [languages](../../languages/) が定める。

## 共有ライブラリからの取り込み

libs の機構の共有は、機構ごとに独立したライブラリリポジトリから取り込む。
リポジトリの名は、機構名に言語の接尾辞を付ける。
取り込みは、GitHub からの取得、またはローカルコピーで行う。
registry での配布は、行わない。
