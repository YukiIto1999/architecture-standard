# modeling

modeling は、業務の意味を型で表すための原則を置く。
型駆動は、業務知識と不変条件を型の構築・引数・戻り値・取りうる場合へ落とし、正しい操作を型から導く設計の手段である。
意味を型に封じ、不正な状態を表現できなくし、境界で検証し、論理と物理を分ける。
値・区分・集合は、計算・判断・繰り返しの業務知識を発見して、型の操作へ封じる役割である。
値は計算と比較、区分は分類と場合ごとに変わる判断、集合は要素にわたる繰り返しを担う。
この三つは型を排他的に分ける分類ではなく、集合が値でもあるように、一つの型が複数の役割を持ってよい。
値の計算と比較の原則は [meaning-in-types](./meaning-in-types.md) が定める。
区分の判断の原則は [decisions-as-types](../construction/decisions-as-types.md) が定める。
集合の繰り返しの原則は [named-collection-operations](../construction/named-collection-operations.md) が定める。
語彙と命名は [naming](../naming/README.md) に従う。

## 規律

- [業務の意味を型に封じる](./meaning-in-types.md) — 機械+レビュー(型と構築・操作の検証+意味と責務の照合)
- [不正な状態を表現できなくする](./illegal-states-unrepresentable.md) — 機械(型(直和と網羅検査))
- [境界で検証して型に通す](./parse-at-boundary.md) — 機械(型+境界 parse テスト)
- [知識の増加を型に残す](./knowledge-in-types.md) — レビュー(保証差の判断レビュー)
- [論理設計と物理設計を分ける](./logical-physical-separation.md) — 機械+レビュー(依存方向検査+意味レビュー)
