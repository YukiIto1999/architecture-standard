# inspection

## 概要
inspection は、TypeScript で検証を扱う実現軸である。
principles の [verification](../../principles/verification/README.md) が定める検証の機械化を、TypeScript の機構で満たす。

## 構造

### 要求
依存方向と境界の禁止は TypeScript compiler API による AST 構造検査で検証し、規則は層の参照禁止と exports の外への到達の禁止を持つ。
構造検査は、import 宣言と export 宣言の module specifier を採用している TypeScript の解決規則で file へ解決し、解決した組を依存 edge として規則に当てる。
構造検査は、依存 edge を型だけの import と実行時の import に区別する。
root の構造検査は、skeleton の実行時表と build・test-only 表から runtime・build・test phase の許可 edge を生成する。
root の構造検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。
外部 I/O、待機、下流 Effect の非同期呼出は、TypeScript compiler API による AST 構造検査で検査する。
外部 I/O と待機の symbol は、構造検査の設定に列挙する。
Promise を返す前に同期で throw し得る境界 API の symbol と、throw し得る同期 DOM API と postMessage の symbol は、構造検査の設定で別の集合に列挙する。
前者の呼出式は `Result.wrapAsync` に渡す関数リテラルの内側だけに、後者の呼出式は `Result.wrap` に渡す関数リテラルの内側だけに許す。
`Result.wrap` と `Result.wrapAsync` に `unknown` 以外の error の型引数を与える形、および結果に `mapErr` を繋がない形は拒否する。
下流 Effect は、callee expression の型が Effect の nominal brand を持つか、branded Effect へ代入可能かで識別する。
外部 I/O、待機、下流 Effect は、`withDeadlineEffect` の operation からだけ呼ぶ。
`withDeadlineEffect` は host ごとの `ResumeSource` capability を受け、`window` と `document` を直接参照しない。
全ての公開 Effect factory は、TypeScript compiler API による AST 構造検査で検査する。
Effect の callable な型は `unique symbol` の nominal brand を持ち、`deferEffect` だけが branded value を構築する形を許す。
公開 Effect factory の parameter は、default parameter と destructuring の binding initializer を持たない形だけを許す。
公開 Effect factory の本体は、実行用の関数リテラルを `deferEffect` へ渡す形だけを許す。

