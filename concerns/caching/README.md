# caching

## 概要
caching は、正本または計算から再構築できる結果を保って再利用するときの、結果の妥当性と保持を全系で統べる規律である。
再利用する結果は、正本にせず、欠けても取得または再計算で取り戻せる形に保つ。
principles の [data](../../principles/data/README.md) が定める導出と控えの定めを、再利用する結果の扱いとして具象化する。
再利用は、結果が依存する入力と可変な正本を特定してから行う。
適用する規律は、再利用が古い結果を許すかで分ける。
古い結果を許さず、計算と入力と依存の同一性を確かめて再利用する決定的な計算は、memo とする。
正本の現在の値を確かめず、許容する古さの範囲で再利用する取得は、取得 cache とする。
依存を特定できない結果は、期限を付けても再利用しない。
cache と memo の規律の正本は、この概念に置く。

## 規律

- [可変な正本の取得 cache の古さを期限と無効化で閉じる](./cache-aside.md) — 機械+レビュー(失効・無効化・分散・不在のtest+依存する正本と許容する古さと無効化の対象の記録のレビュー)
- [決定的な結果の再利用を依存の同一性で閉じる](./deterministic-memo.md) — 機械+レビュー(依存変更後の期待値との一致、保持量の上限と所有者終了時の回収のtest+依存の網羅と効果の不在のレビュー)

## 参照
事実の正本の datastore と一時データの store の単一採用は [persistence](../persistence/single-store-adoption.md) の「datastore と一時データの store を単一に採用する」に従う。
cold cache の負荷は [performance](../performance/measure-before-compare.md) の「計測を定めてから比べる」に従う。
HTTP cache の protocol 適用は [structure/contracts/http](../../structure/contracts/http.md) の「cache 可能性」が定める。
cache と一時データの store の採用は [tools/platforms/valkey](../../tools/platforms/valkey.md) が定める。
