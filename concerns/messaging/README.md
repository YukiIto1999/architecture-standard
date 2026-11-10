# messaging

## 概要
messaging は、イベントによる連携を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める、同時の確定を要さない同一コンテキストの集約どうしの結果整合性と、[separation](../../principles/separation/context-relationships.md) の「コンテキストを業務上独立させる」を、内部の非同期処理と独立した外部への事実の公開・消費として具象化する。
event の契約と配送・消費の扱いは、[参照](#参照) が示す正本に従う。

## 規律

- [domain event と integration event を分ける](./domain-integration-events.md) — レビュー(review規律照合のみ)
- [同期で済む連携はイベントにしない](./async-only-events.md) — レビュー(業務操作・進行の所有と非同期にする理由の照合)
- [outbox から配送する](./outbox-delivery.md) — 機械(状態とoutbox同時確定)
- [少なくとも一度の配送を前提に冪等に消費する](./idempotent-consumption.md) — 機械(durable inbox検査)
- [順序・再試行・行き止まりを扱う](./ordering-retry-deadletter.md) — 機械(methods表 順序・行き止まり)
- [イベント契約を版で進化させ、寛容に読む](./event-contract-versioning.md) — 機械+レビュー(実受信経路の受容と拒否・業務処理非開始・旧版配送残存の検査+版変換と撤去範囲の照合)

## 参照
outbox の書き込みは [transaction](../transaction/README.md)、冪等・再試行・行き止まりの正本は [resilience](../resilience/README.md)、コンテキストの独立性は [separation](../../principles/separation/README.md) に従う。
手順の所有と補償の正本は [workflow](../workflow/README.md) であり、messaging は event の契約と配送・消費を書く。
言語別の実現は [languages](../../languages/) が定める。
