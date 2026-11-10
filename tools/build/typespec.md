# TypeSpec

用途は、公開契約の意味を記述し、各言語の型・構築・codec・操作と通信接続を build 時に生成する道具である。
採用は、TypeSpec である。
契約 profile と生成処理の source は [structure/contracts](../../structure/contracts/layout.md) が定める toolchain に置き、repository の revision と依存 lock で compiler・profile・emitter・設定の組を固定する。
OpenAPI と JSON Schema は同じ契約からの投影として `@typespec/openapi3` と `@typespec/json-schema` で出力し、実行用の型や codec の必須入力にはしない。
判断基準は、compiler が解決した operation・scalar・union・field・注釈と宣言位置を、投影による情報の欠落より前に読み取り、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成能力へ一度だけ解釈できることである。
TypeSpec の [emitter の入口と意味走査](https://typespec.io/docs/extending-typespec/emitters-basics/#emitting-typespec-types-to-assets-on-disk)と [Program の意味 graph・診断・emitter 接続](https://github.com/microsoft/typespec/blob/34435f46bf441cd10047c6f604cf977c4b041e16/packages/compiler/src/core/program.ts)を使い、parser と名前解決を作り直さず、追加する意味と各言語への保存を profile と emitter が所有する。
この採用は生成経路の指定であり、TypeSpec の既定 emitter や代表契約の試行が実行時の全保証を満たすという判定ではない。
撤回条件は、判断基準を満たさなくなることであり、compiler API の変更、意味の保存または決定的生成の不成立、profile または emitter の保守停止、同じ保証を満たす生成機構の成立を再評価のトリガーとする。

## 契約の意味を一度解釈して直接生成する

### 要求
TypeSpec compiler の意味情報と契約 profile から IR を作り、各言語 emitter は IR の解釈済みの意味を出力先の機構へ写せ。
profile は、別の役割を持つ型の identity、同じ型への alias、scalar の受理値域・同値性・保持する精度や表記、通常の field 制約を区別せよ。
項目の必須性・null 許容・未指定時の既定値、判別子と variant の対応、通信非依存の operation の入力と成功・拒否の各結果を解釈せよ。
binding は operation の意味と分け、公開を要求する通信方式ごとに全結果の識別・media type・body の有無・encoding の対応を検査せよ。
型、検証付き構築、codec、operation 入力と outcome、提供側 handler・dispatch の Interface、利用側 transport を同じ IR から生成せよ。
説明専用と登録した注釈以外は、意味を解釈するか、生成を失敗させよ。
未対応の注釈・encoding・型、空の値域、制約に違反する既定値、binding の欠落・曖昧さ、出力先で保存できない意味を、成果物の公開前に拒否せよ。
診断に元の宣言位置、該当する操作・型・field、対象出力、保存できない意味と理由を含めよ。
必須の生成先が一つでも失敗したら、部分出力を成功した更新として公開するな。

### 根拠
投影前の意味を一度解釈すれば、各言語の型生成と検証生成で契約を読み直さず、役割や存在状態を同じ入力から保存できる。
TypeSpec の [encoding の扱い](https://typespec.io/docs/extending-typespec/emitters-basics/#dealing-with-encodings)にある未知 encoding の decay は、必要な意味を失う場合があるため、この profile では採らない。
未対応を拒否することは意味を弱めない安全条件であり、必要な契約を実現した証拠ではない。

### 完了条件
各言語の実行用生成物が、投影 schema でなく同じ解釈済み IR から導かれている。
profile が役割・alias・値域・保存表現・存在状態・variant・operation・binding の意味を判定可能に定めている。
未解釈の宣言、不完全または曖昧な binding、出力先の能力不足が、元の位置を持つ生成失敗になり、成功成果物が公開されない。
必要な全契約が選択した production target で生成され、[tests の方法](../../structure/tests/methods.md)が定める生成能力の検査へ接続されている。

### 禁止事項
各 emitter や consumer が投影 schema から制約を再解釈し、同じ契約の検証を別に定義すること。
未知の注釈を説明専用と推測し、無視または弱い型への置き換えで生成を成功させること。
生成先の標準型や試行の対応範囲に合わせ、契約の受理値域・精度・offset・存在状態を狭めること。
生成した handler の Interface を application に実装させ、core に生成物を参照させること。

### 行動
profile の意味と構成子、各出力先への写像、投影で失う情報を対応付ける。
compiler 更新時は意味抽出と位置付き診断を照合し、必要な契約を全出力先で生成できることを確かめる。
不足は profile・IR・emitter の該当する所有者で直し、生成後の手修正や同義 DTO で補わない。

## 生成を再現できる build 入力に閉じる

### 要求
生成を製品の実行時と型検査の依存から独立した build-time toolchain で実行せよ。
定義、binding、profile、生成処理、依存 lock、設定、出力整形を入力として固定し、時刻・絶対パス・列挙順で成果物が変わらないようにせよ。
生成物を追跡し、再生成との差分を repository の検証入口の失敗にせよ。
純粋な型・構築・codec の依存単位を、通信 client・dispatch の実行機構から分けよ。

### 根拠
生成処理と入力を固定すれば、手元の tool と実行時の既定動作に依存せず同じ契約を再現できる。
生成用の依存を分離すれば、compiler の要求する版と通信 runtime が、型や codec だけを使う製品へ流入しない。

### 完了条件
同じ入力と固定した toolchain が、異なる一時パスでも同じ成果物を出し、差分が検証入口で拒否される。
型・構築・codec だけの利用に通信 runtime が不要で、生成器自体も製品の依存 closure に入っていない。

### 禁止事項
再生成できない出力を公開すること。
生成器の都合で製品の言語版または通信 runtime の依存を増やすこと。

### 行動
独立した生成入口で全出力を作り、決定的生成・drift・依存分離の検査を検証入口へ接続する。
言語別の型・所有権・効果への接続は各 ecosystem の translation と inspection に従う。
