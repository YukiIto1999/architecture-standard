# generated 層

generated 層は、canonical と binding(http・protocol)から生成した出力を定める層である。
generated は、canonical の契約を code から使うときに置く。
generated は [layout](./layout.md) の依存に従う。

## 生成物

generated には、契約の公開型、検証付き構築、encoder と decoder、操作の入力と結果、提供側と利用側の接続口と通信処理を出力する。
canonical と binding の意味を一度解釈した内部モデルから各言語へ生成し、OpenAPI・JSON Schema と参照ドキュメントも同じ定義から投影する。
公開型は field、variant、値の制約と型の役割を具体的に表し、任意の map や未分類の payload に責務を委ねない。
型・構築・codec、提供側の接続、利用側の通信処理は別の package または同等の依存単位とし、型・codec だけの利用で HTTP client、接続設定、通信 runtime への依存を持ち込まない。
提供側に利用側の client を要求せず、参照ドキュメントを手で保守しない。

## 生成のみ

generated を、手で編集しない。
generated を、正本にしない。
共有の生成器の所有と取り込み、project 固有の生成入力の置き場、再現可能な生成入口は [layout](./layout.md) の「生成の toolchain」に従う。
公開型・構築・codec・操作対応に不足がある場合は、[canonical](./canonical.md) と binding と生成器の repository の該当する入力を直し、利用側の手書き同義 DTO や生成後の手修正で補わない。

## 生成能力

