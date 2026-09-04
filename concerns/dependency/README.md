# dependency

## 概要
dependency は、依存の向きと合成を全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める依存方向と関心の隠蔽を、全系の依存の扱いとして具象化する。
依存はゼロにするのでなく、安定で抽象なものへ向ける。
効果が要求する依存の型での表現は [effect](../effect/README.md) が定め、dependency はその配線を統べる。

## 規律

- [依存を内側へ一方向に向ける](./inward-dependencies.md) — 機械(依存方向の構造検査)
- [抽象を方針側が所有する](./policy-owned-abstractions.md) — 機械+レビュー(依存方向検査+幅レビュー)
- [port を目的で宣言する](./purpose-driven-ports.md) — 機械+レビュー(fake隔離test+目的判断)
- [配線を組立点に集める](./composition-root.md) — 機械+レビュー(組立点外生成検出+レビュー)
- [依存は構成子で受け取る](./constructor-injection.md) — 機械+レビュー(locator検出+レビュー)
- [循環を作らず、安定へ依存し、詳細を先送りする](./acyclic-stable-dependencies.md) — 機械+レビュー(循環検査+安定度レビュー)

## 参照
依存と境界の原則は [separation](../../principles/separation/README.md)、効果の合成は [effect](../effect/README.md) に従う。
投機の排除は principles の [construction](../../principles/construction/no-speculation.md) の「投機的で説明できない要素を作らない」に従う。
プロセス全体の組立点は [structure/surfaces](../structure/surfaces/) と [structure/runtimes](../structure/runtimes/) が、core の module factory は [structure/core/composition](../../structure/core/composition.md) が定める。言語別の依存注入は [tools](../tools/) が定める。
