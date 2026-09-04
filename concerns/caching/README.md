# caching

## 概要
caching は、正本から再構築できる短寿命の導出状態の鮮度・無効化・不在・障害時の意味を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める導出と控えの定めを、cache の扱いとして具象化する。
cache の規律の正本は、このファイルに置く。

## 規律

- [cache を正本の控えに保つ](./cache-aside.md) — 機械(失効・分散・不在のtest)

## 参照
事実の正本の datastore と一時データの store の単一採用は [persistence](../persistence/single-store-adoption.md) の「datastore と一時データの store を単一に採用する」に従う。
cold cache の負荷は [performance](../performance/measure-before-compare.md) の「計測を定めてから比べる」に従う。
HTTP cache の protocol 適用は [structure/contracts/http](../../structure/contracts/http.md) の「cache 可能性」が定める。
cache と一時データの store の採用は [tools/platforms/valkey](../../tools/platforms/valkey.md) が定める。