生成した型と encoder・decoder は、項目の必須・任意と null の許容、未指定時の意味、値の制約、判別子と variant の対応を契約どおりに扱う。
値の制約は、型が表す形式、数値の値域と精度、日時の精度と offset、文字列長の単位を含む。
契約が受理する値を、生成先の言語の既定の型や数え方で拒否も丸めもせず、契約が拒否する値を受理しない。
有限で契約上有効な値の構築、parse、既定値の適用、読取り、書出し、言語の解放と公開する trait の処理を、host の call stack や library の隠れた深さ上限に依存させない。
再帰的な契約を有限の値として扱える表現と走査を用い、実装都合の深さ上限を canonical の制約へ追加して受理値を狭めない。
型・構築・codec は同期の純粋な処理とし、HTTP の資源方針、取消、時計、quota の service や新しい運用失敗の代数を持ち込まない。
入力 byte 数や出力量の予算は host が入出力境界で所有する運用方針であり、契約値の妥当性の判定とは分ける。
JSON の数値は、実装が値域と精度を制限でき、整数の正確な一致を実装間で期待できる範囲は ±(2^53-1) である([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259#section-6))ので、binary64 を既定の数値型にする生成先は、その範囲を越える整数や binary64 で表せない十進数を、そのままでは保てない。
`date-time` は小数秒の桁数に上限がなく、offset を `Z` か `±hh:mm` で持つ([RFC 3339](https://www.rfc-editor.org/rfc/rfc3339#section-5.6))ので、契約が受理する日時を、生成先の既定の日時型が持てる精度や offset へ丸めず、拒否もしない。
JSON Schema の `minLength` と `maxLength` は、UTF-16 の code unit や UTF-8 の byte でなく、Unicode の文字(code point)の数を数える([JSON Schema Validation](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.3.1))ので、長さは契約が数える単位で数える。
`format` は、JSON Schema では既定で検証されず([JSON Schema Validation](https://json-schema.org/draft/2020-12/json-schema-validation#section-7.2.1))、OpenAPI 3.0 では認識しない format を型だけへ戻してよい([OpenAPI Specification 3.0.3](https://spec.openapis.org/oas/v3.0.3.html#data-types))ので、出力 schema に `format` を書いたことだけを、decoder が形式を強制する保証にしない。
未知の項目の扱いは [canonical](./canonical.md) の「進化」に従い、受容と検知を実現する言語別の機構は [languages](../../languages/) が定める。
未知の項目を検知する生成処理は、全 variant と入れ子の object を対象にし、既知の項目の検証や variant の識別を省略しない。
生成器は宣言した役割の違いを型の非互換として表し、alias は同じ型への参照とする。
通常の field 制約を理由に一律の wrapper を作らず、値の保持に必要な表現と型の役割を分ける。
生成能力の検証は [tests の契約の方法](../tests/methods-contracts.md) に従い、満たさない生成物を検証入口で拒否する。

## 構築と復元

local な構築と wire からの復元は同じ契約の規則を使い、受理した値と診断、または位置と破った規則を持つ違反情報を型付きで返す。
違反時に部分的に有効化した値を返さず、通常の入力違反を例外の捕捉に依存させない。
構造を読み取れる入力では、既知項目の違反があっても未知キーの走査を続け、拒否時にも既知の違反と未知項目の診断をともに返す。
構文や wire profile の違反で読取りを続けられない場合も、既に検出した違反と未知項目の診断を捨てない。
違反情報を想定内の失敗と欠陥のどちらへ運ぶかは、値の出所を知る境界が [concerns/effect](../../concerns/effect/value-origin-classification.md) の「失敗と欠陥を値の出所で判別する」に従って決める。
encode は受理済みの値を契約の表現へ写し、内部の不整合を新たな外部入力の拒否として隠さない。
raw DTO と検証済み DTO の同義の二重構造を公開せず、parser の中間表現と未検証の完成処理は codec の内部に閉じる。
構築と復元で完成処理を共有し、検証・構築済みの graph を公開 constructor に戻して再検証しない。
未知の object 項目は既知の項目を検証した上で受容し、その位置とキーを値とは別の診断に残す。
未知項目の値を保持して業務入力や再 encode へ渡さず、未知項目の受容を未知 variant の受理へ広げない。
受理後は呼出側が持つ可変 alias から制約を壊せない所有方法を採り、不変な子の不要な複製を避ける。
local graph の循環は現在の祖先経路への参照で検出して拒否し、複数箇所で共有する不変な子を循環とみなさない。
共有された子の identity を保ちながら、出力は各出現位置の値を省略せずに表す。DAG の共有を理由に値を暗黙に重複排除しない。
言語の既定値や型の消去による迂回を静的保証だけで排除できるとは扱わず、未検証の入力は構築または codec を通す。
生成した公開入口は不正な既定値を送信前に拒否し、静的な役割の区別を入力の出所の証明に使わない。
言語別の表現と検査は [languages](../../languages/) が定める。

## 生成時の診断

生成前に、空の値域、不正な既定値、重複する判別子、必要な binding の欠落、結果を一意に復元できない対応を拒否する。
未解釈の制約・encoding・注釈を黙って無視せず、生成先が必要な意味を保てない場合も拒否する。
encoding は profile に登録した意味と対象型との組として解釈し、未対応の組を既定の文字列表現へ戻さない。
pattern は profile の安全な共通部分集合への適合を既定値の検証より先に検査し、未対応の構文や意味を engine が無視する形で通さない。
契約の文字列を source の literal やドキュメントコメントへ出力するときは、その文脈に合わせて引用符、改行、制御文字と区切り文字を escape し、生成 source へ構文を注入させない。
source 上の escape と契約値の正規化を混同せず、復元される文字列の意味を変えない。
説明専用の注釈はその意味を登録して区別し、未知の注釈を説明専用と推測しない。
診断は元の宣言位置、操作・型・field、対象出力、保持できない意味と理由を指す。
任意の predicate を実行する拡張で、契約の意味の解釈や必要な生成先の実現を代用しない。
必須の生成先が一つでも失敗したら、部分生成物を成功した更新として公開しない。
未対応を拒否できることは安全条件であり、必要な契約を生成できない実装を完成としない。
参照・探索用の投影が意味を省く場合は、その用途と欠落を明示する。
その投影を完全な契約として検証や再生成の入力に使う場合は、意味の欠落を拒否する。
同じ定義、profile、toolchain、設定から、時刻・絶対パス・列挙順に依存しない同じ成果物を生成する。


## drift の検査

生成物と、生成元の canonical・binding(http・protocol)との drift を、リポジトリの検証入口で検査する。
drift があるときは、ビルドを失敗させる。

## 利用

公開契約を code で扱う提供側と利用側は、その契約から生成したデータ型を使う。
core の業務操作へ接続する提供側と host は、公開契約の入出力に generated の型を使い、[adapters](./adapters.md) で独立した application の公開 Interface へ接続する。
host が所有する技術操作も同じ正本から生成したデータ型と codec を両端で使い、core 向けの adapter を経由させず host の公開 Interface へ接続する。
HTTP または protocol の提供側に、利用側の通信 client を要求しない。
通信する利用側は、その通信を所有する adapter に generated の client または stub を置き、接続設定と transport の instance を引数で与え、generated 内に固定しない。
viewer と extension は型・構築・codec を利用し、通信の実装は host から port として受け取る。
root をまたぐ依存の許可は [skeleton](../skeleton.md) に従い、core は composition を含め generated の型にも client・stub にも依存しない。

## 操作の両端

提供側には、要求の decode、未指定の入力への既定値の適用、公開操作への dispatch、返された結果の encode を生成する。
同じ言語の直接呼出しも、既定値を適用する生成済みの受理処理を通して handler へ接続する。
生成する handler の Interface は公開契約側の接続口であり、application に実装させず、[adapters](./adapters.md) が実現する。
host の技術操作は、その host の実装を同じ接続口へ結ぶ。
利用側は、操作の入力から要求を組み立て、応答を対応する成功または拒否の結果として返す。
操作が宣言する結果の型と通信上の識別情報を対応付け、body の union と無関係な status の組を公開しない。
通常の呼出しでは本文の読取りと検証を終えてから結果を返し、accessor を読むまで不正が分からない結果にしない。
本文の不在、JSON null、空の object、空の binary を区別し、binary を text へ変換しない。
stream を公開する場合は開始と読み取り完了を分け、値の寿命、所有権、途中の失敗と取消を Interface に表す。
host の出力予算の超過や encode・送信の失敗は、既に確定した業務操作の rollback を意味しない。確定結果と出力の不成立を区別して境界へ伝える。
効果の要求、失敗と取消の表現は [concerns/effect](../../concerns/effect/README.md) に従い、実現は各 [languages](../../languages/) の effect が定める。


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
分類は生成した通信処理が所有し、契約が宣言した応答の集合との照合で決める。
status、media type と宣言した識別情報を先に照合し、選んだ結果の body を対応する codec で検証する。
payload の構造を順に試すことや、status の範囲、通信ライブラリの例外の型だけで結果を選ばない。
宣言した成功を例外から戻す処理や、未検証の body を decode する処理を利用側へ要求しない。
宣言した拒否は operation の想定内の失敗の型へ写し、他の種類と同じ型や例外へ畳まない。
想定内の失敗の型は [concerns/effect](../../concerns/effect/typed-requirements-failures.md) の「要求と想定内失敗を型に現す」に従う。
欠陥と想定内の失敗の別は [concerns/effect](../../concerns/effect/value-origin-classification.md) の「失敗と欠陥を値の出所で判別する」に従う。
時間上限の超過と取り消しの別は [concerns/effect](../../concerns/effect/failure-defect-cancellation.md) の「失敗と欠陥と取り消しを分ける」に従う。
