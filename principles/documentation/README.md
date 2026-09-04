# documentation

documentation は、README、設計文書、commit log、決定の記録に関する原則を置く。
コードに焼き込めるものは文書に書かず、文書は最小で高シグナルにし、変更の目的と設計判断の理由を分けて残し、種別ごとに読み手を定める。

## 規律

- [コードに焼き込めるものは文書に書かない](./bake-into-code.md) — レビュー(文書の重複レビュー)
- [文書は最小で高シグナルにする](./minimal-high-signal.md) — レビュー(削除テストはレビュー)
- [変更の目的を commit log に残す](./commit-purpose.md) — レビュー(review の commit 照合)
- [設計判断の理由を決定の記録に残す](./decision-records.md) — レビュー(review の ADR 照合)
- [文書の種別を分け、読み手を定める](./separate-document-types.md) — レビュー(文書種別のレビュー)
