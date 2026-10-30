# effect

## 概要
effect は、副作用の統合を全系で統べる親規律であり、効果システムを定める。
効果システムは、生成と合成、要求する依存、想定内の失敗と欠陥と取り消し、資源、境界での解釈を、効果の代数として備える。
副作用は、遅延した効果の記述として組み、純粋核を包まない。
要求する依存と想定内の失敗を型に現し、実行は runtime の境界に限る。
副作用の最下層にあたる現在時刻・乱数・ID の生成・入出力・外部通信の呼出しを、原始効果と呼ぶ。
効果が要求する依存の配線は、[dependency](../dependency/README.md) に従う。
principles の [construction](../../principles/construction/README.md) が定める不変と変換パイプラインと、[separation](../../principles/separation/README.md) が定める副作用の境界隔離を、全系の効果の扱いとして具象化する。
非同期と取り消しは [concurrency](../concurrency/README.md) へ委譲する。
失敗の直和の網羅と構築の規律は、[types](../types/unrepresentable-invalid-states.md) の「不正な状態を型で構築できなくする」に従う。

## 規律

- [純粋核と効果の殻に分ける](./pure-core-effect-shell.md) — 機械+レビュー(I/O限定検査+純粋性判断)
- [効果を遅延した記述にして端で実行する](./deferred-effect-descriptions.md) — 機械(構築の無実行test+遅延の静的検査)
- [要求と想定内失敗を型に現す](./typed-requirements-failures.md) — 機械+レビュー(型+暗黙の依存と原始効果の静的検査+迂回レビュー)
- [失敗と欠陥と取り消しを分ける](./failure-defect-cancellation.md) — 機械(四つの終了、完了と取り消し・期限の競合、時間の上限を設けた側の超過と内側の取り消し、取り消しと超過の重なり、上限の状態によらない中断の非帰属の test+型)
- [失敗と欠陥を値の出所で判別する](./value-origin-classification.md) — 機械+レビュー(境界parse test+通信の不成立の test+出所判断)
- [取り消しと資源を言語の機構に委ねる](./cancellation-resource-safety.md) — 機械(資源の解放を閉じる型と取り消し・解放のtest)
- [合成して部分代替できるようにする](./composable-stages.md) — 機械+レビュー(Result型+段構成レビュー)

## 参照
不変と変換は [construction](../../principles/construction/README.md)、副作用の隔離は [separation](../../principles/separation/README.md) に従う。
非同期と取り消しは [concurrency](../concurrency/README.md)、依存の配線は [dependency](../dependency/README.md) に従う。
失敗の直和の構築規律は [types](../types/README.md) に従う。
書き込みの確定は [transaction](../transaction/README.md) に従う。
機構の置き場は [structure](../../structure/)、言語別の実現は [languages](../../languages/) が定める。
