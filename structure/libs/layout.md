# libs の構造

libs は、core と並列に root に置く、業務非依存の技術基盤の境界である。
言語・library・framework に欠ける能力を補う拡張と、独立した技術契約を持つ機構を収める。
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

libs は、業務の意味や利用側の配置を知らずに使える技術契約を提供する。
core・surface・runtime は、必要な機構の公開 API を直接参照し、core や別の境界を仲介にしない。
依存の許可は [skeleton](../skeleton.md) に従い、利用できる公開面は本書が定める。
標準の言語機構や採用済みの依存が必要な能力を満たすなら、新しい機構を作らない。
既存の API を包むだけで技術契約を加えない wrapper や、雑多な共通コードの置き場を作らない。
単一の業務境界の port を実装するだけの接続は、その境界の adapter に置く。
業務型を技術契約へ写す adapter も利用側に置き、libs に業務を持ち込まない。
境界の殻で行う観測の配線は、その境界の composition に置き、配線だけを機構として切り出さない。

## 機構の単位と粒度

libs 直下の単位は、独立に意味を持つ一つの技術契約である。
機構の境界は、提供する能力と、その能力が保証する不変条件、入出力、効果、失敗条件で決める。
全文検索の索引、ジョブのスケジューリング、識別子の採番、結果の型や効果の合成は、業務を知らずに契約を定められる機構にあたる。
純粋な型や演算だけで成立する機構に、port や infrastructure を要求しない。
利用側が一つでも、独立した技術契約があれば機構として置ける。
複数の利用側があることだけでは、機構として切り出す根拠にならない。
現在の一つの利用で必要な能力を独立させることと、将来の利用のために契約の範囲を広げることを区別する。
契約の一般化は [principles/construction](../../principles/construction/no-speculation.md) の「投機的で説明できない要素を作らない」に従う。
公開・配布できる品質を持つ単位として凝集させ、実際に公開するかとは分けて判定する(REP)。
同じ変更理由で一緒に変わる要素をまとめる(CCP)。
一つの能力を使うために必要な要素をまとめ、無関係な能力への依存を消費側に強制しない(CRP)。
単一の関数ごとに割らず、雑多な寄せ集めにもしない。
名は提供する能力を表す記述的で精密なものにし、effect・clock・common・util のような一般名を付けない。

## 業務非参照

機構は、業務を参照しない。
機構は、core のコンテキスト・shared・composition を参照しない。

## 内部の層

実行時の機構は、必要な層だけを持ち、それぞれの責務と公開面を次のように分ける。

| 単位 | 責務 | 公開面 |
|---|---|---|
| domain | 純粋な値、演算、技術の不変条件 | 契約を持つ型と演算 |
| application | 効果の宣言と合成 | port と合成の API |
| infrastructure | 技術 port の具体実装 | 消費側の組立点が使う adapter の構築用 API のみ |
| testing | 消費側の検査を実行する test-only の機構 | test package だけが使う検査の API |

domain を公開するのは、業務判断を内に隠す core のコンテキストとは異なり、技術契約そのものを再利用させるためである。
infrastructure の処理は、domain と application の公開 API を通して利用する。
消費側の組立点が package 境界を越えて adapter を構築する場合は、構築に必要な API に限って公開する。
この構築用 API の許可は、同じ repository 内での利用にも、独立した repository からの配布にも適用する。
公開面以外は、言語の可視性の機構で閉じる。
機構の内部では、参照は infrastructure から application、application から domain へ向かう。

## 機構間の依存

各機構は、公開する技術契約が意味を持つ単位として成立させる。
二つの package を分けても、一方が他方の内部実装にしか意味を持たず、独立した技術契約を定められないなら、一つの機構にまとめる。
別の機構への依存は、参照先が独立した技術契約を持ち、参照元がその公開能力を再利用する関係に限る。
別の機構から参照してよいのは、公開された domain と application だけである。
別の機構の infrastructure と testing は、参照しない。
機構間の依存は、循環させない。
arch test は、機構間の参照先が公開 domain または application であることを検査する。
arch test は、機構間の循環依存を検出して失敗する。
機構間の依存を追加する前に、上記の REP・CCP・CRP に照らして別の単位のままでよいことを確認する。

