# transaction

## 概要
transaction は、書き込みパスの一貫性と確定点を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める整合性と集約境界、事実の追記と現在状態の導出を、全系の書き込みの扱いとして具象化する。
transaction は書き込みパスの動的な確定を扱い、静止した関係と制約は [persistence](../persistence/README.md) が扱う。

## 規律

- [整合性を一つの書き込みパスに閉じる](./single-write-path.md)
- [一つの確定点を持つ](./single-commit-point.md)
- [状態とイベントを同一パスで記録する](./state-event-atomicity.md)
- [冪等にして再実行できるようにする](./scoped-idempotency-keys.md)
- [部分確定を不可視にする](./invisible-partial-commits.md)
- [書き込みパスの所有を組立点に置く](./composition-owned-transactions.md)

## 参照
整合性と集約は [data](../../principles/data/README.md)、効果とエラーは [effect](../effect/README.md) に従う。
配送は [messaging](../messaging/README.md)、冪等と再試行は [resilience](../resilience/README.md) に従う。
書き込みパスの所有を実現する構造は [structure/core/composition](../../structure/core/composition.md)、言語別の実現は [tools](../tools/) が定める。
