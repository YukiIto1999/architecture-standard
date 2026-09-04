# modeling

modeling は、業務の意味を型で表すための原則を置く。
意味を型に封じ、不正な状態を表現できなくし、境界で検証し、論理と物理を分ける。
語彙と命名は [naming](../naming/README.md) に従う。

## 規律

- [業務の意味を型に封じる](./meaning-in-types.md) — 機械(型(newtype/brand))
- [不正な状態を表現できなくする](./illegal-states-unrepresentable.md) — 機械(型(直和と網羅検査))
- [境界で検証して型に通す](./parse-at-boundary.md) — 機械(型+境界 parse テスト)
- [知識の増加を型に残す](./knowledge-in-types.md) — レビュー(保証差の判断レビュー)
- [論理設計と物理設計を分ける](./logical-physical-separation.md) — 機械+レビュー(依存方向検査+意味レビュー)