## spec と arch test

各機構は、spec.md を持つ。
ターゲットプロジェクトでは、spec.md を `libs/<mechanism>/spec.md` に置く。
独立した機構リポジトリでは、spec.md をリポジトリのルートに置く。
独立した機構をターゲットへ取り込むと、リポジトリのルートにある `spec.md` が `libs/<mechanism>/spec.md` に対応する。
spec.md の front-matter は、`mechanism:` に機構名を書く。
この機構名が、arch test の検査対象を特定する。
spec.md は、root またぎ依存の許可を持たない。
spec.md は arch test が読む製品メタデータであり、実装、振る舞い、変更理由の別の正本にしない。
技術契約と判断の説明の所在は [principles/documentation](../../principles/documentation/README.md) に従う。

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
言語ごとの検査と生成の機構、およびその構築と参照の仕方は [languages](../../languages/) が定める。

## 検査の実行機

消費側の設営義務(attach・閉包・台帳の検査)を宣言だけで検査する実行機を提供する場合は、機構の `testing/` に同梱する Testing package として置く。
実行機は機構の公開面の一部であり、消費側の test からだけ参照される。
root tests と各境界内の test package だけが、skeleton の build・test-only 依存表を通して Testing package を参照する。
arch test は、Testing package の参照元が test package であることを検査する。
arch test は、Testing package の内部参照が同じ機構の公開 domain と application に閉じていることを検査する。
実行機を持つ機構は、その実行機を自身へ適用する自己監査の test を持つ。

## 品質と公開

全ての機構に、公開・配布できる品質を要求する。
公開 API の契約、内部の隠蔽、契約を保証する test、依存と境界の検査を持ち、消費側が内部の実装へ踏み込まずに利用できる状態にする。
local や非公開の利用を理由に、この品質を下げない。
品質の判定と、実際の公開・配布、独立した repository への分離の判断は分ける。
実際の公開・配布は、他の project が機構を取得して利用できるようにすることを指し、同じ target 内から公開 API を参照するだけの利用を含めない。
機構は target の `libs/<mechanism>` で管理してよく、独立した repository や外部への公開を必須にしない。
target 内の利用と、公開・配布する利用で、同じ技術契約と実装を使う。
local 用と配布用に別の実装を保守せず、配布のためだけに品質を満たす別実装も作らない。
消費側に導入や利用の案内が必要な場合は、README.md をその読み手への入口にする。
他の project への公開・配布を選んだ library の README と CHANGELOG は [principles/documentation](../../principles/documentation/separate-document-types.md) の「文書の種別を分け、読み手を定める」に従う。
判断の説明の所在は [principles/documentation](../../principles/documentation/decision-records.md) に従う。
docs・work の扱いは [principles/documentation](../../principles/documentation/separate-document-types.md) に従う。

## 独立した repository からの取り込み

独立した repository で機構を管理し、target に共有する場合に、この取り込みの規律を適用する。
その repository の名は、機構名に言語の接尾辞を付ける。
target は、取り込む機構の origin、exact commit、`libs/<mechanism>` の path を追跡対象にする。
取得の機構は [tools/build/vendoring](../../tools/build/vendoring.md) が、初期化と確認の順序は [process/bootstrap](../../process/bootstrap.md) が定める。
機構の repository では、コード、test、消費側文書、arch test の入力となるルートの `spec.md` を Git で管理し、clone に含める。
target は、同じ製品メタデータを `libs/<mechanism>/spec.md` で参照できるようにする。
clean clone は、追加の取得なしに、記録した exact commit のコードと spec.md を同じ path で使える状態にする。
target 内で機構を管理する場合は、コード、test、必要な消費側文書、`spec.md` を target 自身の Git で管理し、外部の origin や UPSTREAM を要求しない。
