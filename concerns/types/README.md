# types

## 概要
types は、型で全系の不変条件を守る規律である。
principles の [modeling](../../principles/modeling/README.md) が定める、不正な状態の排除・境界での parse を、全系の型の扱いとして具象化する。
保証を所有する型と責務ごとに入力境界を定め、同じ型への経路を一つの変換器の集合へ集める。
その責務の内側は型の保証を前提にし、独立した契約や業務モデルへの写像は、受け手が所有する型の構築を通す。

## 規律

- [不正な状態を型で構築できなくする](./unrepresentable-invalid-states.md) — 機械(formation型・網羅検査)
- [境界で一度だけ parse する](./parse-once-at-boundary.md) — 機械+レビュー(境界parse型+単体テスト+検証済み型と独立したモデルの構築責務の照合)
- [型の情報を失う箇所を監査する](./audited-type-loss.md) — 機械(cast allowlist検査)
- [部分的な成功を直和で表す](./partial-success-union.md) — 機械+レビュー(型網羅+境界設計review)

## 参照
封入と分類の原則は [modeling](../../principles/modeling/README.md)、語彙は [naming](../../principles/naming/README.md) に従う。
境界での検証に伴う効果の実行は [effect](../effect/README.md) に従う。
言語別の型機構は [languages](../../languages/) が定める。
