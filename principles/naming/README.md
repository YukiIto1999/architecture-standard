# naming

naming は、命名と語彙に関する原則を置く。
名前で意味を表し、業務の語彙を統一する。
識別子は英語で書き、役割と具体で名付ける。
汎用名と略語を制限し、種類ごとに名付ける。
参照範囲で名前の可変性を見積もり、最初の命名を丁寧にして乱れを早期に直し、テスト名で仕様を表す。
casing と接辞の形式の規約は言語ごとに異なるため、[tools](../tools/) に置く。

## 規律

- [名前で意味を表す](./meaningful-names.md) — レビュー(意味の読解はレビュー)
- [語彙を統一する](./unified-vocabulary.md) — レビュー(語彙一致はレビュー)
- [識別子を英語で書く](./english-identifiers.md) — レビュー(レビュー照合のみ)
- [役割と具体で名付ける](./role-and-concreteness.md) — 機械+レビュー(denylist+役割レビュー)
- [汎用名・略語・一時名を制限する](./restrict-generic-names.md) — 機械(denylist lint で禁止)
- [種類ごとに名付ける](./per-kind-naming.md) — レビュー(命名の意味はレビュー)
- [参照範囲で可変性を見積もる](./rename-cost-by-scope.md) — レビュー(改名判断のレビュー)
- [最初の命名を丁寧にし、乱れを早期に直す](./deliberate-initial-naming.md) — レビュー(命名レビューのみ)
- [テスト名は仕様を表す](./test-names-as-specs.md) — レビュー(review/実装の確認点)
