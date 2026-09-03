# secrets

## 概要
secrets は、資格情報・鍵の保存・参照・回転・失効・監査の lifecycle を統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める関心の隠蔽を、全系の secrets の扱いとして具象化する。
secret の値と lifecycle の正本は secrets であり、[configuration](../configuration/README.md) は secret 参照の型と起動時の解決を書く。

## 規律

- [secret を分けて専用の型に封じる](./sealed-secret-type.md)

## 参照
設定へ secret の参照を置き、起動時に値を解決する適用は [configuration](../configuration/README.md) が書く。
暗号の姿勢は [security](../security/README.md) に従う。
配備における secret の置き場は [structure/deploy](../structure/deploy/) が定める。
