# separation

separation は、分割と依存に関する原則を置く。
何を同じ境界に入れ、何を分け、結合をどう弱め、依存をどちらへ向けるかを定める。

## 規律

- [変更理由で分ける](./split-by-change-reason.md) — レビュー(design/実装の図示照合)
- [サブドメインの種別で設計投資を配分する](./subdomain-investment.md) — 機械+レビュー(分類記録と構造対応の検査)
- [コンテキスト間の関係を明示して選ぶ](./context-relationships.md) — レビュー(ADR 記録と design 照合)
- [分類軸と粒度を階層で揃える](./classification-granularity.md) — 機械+レビュー(配置検査+分類軸レビュー)
- [関心を境界の内に隠す](./information-hiding.md) — 機械+レビュー(可視性検査+契約レビュー)
- [結合を距離に見合う強さにする](./coupling-by-distance.md) — 機械+レビュー(記録有無は機械/内容レビュー)
- [依存を安定と抽象へ向ける](./stable-abstract-dependencies.md) — 機械(依存方向の構造検査)
- [副作用を境界に集める](./effects-at-boundaries.md) — 機械+レビュー(純粋性検査+核のレビュー)
- [正本を互換から独立させる](./compatibility-isolation.md) — レビュー(review の境界照合)
