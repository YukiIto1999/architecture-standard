# persistence

## 概要
persistence は、永続データの設計を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める事実の追記と整合性の所在を、関係と制約による永続データの設計として具象化する。
persistence は静止した関係と制約を扱い、書き込みパスの動的な確定は [transaction](../transaction/README.md) が扱う。
永続化と一時データの実現に用いる store は単一とし、採用は [tools/platforms](../../tools/platforms/README.md) が定める。
cache の規律の正本は [caching](../caching/README.md) に置く。
store の採用では、persistence は datastore と一時データの store の単一採用だけを扱う。

## 規律

- [事実・状態・時間を別の関係に落とす](./fact-state-time-relations.md) — レビュー(schema設計はreview)
- [事実を追記する形で残す](./append-only-facts.md) — 機械+レビュー(関係名の denylist 検査+schema 設計のレビュー)
- [追記した事実の版を読み出しで現在へ変換する](./read-time-upcasting.md) — レビュー(review規律照合のみ)
- [正規化して一つの事実を一箇所に置く](./normalization.md) — レビュー(schema設計はreview)
- [関係の意図を制約で表す](./relational-constraints.md) — 機械+レビュー(実datastore制約テスト)
- [一つの操作の問い合わせ数を件数から独立させる](./bounded-query-count.md) — 機械(問い合わせ数不変テスト)
- [物理の最適化は計測した根拠で行う](./measured-physical-optimization.md) — 機械+レビュー(計測+再構築の検証)
- [派生の再構築を決定的にする](./deterministic-rebuild.md) — 機械(再構築決定性テスト)
- [datastore と一時データの store を単一に採用する](./single-store-adoption.md) — 機械+レビュー(store単一性の構造検査)

## 参照
データの原則は [data](../../principles/data/README.md)、論理設計と物理設計の分離は [modeling](../../principles/modeling/README.md)、書き込みパスの一貫性は [transaction](../transaction/README.md) に従う。
稼働中のスキーマと別 datastore への移行は [migration](../migration/README.md) に従う。
cache の鮮度・無効化・不在・障害時の意味は [caching](../caching/cache-aside.md) の「cache を正本の控えに保つ」に従う。
永続化の置き場は [structure/core/infrastructure](../../structure/core/infrastructure.md)、言語別の実現は [tools](../tools/) が定める。
