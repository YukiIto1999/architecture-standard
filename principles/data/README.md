# data

data は、データと状態に関する原則を置く。
整合性を集約境界に閉じ、データを意味で分類し、事実を追記して現在状態を導き、整合性をデータ層の制約で守る。
論理と物理の分離は [modeling](../modeling/README.md)、正本と互換の独立は [separation](../separation/README.md)、状態の命名は [naming](../naming/README.md) に従う。
関係と制約による永続データの設計は、concerns の [persistence](../../concerns/persistence/README.md) が具象化する。

## 規律

- [整合性を集約境界に閉じる](./aggregate-integrity.md) — 機械+レビュー(確定点テスト+境界レビュー)
- [データを事実・状態・時間で分類する](./fact-state-time.md) — レビュー(分類のモデリングレビュー)
- [事実は追記し、現在状態は導出する](./append-facts-derive-state.md) — 機械+レビュー(replay 検証+判断レビュー)
- [整合性をデータ層の制約で守る](./database-integrity.md) — 機械+レビュー(実 datastore 制約テスト)
