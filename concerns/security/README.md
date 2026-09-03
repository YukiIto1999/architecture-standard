# security

## 概要
security は、安全の姿勢を全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める関心の隠蔽を、全系の安全の姿勢として具象化する。

## 規律

- [境界の外を既定で信頼しない](./distrust-by-default.md)
- [最小権限を与える](./least-privilege.md)
- [多層で防御する](./defense-in-depth.md)
- [攻撃面を最小にする](./minimal-attack-surface.md)
- [標準の暗号に任せる](./standard-cryptography.md)
- [供給網を保証する](./supply-chain-assurance.md)

## 参照
入力の検証は [types](../types/README.md)、認可は [authorization](../authorization/README.md) に従う。
secret と鍵の保管は [secrets](../secrets/README.md) に従う。
伝送・供給網などの機構は [structure](../structure/) に置き、一つの箱へまとめない。
言語別の実現は [tools](../tools/) が定める。
