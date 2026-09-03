# types

## 概要
types は、型で全系の不変条件を守る規律である。
principles の [modeling](../../principles/modeling/README.md) が定める、不正な状態の排除・境界での parse を、全系の型の扱いとして具象化する。
全系を貫く鎖は一つである。
境界で一度だけ外部の表現を型へ変換し、通った値だけが内側へ入り、内側は再検証せず型が保証する。

## 規律

- [不正な状態を型で構築できなくする](./unrepresentable-invalid-states.md)
- [境界で一度だけ parse する](./parse-once-at-boundary.md)
- [型の情報を失う箇所を監査する](./audited-type-loss.md)
- [部分的な成功を直和で表す](./partial-success-union.md)

## 参照
封入と分類の原則は [modeling](../../principles/modeling/README.md)、語彙は [naming](../../principles/naming/README.md) に従う。
境界での検証に伴う効果の実行は [effect](../effect/README.md) に従う。
言語別の型機構は [tools](../tools/) が定める。
