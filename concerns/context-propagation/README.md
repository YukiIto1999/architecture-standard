# context-propagation

## 概要
context-propagation は、同一実行に随伴して境界を越える metadata の不変な carrier と伝播の契約を全系で統べる規律である。
principles の [construction](../../principles/construction/README.md) が定める不変の定めを、同一実行に随伴して境界を越える metadata の carrier と伝播の契約として具象化する。

## 規律

- [文脈を一つにまとめて伝える](./unified-request-context.md) — 機械+レビュー(Deadline検査+集約レビュー)

## 参照
trace の意味と観測への付与は [observability](../observability/README.md) が正本である。
取り消しと期限の意味は [concurrency](../concurrency/README.md) が正本である。
actor の構築は [authentication](../authentication/README.md) が正本である。
載せてよい情報の制限は [privacy](../privacy/README.md) と [security](../security/README.md) が正本である。
