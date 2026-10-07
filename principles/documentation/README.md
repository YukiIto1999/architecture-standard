# documentation

documentation は、README、設計文書、commit log、決定の意味を辿る記録と、それらとコメントに共通する文末の形に関する原則を置く。
現在の意味をコードとテストで表し、変更の Why を小さく一貫した commit に、現在の Why not を実装コメントに残す。
読者向けの文書は現在の正本からの投影とし、作業記録とは追跡と寿命を分ける。

## 規律

- [コードの意味を文書で代用しない](./bake-into-code.md) — レビュー(正本と文書の対応レビュー)
- [文書は最小で高シグナルにする](./minimal-high-signal.md) — レビュー(削除テストはレビュー)
- [変更の目的を commit log に残す](./commit-purpose.md) — レビュー(review の commit 照合)
- [設計判断の理由を決定の記録に残す](./decision-records.md) — レビュー(コード・テスト・commit・Why not の対応照合)
- [文書の種別を分け、読み手を定める](./separate-document-types.md) — レビュー(文書種別と寿命のレビュー)
- [文末の形を記述の種類で分ける](./sentence-endings.md) — 機械+レビュー(ドキュメントコメントの最初の一行の形の検査+その他の記述の文末のレビュー)
