# configuration

## 概要
configuration は、設定の扱いの方針を全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める副作用の隔離と関心の隠蔽を、全系の設定の扱いとして具象化する。
secret の正本は [secrets](../secrets/README.md) であり、configuration は secret 参照の型と起動時の解決を書く。

## 規律

- [設定を型付きの値で扱う](./typed-config.md)
- [定めた源からまとめて読む](./single-config-source.md)
- [環境差分を設定値で表す](./environment-as-values.md)
- [起動時に検証する](./validate-at-startup.md)
- [起動時設定と実行時 flag を分ける](./config-vs-flags.md)

## 参照
分離の原則は [separation](../../principles/separation/README.md)、検証に失敗した起動の停止は [lifecycle](../lifecycle/README.md)、secret の伝送は [security](../security/README.md) に従う。
secret の正本は [secrets](../secrets/README.md) であり、configuration は secret 参照の型と起動時の解決を書く。
設定の読み込みと flag の配置は、プロセスを起動する [structure/surfaces](../structure/surfaces/) または [structure/runtimes](../structure/runtimes/) が定め、言語別の機構は [tools](../tools/) が定める。
