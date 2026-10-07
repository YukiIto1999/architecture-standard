# generated 層

generated 層は、canonical と binding(http・protocol)から生成した出力を定める層である。
generated は、canonical の契約を code から使うときに置く。
generated は [layout](./layout.md) の依存に従う。

## 生成物

generated は、openapi・json schema・protocol の stub と、各言語の client・データ型・契約に基づく encoder と decoder である。
generated は、canonical と、ある場合は http・protocol の binding から生成する。
データ型は公開契約の field、variant、制約を具体的に表し、任意の map や未分類の payload に型の責務を委ねない。
データ型と通信を実行する client・stub は別の package または同等の依存単位として出力し、データ型だけの利用で HTTP client、接続設定、通信 runtime への依存を持ち込まない。
参照のドキュメントも、canonical と binding からの生成物であり、手で保守しない。

## 生成のみ

generated を、手で編集しない。
generated を、正本にしない。
生成器の設定、template、schema 駆動の出力処理も、単一の生成入口から再現できる入力として管理する。
生成 DTO の field、variant、制約、deserialize の処理に不足がある場合は、[canonical](./canonical.md) と binding と生成器の該当する入力を直し、利用側の手書き同義 DTO や生成後の手修正で補わない。

## 生成能力

生成した型と encoder・decoder は、既知の必須項目、不在、値の制約、判別子と variant の対応を契約どおりに扱う。
未知の項目の扱いは [canonical](./canonical.md) の「進化」に従い、受容と検知を実現する言語別の機構は [languages](../../languages/) が定める。
未知の項目を検知する生成処理は、全 variant と入れ子の object を対象にし、既知の項目の検証や variant の識別を省略しない。
採用した生成器の既定の出力がこれらを満たさない場合は、契約から導く生成処理で能力を補い、満たさない生成物を検証入口で拒否する。

## drift の検査

生成物と、生成元の canonical・binding(http・protocol)との drift を、リポジトリの検証入口で検査する。
drift があるときは、ビルドを失敗させる。

## 利用

公開契約を code で扱う提供側と利用側は、その契約から生成したデータ型を使う。
core の composition、core を埋め込む server・console・worker・埋め込み surface と host は、公開契約を持つ core の operation の入出力に generated のデータ型を使う。
HTTP または protocol の提供側に、利用側の通信 client を要求しない。
通信する利用側は、その通信を所有する adapter に generated の client または stub を置き、接続設定と transport の instance を引数で与え、generated 内に固定しない。
viewer と extension はデータ型の import にとどめ、通信の実装は host から port として受け取る。
root をまたぐ依存の許可は [skeleton](../skeleton.md) に従い、core のコンテキストと shared は generated の型にも client・stub にも依存しない。
