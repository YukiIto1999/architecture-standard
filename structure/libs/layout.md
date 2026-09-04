# libs の構造

libs は、root に置く境界であり、言語拡張と技術基盤の機構を収める。
機構は、業務を参照しない。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [tools](../../tools/) に置く。
libs は [skeleton](../skeleton.md) の依存と命名に従う。

## フォルダ構成

libs 直下は、機構ごとのフォルダである。

```
libs/
└─ <mechanism>/
   ├─ domain/
   ├─ application/
   ├─ infrastructure/
   ├─ testing/
   └─ spec.md
```

`<mechanism>/` の直下に置ける層は domain・application・infrastructure の3層であり、必要な層のみを置く。
`testing/` は、実行時の3層とは別に置く test-only の公開 package である。
`testing/` は、同じ機構の公開 domain と application だけを参照する。
`testing/` は、同じ機構の infrastructure を参照しない。
production の package は、`testing/` を参照しない。
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
全文検索の索引、ジョブのスケジューリング、識別子の採番のように、純粋な判断と、その subsystem が所有する技術 port を持つものが、機構にあたる。
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
独立リポジトリとして配布する機構では、消費側の合成根が assembly 境界越しに構築する既定の adapter に限り、infrastructure の型を public にしてよい。
機構の内部では、参照は infrastructure から application、application から domain へ向かう。

## 機構間の依存

各機構は、提供する能力を一つのリリース単位で自己充足する。
別の機構が無ければ成立しない二つの package は、一つの機構にまとめる。
別の機構を参照する場合は、参照先が独立してリリースでき、参照元がその公開能力を再利用する関係に限る。
別の機構から参照してよいのは、公開された domain と application だけである。
別の機構の infrastructure と testing は、参照しない。
機構間の依存は、循環させない。
arch test は、機構間の参照先が公開 domain または application であることを検査する。
arch test は、機構間の循環依存を検出して失敗する。
機構間の依存を追加する前に、上記の REP・CCP・CRP に照らして別のリリース単位のままでよいことを確認する。

## spec と arch test

各機構は、spec.md を持つ。
ターゲットプロジェクトでは、spec.md を `libs/<mechanism>/spec.md` に置く。
独立した機構リポジトリでは、spec.md をリポジトリのルートに置く。
独立した機構をターゲットへ取り込むと、リポジトリのルートにある `spec.md` が `libs/<mechanism>/spec.md` に対応する。
spec.md の front-matter は、`mechanism:` に機構名を書く。
この機構名が、arch test の検査対象を特定する。
spec.md は、root またぎ依存の許可を持たない。

```yaml
---
mechanism: <mechanism>
---
```
[skeleton](../skeleton.md) の実行時依存表と build・test-only 依存表が、root またぎ依存の唯一の許可元である。
[tests/arch](../tests/layout.md) は、ターゲットプロジェクトでは `libs/<mechanism>/spec.md` をリポジトリ相対pathとして列挙する。
[tests/arch](../tests/layout.md) は、独立した機構リポジトリではルートの `spec.md` をリポジトリ相対pathとして列挙する。
[tests/arch](../tests/layout.md) は、spec.md の機構名から検査対象を列挙し、skeleton の両依存表から phase ごとに libs を参照してよい境界を導出して、実際の参照と照合する。
[tests/arch](../tests/layout.md) は、spec.md の機構名から機構間の依存 graph を作り、公開面の違反と循環を検出する。

## compile 時ツール

型の網羅の検査、値オブジェクトの生成、効果の規律の強制のように、言語に欠ける compile 時の検査と生成を補う仕組みは、ビルド時のツールであって実行時の単位ではない。
これは実行時の層に属さず、出荷物にも含まれず、対象とは別のコンパイル単位になる。
compile 時のツールは、libs の機構として置く。
compile 時のツールは、ビルド時にだけ参照され、実行時の依存に現れない。
言語ごとの検査と生成の機構、およびその構築と参照の仕方は [tools](../../tools/) が定める。

## 検査の実行機

消費側の設営義務(attach・閉包・台帳の検査)を宣言だけで実行させる実行機は、機構の `testing/` に同梱する Testing の package として置く。
実行機は機構の公開面の一部であり、消費側の test からだけ参照される。
root tests と各境界内の test package だけが、skeleton の build・test-only 依存表を通して Testing package を参照する。
arch test は、Testing package の参照元が test package であることを検査する。
arch test は、Testing package の内部参照が同じ機構の公開 domain と application に閉じていることを検査する。
機構は、自らの実行機を自リポジトリへ適用する自己監査の test を持つ。

## 共有ライブラリからの取り込み

libs の機構の共有は、機構ごとに独立したライブラリリポジトリから取り込む。
リポジトリの名は、機構名に言語の接尾辞を付ける。
target は、取り込む機構の origin、exact commit、`libs/<mechanism>` の path を追跡対象にする。
取り込みの機構は [tools/build/vendoring](../../tools/build/vendoring.md) が、bootstrap で path へ materialize する順序は [process/bootstrap](../../process/bootstrap.md) が定める。
独立リポジトリの機構では、README.md を消費側の文書とする。
独立した機構リポジトリの git は、製品であるコード、テスト、消費側文書と、arch test の入力となる製品メタデータであるルートの `spec.md` を管理し、clone に含める。
target は、取り込んだ同じ製品メタデータを `libs/<mechanism>/spec.md` で参照できるようにする。
clean clone で bootstrap を実行すると、同じコードと spec.md を同じ path に解決する。
設計中の検討と決定の作業メモは、git 管理外の docs/ に置く。