### 根拠
[verification](../../principles/verification/README.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、TypeScript compiler API の AST 構造検査で応える。
compiler API は採用している TypeScript と同じ解決規則で module specifier を file へ解決するため、別名や再輸出や package の公開面を経た参照も同じ依存 edge として現れる。
同じ構文木から型だけの import かどうかを取れるため、依存方向の規則と生成型を型に留める規則を一つの構造検査で扱える。
層の参照禁止と exports の外への到達の禁止を規則にすれば、層の越境と公開面の迂回が違反として出る。
規則を検証入口で回せば、違反でビルドが止まる。
import を介さない呼び出し(グローバル API 等)は、import の走査に現れない。
その禁止は、oxlint の no-restricted-properties などの banned API の lint に割り当てる。
TypeScript compiler API は、export され、戻り値が Effect に代入可能な function と変数を全て列挙し、本体の call expression と引数を取得できる。
TypeScript compiler API は `unique symbol` の参照と type assertion を取得できるため、型宣言を除く brand の値参照と Effect への assertion を `deferEffect` の実装内へ限定できる。
TypeScript compiler API は call expression の symbol と callee expression の型を解決できる。
Promise を返す境界と同期 DOM と postMessage の symbol を別々に列挙すれば、各呼出式を同期と非同期に対応する `Result.wrap` と `Result.wrapAsync` の関数リテラルへ限定できる。
`Result.wrap` と `Result.wrapAsync` の型引数と後続の `mapErr` は構文木から取得できるため、error の型を偽る形と変換を欠く形を拒否できる。
callee expression の型に Effect の `unique symbol` brand があるか、branded Effect へ代入可能かを調べれば、呼出結果が AsyncResult でも下流 Effect の呼出を識別できる。
設定に列挙した外部 I/O と待機、および callee expression で識別した下流 Effect の呼出を、`withDeadlineEffect` の operation 内に限定できる。
TypeScript compiler API は wrapper 内の global symbol を解決できるため、`withDeadlineEffect` から `window` と `document` の直接参照を拒否できる。
TypeScript compiler API は parameter の initializer と destructuring の binding element を取得できるため、factory 本体へ入る前の副作用経路を検出できる。
公開 Effect factory の本体を `deferEffect` の直接呼出だけにし、その引数を関数リテラルだけにすれば、factory の評価中に副作用を起動する式を構造で排除できる。
`deferEffect` 自体の実行テストは constructor の遅延を確認するが、全ての公開 factory の形は確認しない。

### 完了条件
依存方向と境界の禁止が、TypeScript compiler API による AST 構造検査で検証されている。
依存 edge が、解決した file の組として得られ、型だけの import と実行時の import に区別されている。
規則が、層の参照禁止と exports の外への到達の禁止を持っている。
root の構造検査が、skeleton の両表から phase ごとの許可 edge を生成している。
build または test の edge が runtime の成果物へ混入した場合に、構造検査が失敗している。
外部 I/O、待機、下流 Effect が、`withDeadlineEffect` の operation からだけ呼ばれている。
Promise を返す前に同期で throw し得る境界 API が、`Result.wrapAsync` に渡す関数リテラルの内側からだけ呼ばれている。
throw し得る同期 DOM API と postMessage が、`Result.wrap` に渡す関数リテラルの内側からだけ呼ばれている。
`Result.wrap` と `Result.wrapAsync` の error の型引数が `unknown` であり、結果に `mapErr` が繋がっている。
`withDeadlineEffect` が host ごとの `ResumeSource` を受け、`window` と `document` を直接参照していない。
外部 I/O と待機の symbol が、構造検査の設定に列挙されている。
下流 Effect の呼出が、callee expression の nominal brand と branded Effect への代入可能性で識別されている。
Effect の callable な型が `unique symbol` の nominal brand を持ち、`deferEffect` だけが branded value を構築している。
全ての公開 Effect factory が、実行用の関数リテラルを `deferEffect` へ渡す形になっている。
全ての公開 Effect factory の parameter に、default parameter と destructuring の binding initializer が無い。
公開 Effect factory の本体に、`deferEffect` への委譲より前の副作用呼出が無い。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。
外部 I/O、待機、下流 Effect を、`withDeadlineEffect` の operation の外から直接呼ぶこと。
Promise を返す前に同期で throw し得る境界 API を、`Result.wrapAsync` の関数リテラルの外から呼ぶこと。
throw し得る同期 DOM API または postMessage を、`Result.wrap` の関数リテラルの外から呼ぶこと。
`Result.wrap` または `Result.wrapAsync` に `unknown` 以外の error の型引数を与えること。
`withDeadlineEffect` から `window` または `document` を直接参照すること。
`deferEffect` の外で、Effect の brand を構築または型変換で偽装すること。
公開 Effect factory を一部だけ抽出して、遅延を全件保証したとみなすこと。
公開 Effect factory の default parameter または destructuring の binding initializer を、検査対象から外すこと。
`deferEffect` の実行テストだけで、全ての公開 Effect factory の遅延を保証したとみなすこと。

### 行動
TypeScript compiler API で解決した依存 edge に層の参照禁止と exports の外への到達の禁止を規則として当て、検証入口で回す。
skeleton の両表を TypeScript compiler API で読み、runtime・build・test phase の許可 edge を生成して、同じ構造検査が列挙した依存 graph と照合する。
runtime の成果物を構成する依存 closure に build または test の edge があれば失敗させる。
TypeScript compiler API で外部 I/O、待機、下流 Effect の call expression を列挙し、`withDeadlineEffect` の operation 内にあることを検証入口で検査する。
Promise を返す前に同期で throw し得る境界 API と、throw し得る同期 DOM API と postMessage の symbol を別々に設定へ列挙する。
前者が `Result.wrapAsync` に渡す関数リテラルの内側に、後者が `Result.wrap` に渡す関数リテラルの内側にあることを検証入口で検査する。
`Result.wrap` と `Result.wrapAsync` の error の型引数が `unknown` であり、結果に `mapErr` が繋がっていることを検証入口で検査する。
TypeScript compiler API で `withDeadlineEffect` の global symbol 参照を列挙し、`window` と `document` の直接参照を検証入口で拒否する。
外部 I/O と待機は、設定に列挙した symbol で識別する。
下流 Effect は、callee expression の型に nominal brand があるか、branded Effect へ代入可能かで識別する。
TypeScript compiler API で export され、戻り値が Effect に代入可能な function と変数を全て列挙する。
型宣言を除く Effect の `unique symbol` brand の値参照と Effect への type assertion が、`deferEffect` の実装内だけにあることを検証入口で検査する。
公開 Effect factory の parameter に、default parameter と destructuring の binding initializer が無いことを検証入口で検査する。
factory 本体が `deferEffect` を直接呼び、実行用の関数リテラルだけを渡す形であることを検証入口で検査する。

### 例
層の参照禁止は、解決した edge に当てる実行可能な規則として設定する。

```typescript
{ name: "no-domain-to-infra", severity: "error",
  from: /^src\/domain\//, to: /^src\/infrastructure\// }
```

## 予防

### 要求
tsconfig は strict を有効にし、型検査と lint の警告を検証入口でエラーとして扱う。
tsc は型検査の専用に使い、JS への変換は build 基盤に委ねる。
tsconfig は strict に加え、noUncheckedIndexedAccess と exactOptionalPropertyTypes も有効にする。
linter は oxlint を使い、型認識の検査は tsgolint による oxlint の type-aware 実行で行う。
ファイル・関数の大きさとネストの深さのしきい値は oxlint の max-lines(ファイル)・max-lines-per-function(関数)・max-depth(ネスト)の規則として定め、既定値から緩める変更は project の決定の記録に明記する。
環境変数の直読は、TypeScript compiler API による構造検査で process.env と import.meta.env の参照を設定の parse を持つ組立点だけに限る。
認知的複雑さの測り方は、[sonarqube](../../tools/platforms/sonarqube.md) の「cognitive complexity を一箇所で測る」に従い、oxlint 側の複雑度の規則(complexity)は有効にしない。

### 根拠
strict を有効にすれば、不在や暗黙の any が型検査で止まる。
noUncheckedIndexedAccess は配列・索引アクセスの結果に `undefined` を型で強制し、exactOptionalPropertyTypes は省略可能なプロパティへの明示的な `undefined` 代入を区別するので、formation が定める不在の union と厳密な型検査の規律を tsconfig が機械で支える。
型検査と lint の警告をエラーにすれば、規則の違反がビルドで止まる。
oxlint は、tsgolint の type-aware 実行により floating promise や unsafe な型変換を検出できる。
max-lines・max-lines-per-function・max-depth は、ファイル・関数の大きさとネストの深さを早く気づかせる。
oxlint の complexity 規則が測る cyclomatic complexity は cognitive complexity と別の性質であり、重複検証ではない。標準が必須の検証へ割り当てる複雑度は cognitive complexity であり、cyclomatic complexity は必須の検証へ割り当てていないため、oxlint の complexity 規則は有効にしない。
採用済みの oxlint に環境変数の直読を禁止する native の規則がないため、compiler API の構造検査で補い、[single-config-source](../../concerns/configuration/single-config-source.md) の「定めた源からまとめて読む」を機械の gate にする。
既定から緩める判断を決定の記録に残せば、緩和の理由が追える。
tsc の emit は build 基盤の変換と重複し、二重の変換経路を生む。

### 完了条件
tsconfig の strict が、有効になっている。
tsconfig の noUncheckedIndexedAccess と exactOptionalPropertyTypes が、strict と併記して有効になっている。
型検査と lint の警告が、検証入口でエラーとして扱われている。
oxlint が linter として使われ、型認識の検査が tsgolint で行われている。
ファイル・関数の大きさとネストの深さのしきい値が、max-lines・max-lines-per-function・max-depth の規則として定められている。
process.env と import.meta.env の参照が、設定の parse を持つ組立点に限られている。
緩和が、project の決定の記録に明記されている。
oxlint の complexity 規則が、有効になっていない。
tsc が型検査の専用に設定され、JS への変換が build 基盤に委ねられている。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
cognitive complexity を、oxlint の complexity 規則で測ること。
tsc を、JS への変換に使うこと。

### 行動
strict を有効にし、型検査と lint の警告を検証入口でエラーにする。
noUncheckedIndexedAccess と exactOptionalPropertyTypes を strict と併記して有効にする。
oxlint を導入し tsgolint で type-aware の検査を行い、max-lines・max-lines-per-function・max-depth のしきい値を定める。

## 型消去の cast allowlist

### 要求
TypeScript compiler API の構造検査で、reporting boundary の型消去の symbol と、検証を完結する converter または factory の型構築の symbol を、別の allowlist として照合する。
集合の外の assertion と cast、および種類の一致しない cast を拒否する。
型消去と型構築の扱いは、[concerns/types](../../concerns/types/audited-type-loss.md) の「型の情報を失う箇所を監査する」に従う。

### 根拠
型消去と型構築を同じ集合で扱うと、検証を経ない型構築が報告の型消去に紛れる。
allowlist を分けて照合すれば、どちらの種類の cast かを機械で判定できる。

### 完了条件
型消去の symbol と型構築の symbol が、別の allowlist で管理されている。
allowlist の集合外の cast と、種類の一致しない cast が、検証入口で拒否されている。
converter または factory が、検証を終えた後だけ型を構築していることが実行テストで確かめられている。

### 禁止事項
型消去と型構築を、一つの allowlist へまとめること。
allowlist に載せずに cast を書くこと。

### 行動
reporting boundary の型消去と、検証を完結する型構築の symbol を、別々の allowlist へ列挙する。
構造検査で allowlist と照合し、集合外と種類不一致を失敗させる。
converter と factory が検証後だけ型を構築することを、実行テストで確かめる。

## 規則と検証機構の対応

この言語 ecosystem の全規律を、検証手段へ写像する。
規律は軸ファイルと採用したツールのファイルに住み、ファイル列は規律が住むファイルの名前である。上位規律を ecosystem の機構で満たす規律も、軸ファイルか採用したツールのファイルに置く。
標準 repository の verifier は、ecosystem の全ファイルの規律を表す H2 見出しの集合と、この対応表の規律の集合を照合し、欠落、余分、重複があれば失敗する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。
検証手段は、型・構造検査・analyzer/lint・計測・mutation・runner 検査・artifact 検査・実行テスト・レビューの語で書き、複数の手段は + で連ねる。
レビューは、括弧に判断の対象を書く。

| ファイル | 規律 | 検証手段 |
|---|---|---|
| vitest | 実行 | 実行テスト(Vitest の単体・性質・結合を検証入口で実行し、発見件数0を失敗にする) |
| fast-check | 性質 | 実行テスト(fast-check の生成・縮小・stateful property と回帰 seed の再実行) |
| cucumber-js | 仕様 | 構造検査(feature・step binding・公開 interface operation の実体由来一覧の drift)+実行テスト(cucumber-js を実装と同じ検証入口で実行) |
| playwright-bdd | UI smoke の Gherkin を Playwright の test へ変換する | 実行テスト(playwright-bdd が変換した test を Playwright の runner で実装と同じ検証入口から実行)+レビュー(executable spec と UI の E2E smoke・visual を代替に並べていないことの判断) |
| axe-core-playwright | accessibility | 実行テスト(@axe-core/playwright による自動判定可能な違反、Playwright による keyboard 操作・pointer target の bounding box・WCAG 2.2 Level AA の text/non-text contrast と例外記録の照合)+レビュー(自動判定できない WCAG 2.2 Level AA の確認) |
| testcontainers | 実依存 | 実行テスト(testcontainers の割当 host・port を使う結合テストと終了時の破棄)+runner 検査(`vitest list --json` と Playwright `--list` が返す project・file・suite・test の組を native test ID とする size ごとの排他・全域集合一致、発見件数0の拒否、実行環境の資源制限。cucumber-js scenario は URI・line・name の組を同じ集合へ加える) |
| knip | 未使用 | analyzer/lint(knip で未使用のファイル・export・依存を検出し検証入口で失敗) |
| stryker-js | 有効性 | mutation(StrykerJS の totalUndetected または Survived+NoCoverage が0件の gate、変異生成0件の失敗、選んだテストの実行0件の失敗、既知の欠陥を仕込んだ確認での検出の成立) |
| inspection | 構造 | 構造検査(TypeScript compiler API が解決した依存 edge と skeleton の両表から runtime・build・test edge を生成し、runtime 成果物への build・test edge 混入を失敗にする) |
| typescript-compiler-api | 構造検査 | 構造検査(@typescript/typescript6 の compiler API による call expression の symbol・callee expression の型・parameter の initializer・destructuring の binding element・module specifier の解決先 file と型だけの import かどうかの取得と規則照合) |
| inspection | 予防 | analyzer/lint(tsc・oxlint・`oxlint --type-aware`・`oxlint-tsgolint`・SonarQube の設定と診断を検証入口でエラー化) |
| tsdoc | ドキュメントコメントの検査 | 構造検査(TypeScript compiler API と `@microsoft/tsdoc`)+レビュー(実効的な可視境界に応じた外部契約または内部契約、伝播する欠陥、再述でない意味、統一した語彙) |
| valibot | 業務の値を型に封じる | 型(valibot の brand・safeParse)+実行テスト(factory の単体テスト) |
| formation | 不正な状態を構築できなくする | 型(判別子つき union・never 網羅) |
| formation | 不変を既定にする | 型(readonly・as const) |
| formation | 意味と単位を型で区別する | 型(branded type) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(oxfmt チェック・oxlint の unicorn/filename-case)+構造検査(TypeScript compiler API による型・値の PascalCase・camelCase の命名照合) |
| conventions | ドキュメントコメントを書く | 構造検査(TypeScript compiler API と @microsoft/tsdoc。存在・構文・宣言と tag の対応・`@throws {@link ErrorType} 条件`・外へ伝播する直接の throw の型と link・try/catch で吸収される throw の除外・先頭行の一行と句読点)+レビュー(実効的な可視境界に応じた外部契約または内部契約、call/rejected Promise から伝播する欠陥と @throws、再述でない意味、統一した語彙) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(TypeScript compiler API による命名照合) |
| vitest | カバレッジ | 計測(Vitest coverage の v8 provider で project 記録の branch 下限を検証入口で判定) |
| valibot | unknown で受けて一度だけ parse する | 型/実行テスト(valibot の safeParse・境界の parse の単体テスト) |
| valibot | 受け取ったエラーを parse し、想定された失敗と欠陥を分ける | 実行テスト(契約宣言済み failure、契約外の status/body、problem+json parse 失敗、実装の throw の分岐) |
| http-client-js | 生成した契約を使い、drift を検査の gate にする | 実行テスト(契約からの生成、再生成の差分、判別付き直和の判別子つき union と網羅の型検査、生成 client への transport の注入、生成物の製品が採用する TypeScript での型検査、drift 検査の検証入口の判定) |
| translation | 生成型を型としてのみ使い、通信を port に通す | 構造検査(TypeScript compiler API。viewer からの生成 client の import と runtime の import の検出、生成 client の import を ui port の実装へ限定)+型(import type) |
| ts-results-es | 効果を遅延した関数で表す | 構造検査(TypeScript compiler API。Effect が unique symbol の nominal brand を持ち、deferEffect だけが branded value を構築し、全ての公開 Effect factory に parameter initializer がなく、本体が実行用の関数リテラルを deferEffect へ直接渡すこと)+実行テスト(deferEffect の構築時は副作用0件で、返した Effect の呼出後にだけ開始すること)+型(Effect の nominal brand・環境・AbortSignal・wall-clock の絶対期限・AsyncResult のシグネチャ) |
| ts-results-es | 想定内失敗を Result で返す | 型(ts-results-es の Result・判別子つき union) |
| ts-results-es | 非同期 API の送出を AsyncResult へ変換する | 構造検査(TypeScript compiler API。設定した Promise を返す境界 API の呼出しを `Result.wrapAsync` の関数リテラル内へ限定し、error の型引数が `unknown` であることと結果に `mapErr` が繋がることを照合)+実行テスト(関数呼出時の同期 throw と返した Promise の rejection を同じ mapper が Err にし、欠陥と AbortError は元の error のまま rejection になること) |
| ts-results-es | 同期 API の送出を Result へ変換する | 構造検査(TypeScript compiler API。設定した同期 DOM API と postMessage の呼出しを `Result.wrap` の関数リテラル内へ限定し、error の型引数が `unknown` であることと結果に `mapErr` が繋がることを照合)+実行テスト(同期の戻り値と throw、想定外の欠陥の再送出) |
| connection | 依存を環境で受け、host の能力を port で宣言する | 型(環境の型・ui port の型)+レビュー(singleton を作らないことの判断) |
| inspection | 型消去の cast allowlist | 構造検査(TypeScript compiler API。reporting boundary の型消去 symbol と検証を完結する converter または factory の型構築 symbol を別の allowlist として照合し、集合外と種類不一致の assertion/cast を拒否)+実行テスト(converter または factory が検証後だけ型を構築) |
| solidjs | 状態の機構 | レビュー(structure の分類に対応する remote/URL/横断/一時 の機構の選択) |
| solidjs | remote の規律 | レビュー(local の横断 store への複製禁止の判断) |
| publication | 保存の禁止 | analyzer/lint(oxlint の no-restricted-properties で localStorage・sessionStorage の直呼びを禁止) |
| vscode | extension の保持状態 | 型(state port・secret port)+レビュー(保持する状態の範囲と secret の扱いの判断) |
| coordination | 非同期 | 構造検査(TypeScript compiler API。公開非同期 API の戻り型と、domain の関数に非同期が現れないことの照合)+レビュー(domain の純粋性の判断) |
| coordination | 取り消し | 型(Effect 専用 withDeadlineEffect が AsyncResult<T, E &#124; DeadlineExceeded> を返すこと)+構造検査(TypeScript compiler API。設定に列挙した外部 I/O と待機の symbol と、callee expression の nominal brand または branded Effect への代入可能性で識別した下流 Effect を withDeadlineEffect の operation からだけ呼び、wrapper 内の window と document の直接参照を拒否すること)+実行テスト(host ごとの ResumeSource、wall-clock の絶対期限の伝播、非同期境界の前後と再開時の期限確認、購読解除後の判定、解決済み Err の保持と overrun 診断、期限 reason と同一または cause chain に持つ rejection の DeadlineExceeded Err 変換、wrapper 開始前から親取消と期限超過が同時に成立した場合に AbortSignal.any が選んだ親 reason の保持、別 defect の保持と期限超過診断、Ok 後の期限超過を DeadlineExceeded Err にすること、AbortSignal.timeout が active time の局所補助であること、親 signal と期限用 controller の AbortSignal.any 合成) |
| coordination | 並行の組 | 構造検査(TypeScript compiler API。Promise.all または Promise.allSettled に渡す並行 task collection を生成する箇所では、branded Effect を開始する withDeadlineEffect の呼出しを、project の決定の記録で固定した単一 limiter の需要枠 callback 内へ限定)+実行テスト(最初の Err と最初の rejection の各経路で abort、controller 由来の sibling cancellation rejection の除外、allSettled で全兄弟へ合流、rejection defect が無い場合は最初に観測した Err を Result で返すこと、Err と独立した rejection が同時に成立した場合は drain 後に rejection defect を優先して送出すること、実行中の Effect が決定の記録の上限を越えない最大同時実行数) |
| coordination | メインスレッドを塞がない | レビュー(重い同期計算の特定と退避の判断) |
| coordination | 後始末 | レビュー(onCleanup 登録漏れの判断) |
| solidjs | viewer | レビュー(props の分割代入の禁止) |
| opentelemetry-js | viewer の telemetry | 型(ui port の型)+レビュー(SDK の adapter への隔離の判断) |
| tailwind | styling | 構造検査(design token の定義が `@theme` に限られることの照合)+レビュー(token の粒度と命名の判断) |
| vite | viewer を載せる host の entry と build | レビュー(tsconfig の `jsx` が `preserve`、`jsxImportSource` が `@solidjs/web`、composition の ui port 注入と @solidjs/web の render による mount) |
| publication | extension | 型(port の interface) |
| vscode | ide の host | 型(判別子つき union の schema・safeParse)+実行テスト(postMessage 受信の単体テスト) |
| vscode-jsonrpc | core への接続 | 型(RequestType・NotificationType の型宣言) |
| publication | 可視性 | 構造検査(package.json の exports フィールドの検査と、exports に無い path への import の拒否) |
| oxlint | 汎用名と裸ループと自由文出力を lint で止める | analyzer/lint(id-denylist・typescript/prefer-for-of・no-console をエラー化) |
| playwright | 表示までの時間を E2E で測る | 実行テスト(Playwright の E2E で入力時刻・状態または feedback の表示時刻・progress の表示時刻・完了時刻を測定し、experience の閾値と継続条件へ照合) |
| playwright | baseline 画像と環境指紋を一つの更新単位で版管理する | 構造検査(baseline metadata と実行環境の environment fingerprint を screenshot の比較前に照合)+実行テスト(fingerprint 一致時だけ `toHaveScreenshot` で screenshot 差分を実行し、画像と metadata の生成が片方だけ確定しないこと)+レビュー(画像と metadata の一組更新の明示承認) |

## 参照
検証の機械化と実行可能な仕様の検査経路は [verification](../../principles/verification/README.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
