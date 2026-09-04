# concurrency

## 概要
concurrency は、非同期と並行の実行を全系で統べる規律である。
principles の [construction](../../principles/construction/README.md) が定める不変な値の扱いと、[separation](../../principles/separation/README.md) が定める副作用の境界隔離を、全系の並行の扱いとして具象化する。
ここで扱うのは、複数を束ねて捌く構造の並行であり、同時に動かして速くする実行の並列ではない。
性能目的の並列化は、[performance](../performance/README.md) が計測の後の最適化の一手段として定める。
業務の核は同期の純粋関数に保ち、並行と非同期は境界で扱う。

## 規律

- [構造化並行で寿命をスコープに束ねる](./structured-concurrency.md) — 機械+レビュー(drain test+所属レビュー)
- [取り消しを協調的に伝える](./cooperative-cancellation.md) — 機械+レビュー(期限検査+安全性レビュー)
- [共有可変状態を避ける](./no-shared-mutable-state.md) — 機械+レビュー(mpsc検査+経路レビュー)
- [並行度を制限し、背圧を扱う](./bounded-concurrency-backpressure.md) — 機械(並行上限・過負荷test)
- [並行の駆動を言語の機構に委ねる](./delegate-to-language-async.md) — 機械+レビュー(runtime単一の構造検査)
- [非同期と並行を業務の核から隔離する](./isolate-async-from-core.md) — 機械+レビュー(I/O限定検査+純粋性判断)

## 参照
不変は [construction](../../principles/construction/README.md)、副作用の隔離は [separation](../../principles/separation/README.md) に従う。
効果の合成は [effect](../effect/README.md)、文脈の伝播は [context-propagation](../context-propagation/README.md) に従う。
待ち行列と流入の上限は [resilience](../resilience/README.md)、性能目的の並列化は [performance](../performance/README.md) に従う。
言語別の実現は [tools](../tools/) が定める。
