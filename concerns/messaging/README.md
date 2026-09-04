# messaging

## 概要
messaging は、イベントによる連携を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める複数集約の結果整合性と、[separation](../../principles/separation/README.md) が定める契約の独立を、全系のイベント連携として具象化する。
手順の所有と補償の正本は [workflow](../workflow/README.md) であり、messaging は event の契約と配送・消費を書く。

## 規律

- [domain event と integration event を分ける](./domain-integration-events.md) — レビュー(review規律照合のみ)
- [同期で済む連携はイベントにしない](./async-only-events.md) — レビュー(design/review照合のみ)
- [outbox から配送する](./outbox-delivery.md) — 機械(状態とoutbox同時確定)
- [少なくとも一度の配送を前提に冪等に消費する](./idempotent-consumption.md) — 機械(durable inbox検査)
- [順序・再試行・行き止まりを扱う](./ordering-retry-deadletter.md) — 機械(methods表 順序・行き止まり)
- [イベント契約を版で進化させ、寛容に読む](./event-contract-versioning.md) — 機械+レビュー(未知フィールド単体テスト)

## 参照
outbox の書き込みは [transaction](../transaction/README.md)、冪等・再試行・行き止まりの正本は [resilience](../resilience/README.md)、契約の独立は [separation](../../principles/separation/README.md) に従う。
手順の所有と補償の正本は [workflow](../workflow/README.md) であり、messaging は event の契約と配送・消費を書く。
言語別の実現は [tools](../tools/) が定める。
