# verification

verification は、検証に関する原則を置く。
重要な制約を機械検証に固定し、実行可能な仕様を実装と同じ検査経路に載せ、テストを設計の道具にし、テストを振る舞いの安全網にし、テストの信頼性を保つ。
要件の確定は [requirements](../requirements/README.md) に従う。

## 規律

- [重要な制約を機械検証に固定する](./machine-enforced-constraints.md) — 機械(検証入口と対応表照合)
- [検査が見るのは書かれたものだけである](./enforce-existence.md) — 機械(実体照合と件数0拒否)
- [テストを設計の道具にする](./tests-as-design.md) — レビュー(実装手順の red 確認)
- [テストを振る舞いの安全網にする](./behavioral-safety-net.md) — 機械+レビュー(size 検査+単位レビュー)
- [テストの信頼性を保つ](./test-reliability.md) — 機械+レビュー(mutation 検査+緩和承認)
