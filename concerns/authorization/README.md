# authorization

## 概要
authorization は、アクセス制御の流れを全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める変更理由での分割・関心の隠蔽・副作用の隔離を、全系のアクセス制御として具象化する。
authorization は認証境界による構築済みの actor の権限評価を扱い、資格情報の検証と actor の構築は [authentication](../authentication/README.md) が扱う。

## 規律

- [業務規則と認可を分ける](./business-rule-separation.md) — 機械+レビュー(認可test+重複レビュー)
- [入口で評価し、通った要求だけ進める](./evaluate-at-entry.md) — 機械+レビュー(matrix+評価位置レビュー)
- [認可の判定を port で委譲する](./policy-port.md) — 機械+レビュー(matrix+委譲配置レビュー)
- [拒否は業務の前で止める](./deny-before-business.md) — 機械+レビュー(権限matrix+機微文脈判断)

## 参照
分離の原則は [separation](../../principles/separation/README.md)、request context の伝播は [context-propagation](../context-propagation/README.md)、安全の姿勢は [security](../security/README.md) に従う。
外部へ公開するエラーの形は [effect](../effect/README.md) に従う。
資格情報の検証と actor の構築は [authentication](../authentication/README.md)、認証境界の surface ごとの構造は [surfaces](../structure/surfaces/)、言語別の実現は [tools](../tools/) が定める。
