# security

## 概要
security は、安全の姿勢を全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める関心の隠蔽を、全系の安全の姿勢として具象化する。

## 規律

- [境界の外を既定で信頼しない](./distrust-by-default.md) — 機械(abuse case+境界parse)
- [最小権限を与える](./least-privilege.md) — 機械+レビュー(default deny+権限matrix)
- [多層で防御する](./defense-in-depth.md) — レビュー(層設計はreview)
- [攻撃面を最小にする](./minimal-attack-surface.md) — レビュー(面の棚卸しはreview)
- [標準の暗号に任せる](./standard-cryptography.md) — 機械+レビュー(標準暗号の設定テスト)
- [供給網を保証する](./supply-chain-assurance.md) — 機械(供給物と依存の検査)

## 参照
入力の検証は [types](../types/README.md)、認可は [authorization](../authorization/README.md) に従う。
secret と鍵の保管は [secrets](../secrets/README.md) に従う。
伝送・供給網などの機構は [structure](../structure/) に置き、一つの箱へまとめない。
言語別の実現は [tools](../tools/) が定める。
