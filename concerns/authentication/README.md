# authentication

## 概要
authentication は、資格情報を受け取るすべての信頼境界で、資格情報を検証して認証主体を確定するまでを統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める関心を境界の内に隠す原則を、資格情報と認証方式を core から隔離する契約として具象化する。
authentication は資格情報の検証、認証主体の確定、業務が主体を必要とする操作への検証済み業務入力の対応づけを扱い、検証済み資格情報の許可範囲と認証主体に対する操作と対象のアクセス制御の評価は [authorization](../authorization/README.md) が扱う。

## 規律

- [資格情報を検証して認証主体を確定する](./credential-to-subject.md) — 機械+レビュー(認証境界の拒否・主体と許可範囲の検査+資格情報の種類ごとの検証根拠の照合)

## 参照
「関心を境界の内に隠す」は [separation](../../principles/separation/information-hiding.md)、業務のモデリングで使う役割と変更要求者は [separation](../../principles/separation/split-by-change-reason.md)、認証主体に対するアクセス制御は [authorization](../authorization/README.md)、安全の姿勢は [security](../security/README.md) に従う。
資格情報の取得、保管、限定した保持、発行・交換応答は [secrets](../secrets/README.md) に従う。
認証境界の surface ごとの配置は [structure/surfaces](../../structure/surfaces/)、言語別の実現は [languages](../../languages/) が定める。
