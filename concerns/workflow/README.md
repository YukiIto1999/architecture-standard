# workflow

## 概要
workflow は、複数の確定点にまたがる一つの業務目的の順序・分岐・再開・補償を統べる規律である。
principles の [data](../../principles/data/README.md) が定める複数集約の結果整合性を、全系の業務の流れとして具象化する。
event の契約と配送・消費は [messaging](../messaging/README.md)、確定点は [transaction](../transaction/README.md)、再開の記録と配置は [structure/core/application](../../structure/core/application.md) が定める。

## 規律

- [連携の手順の所有を決める](./orchestration-choreography.md)
- [連鎖の失敗を、逆順の補償で打ち消す](./reverse-compensation.md)

## 参照
event の契約と配送・消費は [messaging](../messaging/README.md) に従う。
確定点は [transaction](../transaction/README.md) に従う。
再開の記録と配置は [structure/core/application](../../structure/core/application.md) が定める。
打ち消す事実の追記の形は [data](../../principles/data/README.md) に従う。
言語別の実現は [tools](../tools/) が定める。
