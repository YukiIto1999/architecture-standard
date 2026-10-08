# secrets

## 概要
secrets は、資格情報と鍵の取得、保管、限定した保持、参照、回転、失効、監査の lifecycle を統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める関心の隠蔽を、全系の secrets の扱いとして具象化する。
secret の値と lifecycle の正本は secrets であり、設定由来の参照解決と対話認証による取得、永続保管とメモリ上の保持、正当な資格情報の発行・交換を区別する。

## 規律

- [secret を分けて専用の型に封じる](./sealed-secret-type.md) — 機械+レビュー(型封じ+非流出・生存期間・発行応答の検査)

## 参照
設定の構造と読み込みの規律は [configuration](../configuration/README.md) に従う。
暗号の姿勢は [security](../security/README.md) に従う。
資格情報から actor への変換は [authentication](../authentication/README.md)、操作と対象への許可の評価は [authorization](../authorization/README.md) に従う。
配備における secret の置き場は [structure/deploy](../../structure/deploy/) が定める。
