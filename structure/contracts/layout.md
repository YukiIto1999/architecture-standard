# contracts の構造

contracts のフォルダ構成と、公開契約の定義、媒体への対応、生成処理、生成物、application への adapter の責務と依存を定める。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
各層の内部は、[canonical](./canonical.md)・[http](./http.md)・[protocol](./protocol.md)・[generated](./generated.md)・[adapters](./adapters.md) が定める。

## フォルダ構成

```
contracts/
├─ canonical/    公開操作と値の意味。型・結果・制約。
├─ http/         HTTP の wire への binding。
├─ protocol/     ローカルの非 HTTP protocol への binding。
├─ toolchain/    契約 profile の解釈・内部モデル・各出力の生成を持つ build-only package。
├─ generated/    型・構築・codec・操作の両端と参照用 schema の出力。
└─ adapters/     公開契約と core の公開 application 入口の接続。
```

`canonical` は常に置く。
`http` と `protocol` は、canonical を外部との受渡し形式へ束ねる binding であり、プロセスまたは言語の ABI をまたぐ通信があるときに、その通信形式に応じて置く。
`http` は HTTP の通信に、`protocol` は webview と host の IPC や native library の ABI を含む埋め込み surface との非 HTTP のローカル通信に置く。
`generated` は、canonical の契約を code から使うすべての場合に置く。
`adapters` は、公開契約を core の公開 application 入口へ接続するときに置く。
`toolchain` は、記述言語と契約 profile の意味を解釈する実装を所有し、個別の公開契約の定義は持たない。
公開契約を code から扱う値と操作の Interface は generated を使い、同じ意味の field、variant、制約を手書きで写した型を代わりに置かない。
生成物の不足は canonical、binding、生成器の責務に応じて直し、利用側に契約の第二の正本を作らない。
型・構築・codec と、binding ごとの利用側 client・提供側 dispatch を同じ意味の解釈から生成する。
OpenAPI と JSON Schema は参照・交換用の投影であり、言語別の生成をその投影だけへ依存させない。
通信を持たない契約も同じ経路で型・構築・codec を生成し、通信処理だけを省く。
生成する依存単位と Interface は [generated](./generated.md) に従う。

## 生成の toolchain

独立した生成用 package と、契約 profile、生成器設定、emitter、必要な script は、`toolchain/<stage>/` に置く。
profile は型の役割、値の制約と保持情報、操作と binding の意味と合成規則を定め、frontend が記述言語の解決済みの意味を内部モデルへ写す。
内部モデルは生成器が所有し、手書きの契約定義や利用側の公開 API にしない。
各 emitter は同じ内部モデルを使い、制約や操作の意味を言語ごとに再解釈しない。
生成対象の言語と、公開する操作・binding の組を入力で明示し、存在する binding の一覧から必要な対応を逆算しない。
実行用 package の manifest と、依存を固定する lock または toolchain の参照を追跡し、profile と project 固有の生成入力を task の入力へ含める。
root の task graph の contracts 生成 task を利用入口とし、各 stage の command、入力、出力、生成の依存を task graph から辿れるようにする。
CLI を一度呼ぶだけの処理は task 定義から直接実行し、変換の実装を持つ script は対応する stage の package に置き、別の生成手順を並置しない。
前段の出力を使う stage は、前段の生成または入力に対応する有効な cache を task graph の依存で保証し、古い追跡済み出力を黙って使わない。
生成用 package は、製品の runtime と型検査の依存 closure から分離し、生成器が要求する言語版を製品の依存解決へ持ち込まない。
意味を追加するときは、profile の意味と合成規則、必要な全出力、独立した受入例を合わせて更新する。
未対応の宣言と不完全な binding の扱いは [generated](./generated.md) の「生成時の診断」に従う。

### JSON の相互運用 profile

JSON を使う binding と codec は、全生成先で同じ閉じた wire profile を使う。
基礎仕様は [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) とし、次の条件は実装間の解釈差を避けるためにこの profile が選ぶ受入規則である。
RFC の grammar 自体が重複名や BOM を一律に禁止しているとは扱わない。

