# workflow

## 概要
workflow は、複数の確定点にまたがる一つの業務目的の順序・分岐・再開・補償を統べる規律である。
複数の集約の判断を一度に確定できる業務動作は use-case が確定し、workflow は、確定を分けた先の連鎖と停止を越える進行を、集約の数によらず扱う。
event と確定点の扱いは、[参照](#参照) が示す正本に従う。

## 規律

- [連携の手順の所有を決める](./orchestration-choreography.md) — レビュー(手順所有はdesign照合)
- [連鎖の失敗を、逆順の補償で打ち消す](./reverse-compensation.md) — 機械(補償開始・冪等テスト)
- [進行の状態を持ち、停止から再開する](./resumable-progress.md) — 機械+レビュー(試行回数・次の実行時刻・期限・完了記録・操作の識別の停止再開と、停止・再開・自動再投入での上限のリセットの不在のテスト+状態の業務上の意味と所有のレビュー)
- [中間の状態を語彙にして、公開の範囲を分ける](./intermediate-state-exposure.md) — 機械+レビュー(状態の型網羅と面ごとの通過集合のテスト+公開範囲の設計レビュー)

## 参照
event の契約と配送・消費は [messaging](../messaging/README.md) に従う。
確定点は [transaction](../transaction/README.md) に、同時に確定するか確定を分けるかの判断は [data](../../principles/data/aggregate-integrity.md) の「整合性を集約境界に閉じる」に従う。
再開の記録が持つ内容は [進行の状態を持ち、停止から再開する](./resumable-progress.md) が所有し、記録を保存する層と port の配置は [structure/core/application](../../structure/core/application.md) が定める。
打ち消す事実の追記の形は [data](../../principles/data/README.md) に従う。
言語別の実現は [languages](../../languages/) が定める。
