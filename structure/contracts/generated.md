# generated 層

generated 層は、canonical と binding(http・protocol)から生成した出力を定める層である。
generated は、別プロセスの client または型を要するときに置く。
generated は [layout](./layout.md) の依存に従う。

## 生成物

generated は、openapi・json schema・protocol の stub と、各言語の client・型である。
generated は、canonical と、ある場合は http・protocol の binding から生成する。

## 生成のみ

generated を、手で編集しない。
generated を、正本にしない。

## drift の検査

生成物と、生成元の canonical・binding(http・protocol)との drift を、CI で検査する。
drift があるときは、ビルドを失敗させる。

## 利用

別プロセスの通信境界は、generated の型と client を参照する。
client は、接続の設定と HTTP client の instance を引数で受け取り、generated 内に固定しない。
viewer と extension は、generated の型の import にとどめる。