- object の全項目名を escape の復元後に比較し、同じ名前の重複を拒否する。値が同じ場合、異なる場合、未知項目とその subtree も対象にし、先勝ち・後勝ちにしない。
- text と byte の両入口で文書先頭の BOM を拒否する。文字列値や項目名の内側にある U+FEFF はそのまま保持する。
- byte は不正な UTF-8 を、text と JSON escape は孤立した UTF-16 surrogate を拒否し、置換文字で補修しない。
- 有効な Unicode scalar value を非文字であることだけでは除外せず、正規化で別の文字列に変えない。数値の値域と精度もこの profile のために狭めず、canonical が定める意味を保持する。

重複名の相互運用上の問題は [RFC 8259 §4](https://www.rfc-editor.org/rfc/rfc8259#section-4)、UTF-8 と BOM は [§8.1](https://www.rfc-editor.org/rfc/rfc8259#section-8.1)、不対 surrogate の相互運用上の問題は [§8.2](https://www.rfc-editor.org/rfc/rfc8259#section-8.2) を参照する。
I-JSON の数値範囲や非文字の制限を暗黙に追加しない。

### pattern の共通部分集合

profile は pattern の構文と照合の意味を、全生成先で安全に実現できる共通部分集合として明示する。
部分一致と全体一致、文字と長さの単位、anchor と改行の扱いを一意に定める。
生成時と実行時のどちらでも破局的な backtracking に依存せず、profile 外の構文や engine が対応しない機能は、意味を落として通すのでなく生成時に拒否する。
対象言語の engine はこの意味を実現する手段として選び、一言語向けの engine を全言語に要求しない。
宣言を安全に拒否することと、必要な全生成先で pattern を実装できることの区別は [generated](./generated.md) の「生成時の診断」に従う。

## 層

| 層 | 役割 | 変更理由 |
|---|---|---|
| canonical | 公開契約の意味の正本 | 公開する操作・型・エラー・制約の変化 |
| http | 意味を HTTP の wire へ束ねる binding | HTTP の wire 形式の変化 |
| protocol | 意味を非 HTTP のローカル protocol へ束ねる binding | ローカル protocol の形式の変化 |
| generated | 型・構築・codec・操作の両端の Interface と通信処理・参照用 schema | canonical と binding からの再生成 |
| adapters | 公開契約と独立した application 入出力を写像し、公開入口へ接続する | 外部で交わす意味と業務の保証の対応の変化 |

## 依存方向

依存の向きは [concerns/dependency](../../concerns/dependency/README.md) に従う。

| 種類 | 参照元 | 参照可 |
|---|---|---|
| 定義 | canonical | 契約記述言語と profile の宣言 |
| 定義 | http・protocol | canonical、各 binding の宣言 |
| 生成入力 | toolchain | canonical、binding、生成対象の設定 |
| 生成元 | generated | canonical と binding を解釈した内部モデル |
| 実行時 | adapters | generated の型と提供側 Interface、core の公開 API、libs の公開 API |

contracts の外との参照の規則は [skeleton](../skeleton.md) に従う。

## 正本

canonical だけが、契約の意味の正本である。
http と protocol は媒体への対応を所有し、canonical の意味を再定義しない。
generated と生成器の内部モデルは、それらの定義から再構築できる導出物であり、第二の正本にしない。

## 利用側の型との区別

canonical と binding は公開契約を指定する定義であり、core の業務モデルではない。
generated の型は、公開契約の具体的な field、variant、制約と操作の結果を表す。
契約を表せない汎用の map や任意の payload を、その代わりにしない。
runtime の未完成入力、core の業務状態、surface の表示状態は、それぞれの責務と保証で型を定める。
generated の型を使える範囲は root の依存方向に従い、型の形が一致することを core からの依存の理由にしない。
公開契約とコンテキストの application 入出力との写像は [adapters](./adapters.md) が所有する。
