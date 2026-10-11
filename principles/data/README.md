# data

data は、データと状態に関する原則を置く。
整合性を集約境界に閉じ、データを意味で分類し、業務事実と現在情報を分けて保持し、今の状態を事実の行から導き、整合性をデータ層の制約で守り、原則がぶつかるときの順位を定める。
論理と物理の分離は [modeling](../modeling/README.md)、正本と互換の独立は [separation](../separation/README.md)、状態の命名は [naming](../naming/README.md) に従う。
concerns の [persistence](../../concerns/persistence/README.md) が永続データの関係と制約を、[transaction](../../concerns/transaction/README.md) が書込経路の確定を、[privacy](../../concerns/privacy/README.md) が個人情報の保持と消去を定める。

## 規律

- [整合性を集約境界に閉じる](./aggregate-integrity.md) — 機械+レビュー(確定点テスト+境界レビュー)
- [データを事実・状態・時間で分類する](./fact-state-time.md) — レビュー(分類のモデリングレビュー)
- [業務事実と現在情報を分けて保持する](./preserve-facts-and-current-state.md) — 機械+レビュー(実 datastore の消去・競合・原子性・保持期限削除の検証と派生値の再構築検証+保持契約のレビュー)
- [今の状態を事実の行から導く](./derive-state-from-facts.md) — 機械+レビュー(実 datastore の期間の判定と閉じ方の検証+状態の記録の不在のレビュー)
- [整合性をデータ層の制約で守る](./database-integrity.md) — 機械+レビュー(実 datastore 制約テストと手続きの不在の検査+守らない条件の記録のレビュー)
- [データの原則は定めた順位で優先する](./precedence.md) — レビュー(原則の衝突と例外の決定の記録のレビュー)
