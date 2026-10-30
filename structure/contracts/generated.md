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
生成器の設定、template、schema 駆動の出力処理の置き場と再現可能な生成入口は [layout](./layout.md) の「生成の toolchain」に従う。
生成 DTO の field、variant、制約、deserialize の処理に不足がある場合は、[canonical](./canonical.md) と binding と生成器の該当する入力を直し、利用側の手書き同義 DTO や生成後の手修正で補わない。

## 生成能力

生成した型と encoder・decoder は、項目の必須・任意と null の許容、未指定時の意味、値の制約、判別子と variant の対応を契約どおりに扱う。
値の制約は、型が表す形式、数値の値域と精度、日時の精度と offset、文字列長の単位を含む。
契約が受理する値を、生成先の言語の既定の型や数え方で拒否も丸めもせず、契約が拒否する値を受理しない。
JSON の数値は、実装が値域と精度を制限でき、整数の正確な一致を実装間で期待できる範囲は ±(2^53-1) である([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259#section-6))ので、binary64 を既定の数値型にする生成先は、その範囲を越える整数や binary64 で表せない十進数を、そのままでは保てない。
`date-time` は小数秒の桁数に上限がなく、offset を `Z` か `±hh:mm` で持つ([RFC 3339](https://www.rfc-editor.org/rfc/rfc3339#section-5.6))ので、契約が受理する日時を、生成先の既定の日時型が持てる精度や offset へ丸めず、拒否もしない。
JSON Schema の `minLength` と `maxLength` は、UTF-16 の code unit や UTF-8 の byte でなく、Unicode の文字(code point)の数を数える([JSON Schema Validation](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.3.1))ので、長さは契約が数える単位で数える。
`format` は、JSON Schema では既定で検証されず([JSON Schema Validation](https://json-schema.org/draft/2020-12/json-schema-validation#section-7.2.1))、OpenAPI 3.0 では認識しない format を型だけへ戻してよい([OpenAPI Specification 3.0.3](https://spec.openapis.org/oas/v3.0.3.html#data-types))ので、出力 schema に `format` を書いたことだけを、decoder が形式を強制する保証にしない。
未知の項目の扱いは [canonical](./canonical.md) の「進化」に従い、受容と検知を実現する言語別の機構は [languages](../../languages/) が定める。
未知の項目を検知する生成処理は、全 variant と入れ子の object を対象にし、既知の項目の検証や variant の識別を省略しない。
採用した生成器の既定の出力がこれらを満たさない場合は、契約から導く生成処理で能力を補い、満たさない生成物を検証入口で拒否する。

## drift の検査

生成物と、生成元の canonical・binding(http・protocol)との drift を、リポジトリの検証入口で検査する。
drift があるときは、ビルドを失敗させる。

## 利用

公開契約を code で扱う提供側と利用側は、その契約から生成したデータ型を使う。
core の業務操作へ接続する提供側と host は、公開契約の入出力に generated のデータ型を使い、[adapters](./adapters.md) で core の application 型へ写像する。
host が所有する技術操作も同じ正本から生成したデータ型と codec を両端で使い、core 向けの adapter を経由させず host の公開 Interface へ接続する。
HTTP または protocol の提供側に、利用側の通信 client を要求しない。
通信する利用側は、その通信を所有する adapter に generated の client または stub を置き、接続設定と transport の instance を引数で与え、generated 内に固定しない。
viewer と extension はデータ型の import にとどめ、通信の実装は host から port として受け取る。
root をまたぐ依存の許可は [skeleton](../skeleton.md) に従い、core は composition を含め generated の型にも client・stub にも依存しない。

## 応答の分類

[http](./http.md) の binding から生成した client の呼び出し結果は、契約が宣言した応答、契約に無い応答と decode の失敗、要求の組立の失敗、通信の失敗、時間上限の超過、取り消しに区別し、混ぜない。
契約が宣言した応答は、宣言した status と body の型に一致した応答であり、宣言した成功は成功に、宣言した失敗は operation の想定内の失敗に割り当てる。
宣言する status は、[http](./http.md) の「応答の status」に従い、成功の 2xx と失敗の 4xx・5xx に限る。
契約に無い応答と decode の失敗は、宣言していない status の応答と、宣言した status で body を契約の型へ decode できない応答であり、成功の応答の body を含め、欠陥に割り当てる。
ただし 502・503・504 は、gateway・proxy が上流から有効な応答を得られない場合や、server が一時的に処理できない場合の status であり([RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.6.3) の 15.6.3 から 15.6.5)、body を中継者が作りうる。
この三つの status で body が契約の宣言した型に一致しない応答は、宣言していない場合を含め、同じ出所の応答として通信の失敗に割り当て、一致する応答は宣言した失敗に割り当てる。
要求の組立の失敗は、自ら直列化する処理の不一致であり、欠陥に割り当てる。
通信の失敗は、応答の status と body を受け取れなかった失敗と、受け取った応答を読み切れなかった失敗であり、想定内の失敗に割り当てる。
呼び出しごとの時間上限は、HTTP client の timeout でなく、言語の取り消しと期限の機構で設け、[concerns/resilience](../../concerns/resilience/dependency-call-control.md) の「外部依存の呼び出しを制御する層に置く」に従い、受け取った期限と合成して短い方を採る。
時間上限の超過は、通信の失敗に含めず、上限を設けた側の想定内の失敗に割り当て、取り消しは取り消しに割り当てる。
受け取り終えた応答は確定した終了であり、その後に観測した取り消しや期限の超過で、割り当てを書き換えない。
応答を受け取れずに中断した呼び出しのうち、取り消しにも時間上限の超過にもならないもの(HTTP client や OS が自ら設けた timeout と HTTP client の内部の取り消しを含む)は、通信の失敗に割り当てる。
契約に無い応答と decode の失敗を欠陥とするのは、client の相手が同じ canonical を実装する提供側であり、その不一致が自ら直列化し自ら復元する処理の不一致にあたるためである。
分類は、契約が宣言した応答の集合との照合で決める。
照合は status を先に、次に body の型で行い、status の範囲や生成器の例外の型と variant だけで決めない。
生成器が宣言した成功の応答を例外や契約に無い応答として返す場合は、宣言した status との照合で成功へ戻す。
生成器が宣言した status の body を decode せずに返す場合は、利用側が契約から生成した型で decode し、一致しなければ decode の失敗として扱う。
利用側は、宣言した失敗を operation の想定内の失敗の型へ写し、他の種類と同じ型や例外へ畳まない。
想定内の失敗の型は [concerns/effect](../../concerns/effect/typed-requirements-failures.md) の「要求と想定内失敗を型に現す」に従う。
欠陥と想定内の失敗の別は [concerns/effect](../../concerns/effect/value-origin-classification.md) の「失敗と欠陥を値の出所で判別する」に従う。
時間上限の超過と取り消しの別は [concerns/effect](../../concerns/effect/failure-defect-cancellation.md) の「失敗と欠陥と取り消しを分ける」に従う。
