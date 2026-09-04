# performance

## 概要
performance は、計測の後の最適化を全系で統べる規律である。
principles の [construction](../../principles/construction/README.md) が定める単純な形の既定と投機の排除を、性能の扱いとして具象化する。
計測を定めてから比べ、改善は計測が根拠を示した後にだけ行い、推測で単純な形を崩さない。

## 規律

- [計測を定めてから比べる](./measure-before-compare.md) — 機械(methods表 SLO計測)
- [計測の後にだけ最適化する](./optimize-after-measurement.md) — 機械+レビュー(前後比較計測+レビュー)
- [性能目的の並列化を計測の後の一手段にする](./measured-parallelization.md) — 機械+レビュー(SLO計測+ADRレビュー)

## 参照
単純な形の既定と投機の排除は、principles の [construction](../../principles/construction/simplicity-by-default.md) の「単純な形を既定にする」と、[no-speculation](../../principles/construction/no-speculation.md) の「投機的で説明できない要素を作らない」に従う。
永続データの物理の最適化への適用は [persistence](../persistence/README.md)、並行の構造は [concurrency](../concurrency/README.md) に従う。
永続化の改善も、計測した制約を一つずつ解消するこの規律に従う。
言語別の機構は [tools](../tools/) が定める。
