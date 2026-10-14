# context-propagation

## 概要
context-propagation は、同一実行に随伴して境界を越える metadata の不変な carrier と伝播の契約を全系で統べる規律である。
principles の [construction](../../principles/construction/README.md) が定める不変の定めを、同一実行に随伴して境界を越える metadata の carrier と伝播の契約として具象化する。

## 規律

- [実行文脈の由来と寿命を保って伝える](./unified-request-context.md) — 機械+レビュー(Deadline検査+由来・寿命レビュー)

## 参照
trace の意味と観測への付与は [observability](../observability/README.md) が正本である。
取り消しと期限の意味は [concurrency](../concurrency/README.md) が正本である。
認証主体と資格情報の許可範囲の保持は [authentication](../authentication/README.md) が正本であり、業務の入力の形は [structure/core](../../structure/core/) が定める。
認証主体、資格情報の許可範囲、業務の入力は、いずれも carrier へ載せない。
載せてよい情報の制限は [privacy](../privacy/README.md) と [security](../security/README.md) が正本である。
