# authentication

## 概要
authentication は、資格情報を受け取るすべての信頼境界で、資格情報を検証して業務上の actor を構築するまでを統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める関心を境界の内に隠す原則を、資格情報と認証方式を core から隔離する契約として具象化する。
authentication は資格情報の検証と actor の構築を扱い、構築済みの actor に対する権限評価は [authorization](../authorization/README.md) が扱う。

## 規律

- [資格情報を検証して actor を構築する](./credential-to-actor.md) — 機械(認証境界の検査とtest)

## 参照
「関心を境界の内に隠す」は [separation](../../principles/separation/information-hiding.md)、構築済みの actor の権限評価は [authorization](../authorization/README.md)、安全の姿勢は [security](../security/README.md) に従う。
認証境界の surface ごとの配置は [structure/surfaces](../structure/surfaces/)、言語別の実現は [tools](../tools/) が定める。
