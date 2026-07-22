# inspection

## 概要
inspection は、TypeScript で検証を扱う実現軸である。
principles の [verification](../../principles/verification.md) が定める検証の機械化と、[evolution](../../principles/evolution.md) が定める構造を機械で守ることを、TypeScript の機構で満たす。

## 実行

### 要求
単体・性質のテストの実行は、build の設定を共有し変換の前提がずれないようにして速く行う。これを Vitest で満たす。
仕様は cucumber-js、UI の E2E smoke と visual は Playwright で別に実行する。

### 根拠
Vitest は build の設定をテストと共有し、変換の前提がテストと本体でずれない。
テストを速く回し、CI では一度きりの実行になる。
仕様と UI の E2E smoke・visual は目的が異なる別の実行系(cucumber-js・Playwright)を持つので、単体・性質の実行を Vitest に限ってもテスト全体の実行手段は欠けない。

### 完了条件
単体・性質のテストの実行が、Vitest で行われている。
仕様の実行が cucumber-js、UI の E2E smoke と visual の実行が Playwright で行われている。

### 禁止事項
build とテストで、変換の設定を食い違わせること。

### 行動
単体・性質のテストを Vitest で実行し、build の設定を共有する。

## 性質

### 要求
property-based testing は fast-check で書き、状態の遷移は fast-check の model-based な形で書く。

### 根拠
[verification](../../principles/verification.md) が定める、例だけを並べるより性質を書いて入力を多数生成すると見落とした場合が見つかるという要求に、fast-check の入力生成で応える。
失敗した入力は最小化され、seed と path で再現できる。
状態の遷移は、操作の列を生成して実体とモデルの等価を確かめる model-based な形で突ける。

### 完了条件
性質が fast-check で書かれ、入出力の不変量を多くの入力で突いている。
状態の遷移が、model-based な形で書かれている。

### 禁止事項
model を、検証対象の実装の写しにすること。

### 行動
入出力の不変量を性質にし、fast-check で多くの入力を突く。
状態の遷移は、実体と独立したモデルを並べる model-based な形で書く。

### 例
```typescript
// 一つの例しか踏まない
test("rev", () => { expect(reverse(reverse([1, 2, 3]))).toEqual([1, 2, 3]); });

// 性質を多くの入力で突く
fc.assert(fc.property(fc.array(fc.integer()), (values) => {
  expect(reverse(reverse(values))).toEqual(values);
}));
```

## 仕様

### 要求
業務語彙の executable spec は、実行可能にして仕様と実装の継ぎ目を消す。これを cucumber-js で満たす。
UI の E2E smoke と visual は playwright-bdd と Playwright で書き、両者は目的が別なので代替として並べない。

### 根拠
[documentation](../../principles/documentation.md) が定める、仕様の記述にプログラミング言語を使えば仕様と実装の継ぎ目が消えるという要求に、cucumber-js で応える。
executable spec は、業務の振る舞いを公開の interface 越しに確かめる。
UI の E2E smoke と visual は、ブラウザ越しの見た目と疎通を確かめる。
cucumber-js は Cucumber 自身を test runner にして、業務語彙のシナリオを公開の interface 越しに検証する。
playwright-bdd は Gherkin の feature ファイルを Playwright Test のテストファイルへ変換する変換器で、実行は Playwright の runner が担い、UI を操作して見た目と疎通を確かめる。
同じ Gherkin の記法でも、前者は業務語彙の仕様の実行系、後者は UI smoke を Gherkin で書くための変換器であり、担う目的が違う。
両者は目的が違う。
目的の違うものを代替として並べると、どちらの役割も果たせなくなる。

### 完了条件
業務語彙の executable spec が、cucumber-js で書かれ、実行されている。
UI の E2E smoke と visual が、playwright-bdd と Playwright で書かれている。
両者が、代替として並べられていない。

### 禁止事項
executable spec と UI の E2E smoke・visual を、代替として並べること。
仕様に、実装の操作の語を書くこと。

### 行動
業務の語彙でシナリオを書き、cucumber-js のステップで実装する。
UI の E2E smoke と visual は playwright-bdd と Playwright で別に書く。

## accessibility

### 要求
自動判定できる accessibility の違反は、E2E で機械検査する。これを @axe-core/playwright で満たす。
キーボードの到達性は、Playwright の操作と focus の assertion で E2E シナリオとして確かめる。

### 根拠
[experience](../../concerns/experience.md) が要求する対比・ラベル・色だけに頼らない表現のうち、機械判定できる違反は axe の規則が検出する。
playwright-bdd は Playwright Test へ変換するので、生成されたテストの page に AxeBuilder を適用すれば、既存の runner のまま検査が加わる。
axe は focus trap やキーボードの全機能への到達を判定し切れないので、到達性は操作のシナリオで確かめる。

### 完了条件
操作後の各状態が、@axe-core/playwright で検査され、違反が CI で失敗になっている。
キーボードの到達性が、E2E シナリオで確かめられている。

### 禁止事項
機械検査の通過だけで、accessibility を満たしたと称すること。

### 行動
E2E の各状態で AxeBuilder を適用し、違反を失敗として報告する。
Tab・Escape・focus の assertion で、キーボードの到達性のシナリオを書く。

## 実依存

### 要求
実依存のコンテナは、本物に近い依存で検証しテストの終わりに片づける。これを testcontainers の node 実装で満たす。

### 根拠
実依存を mock で置き換えると、実際の API の振る舞いを踏まない。
testcontainers で実依存のコンテナを起動すれば、本物に近い依存で検証でき、コンテナはテストの終わりに片づく。

### 完了条件
実依存のコンテナが、testcontainers の node 実装で起動され、テストの終わりに片づいている。

### 禁止事項
接続の host や port を、固定で書くこと。

### 行動
実依存を testcontainers の node 実装で起動し、割り当てられた host と port を取得して使う。

## 未使用

### 要求
未使用のファイル・エクスポート・依存は、エントリーポイントからの到達可能性で検出し、CI で失敗にする。これを knip で満たす。

### 根拠
参照の消えた残骸は、読み手の探索と依存の把握に費用を課し続ける。
局所の参照数では、相互に参照し合う孤立した島を見つけられない。
knip はエントリーポイントからの到達可能性で判定するので、島ごと検出できる。

### 完了条件
未使用のファイル・エクスポート・依存の検出が、CI に配線され、検出が失敗として扱われている。

### 禁止事項
未使用の検出を、レビューの目視だけで行うこと。

### 行動
エントリーポイントを knip の設定に宣言し、CI で knip を実行して検出を失敗で止める。

## 有効性

### 要求
mutation は StrykerJS で検査し、`thresholds.break` を割ったらビルドを止める。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
StrykerJS は `thresholds.break` を割ったら exit code を非 0 にして CI を止める。

### 完了条件
mutation が StrykerJS で検査され、生き残った欠陥が潰されている。
`thresholds.break` を割ったら、ビルドが止まる。
`thresholds.break` が、0 より大きい。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
`thresholds.break` を定めず、有効性が下がってもビルドを通すこと。
`thresholds.break` を、0 のままにすること。

### 行動
StrykerJS を回し、生き残った欠陥にテストを足す。
`thresholds.break` を 0 でない値に定め、絞り込みは変異演算子と低リスク要素に限って CI に組む。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

## 構造

### 要求
依存方向と境界の禁止は dependency-cruiser で検証し、規則は層の参照禁止と exports の外への到達の禁止を持つ。

### 根拠
[verification](../../principles/verification.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、dependency-cruiser で応える。
層の参照禁止と exports の外への到達の禁止を規則にすれば、層の越境と公開面の迂回が違反として出る。
規則を CI で回せば、違反でビルドが止まる。
import を介さない呼び出し(グローバル API 等)は、import の走査に現れない。
その禁止は、oxlint の no-restricted-properties などの banned API の lint に割り当てる。

### 完了条件
依存方向と境界の禁止が、dependency-cruiser で検証されている。
規則が、層の参照禁止と exports の外への到達の禁止を持っている。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。

### 行動
dependency-cruiser に層の参照禁止と exports の外への到達の禁止を規則として書き、CI で回す。

### 例
```javascript
// 層の参照禁止を実行できる規則にする
{ name: "no-domain-to-infra", severity: "error",
  from: { path: "^src/domain" }, to: { path: "^src/infrastructure" } }
```

## 予防

### 要求
tsconfig は strict を有効にし、型検査と lint の警告を CI でエラーとして扱う。
tsc は型検査の専用に使い、JS への変換は build 基盤に委ねる。
tsconfig は strict に加え、noUncheckedIndexedAccess と exactOptionalPropertyTypes も有効にする。
linter は oxlint を使い、型認識の検査は tsgolint による oxlint の type-aware 実行で行う。
ファイル・関数の大きさとネストの深さのしきい値は oxlint の max-lines(ファイル)・max-lines-per-function(関数)・max-depth(ネスト)の規則として定め、既定値から緩める変更は project の ADR に明記する。
認知的複雑さは SonarQube の cognitive complexity(S3776)で測り、oxlint 側の複雑度の規則(complexity)は有効にしない。
SonarQube の profile は cognitive complexity(S3776)に絞り、ローカル lint と同目的の規則を重ねない。

### 根拠
strict を有効にすれば、不在や暗黙の any が型検査で止まる。
noUncheckedIndexedAccess は配列・索引アクセスの結果に `undefined` を型で強制し、exactOptionalPropertyTypes は省略可能なプロパティへの明示的な `undefined` 代入を区別するので、formation が定める不在の union と厳密な型検査の規律を tsconfig が機械で支える。
型検査と lint の警告をエラーにすれば、規則の違反がビルドで止まる。
oxlint は、tsgolint の type-aware 実行により floating promise や unsafe な型変換を検出できる。
max-lines・max-lines-per-function・max-depth は、ファイル・関数の大きさとネストの深さを早く気づかせる。
oxlint の complexity 規則は cyclomatic complexity であり cognitive complexity と同一でないため、複雑度は SonarQube の S3776 に一本化し二重に測らない。
SonarQube の cognitive complexity は switch の構造化を一度だけ加点し case の数に比例しないので、判別子つき union の網羅的な switch を罰しない。
SonarQube の profile を cognitive complexity だけに絞れば、oxlint が既に検査する未使用変数などの規則を SonarQube 側で重ねて測ることがない。
既定から緩める判断を ADR に残せば、緩和の理由が追える。
tsc の emit は build 基盤の変換と重複し、二重の変換経路を生む。

### 完了条件
tsconfig の strict が、有効になっている。
tsconfig の noUncheckedIndexedAccess と exactOptionalPropertyTypes が、strict と併記して有効になっている。
型検査と lint の警告が、CI でエラーとして扱われている。
oxlint が linter として使われ、型認識の検査が tsgolint で行われている。
ファイル・関数の大きさとネストの深さのしきい値が、max-lines・max-lines-per-function・max-depth の規則として定められている。
緩和が、project の ADR に明記されている。
oxlint の complexity 規則が、有効になっていない。
SonarQube の profile が、cognitive complexity に絞られている。
tsc が型検査の専用に設定され、JS への変換が build 基盤に委ねられている。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
判別子つき union の網羅的な switch を、複雑度の加点対象にする指標を採ること。
cognitive complexity を、oxlint の complexity 規則で測ること。
SonarQube の profile に、ローカル lint と同目的の規則を重ねて有効にすること。
tsc を、JS への変換に使うこと。

### 行動
strict を有効にし、型検査と lint の警告を CI でエラーにする。
noUncheckedIndexedAccess と exactOptionalPropertyTypes を strict と併記して有効にする。
oxlint を導入し tsgolint で type-aware の検査を行い、max-lines・max-lines-per-function・max-depth のしきい値を定める。
複雑度は SonarQube の quality gate に一本化し、緩和は ADR に明記する。
SonarQube の profile は cognitive complexity だけに絞る。

## ドキュメントコメントの検査

### 要求
@param・@returns の網羅は oxlint の jsdoc/require-param・jsdoc/require-returns などの規則群で検査する。
@typeParam・@throws の網羅と、TSDoc の構文が仕様に準拠しているかと、宣言した要素にドキュメントコメントが存在するかと、最初の一行が [conventions](./conventions.md) の体裁(名前の直訳でない体言止め・句読点なし)を満たしているかは、oxlint に検査する規則が無いため、レビューで確かめる。
内容がユビキタス言語と一致しているかは、レビューで確かめる。

### 根拠
oxlint の jsdoc 系の規則は、ドキュメントコメントが既に在るときの @param・@returns の網羅を検査できるが、ドキュメントコメントの存在そのものを要求する規則を持たない。
oxlint の jsdoc 系の規則は @typeParam・@throws の網羅と最初の一行の体裁を検査する規則を持たないため、その部分はレビューで埋める。
TSDoc の構文検査は oxlint に無く、単一の採用を守るために別の linter を並走させない。
内容がユビキタス言語と一致しているかの判断は意味を読む必要があり、機械化できない。

### 完了条件
@param・@returns の網羅が、oxlint の jsdoc の規則群で検査されている。
@typeParam・@throws の網羅と最初の一行の体裁が、レビューで確かめられている。
TSDoc の構文の準拠とドキュメントコメントの存在が、レビューで確かめられている。
内容とユビキタス言語の一致が、レビューで確かめられている。

### 禁止事項
TSDoc の構文検査・ドキュメントコメントの存在検査・@typeParam と @throws の網羅検査・最初の一行の体裁検査を、oxlint が行っていると称すること。

### 行動
oxlint に jsdoc の規則群を有効にし、CI で検査する。
@typeParam・@throws の網羅・TSDoc の構文の準拠・ドキュメントコメントの存在・最初の一行の体裁・内容の妥当性は、レビューで確かめる。

## 規則と検証機構の対応

formation・translation・connection・retention・coordination・publication・conventions の各規律を、検証手段へ写像する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| 実現軸 | 規律 | 検証手段 |
|---|---|---|
| formation | 業務の値を型に封じる | 型(valibot の brand・safeParse)+実行テスト(factory の単体テスト) |
| formation | 不正な状態を構築できなくする | 型(判別子つき union・never 網羅) |
| formation | 不変を既定にする | 型(readonly・as const) |
| formation | 意味と単位を型で区別する | 型(branded type) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(oxfmt チェック・oxlint の unicorn/filename-case)+構造検査(自作の命名照合。型・値の PascalCase・camelCase) |
| conventions | ドキュメントコメントを書く | analyzer/lint(oxlint の jsdoc 規則群。@param・@returns の網羅)+レビュー(@typeParam・@throws の網羅・存在・構文・最初の一行の体裁・意味の妥当性) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(自作の命名照合) |
| translation | unknown で受けて一度だけ parse する | 型/実行テスト(valibot の safeParse・境界の parse の単体テスト) |
| translation | 受け取ったエラーを parse し、想定された失敗と欠陥を分ける | 実行テスト(4xx・5xx の分岐の単体テスト) |
| translation | 契約の型を生成する | 実行テスト(drift 検査の CI gate) |
| translation | 生成型を型としてのみ使い、通信を port に通す | 構造検査(dependency-cruiser での runtime の import の検出)+型(import type) |
| connection | 効果を遅延した関数で表す | 型(関数のシグネチャ・ResultAsync) |
| connection | 想定内失敗を Result で返す | 型(neverthrow の Result・判別子つき union) |
| connection | throw を欠陥として境界で分ける | 実行テスト(try-catch 境界の単体テスト) |
| connection | 依存を環境で受け、host の能力を port で宣言する | 型(環境の型・ui port の型)+レビュー(singleton を作らないことの判断) |
| retention | 状態の機構 | レビュー(由来ごとの機構選択の判断) |
| retention | remote の規律 | レビュー(store への複製の禁止の判断) |
| retention | 保存の禁止 | analyzer/lint(oxlint の no-restricted-properties で localStorage・sessionStorage の直呼びを禁止) |
| retention | extension の保持状態 | 型(state port・secret port)+レビュー |
| coordination | 非同期 | レビュー |
| coordination | 取り消し | 実行テスト(AbortSignal の伝播の単体テスト) |
| coordination | 並行の組 | 実行テスト(AbortController での一括 abort の単体テスト) |
| coordination | メインスレッドを塞がない | レビュー(重い同期計算の特定と退避の判断) |
| coordination | 後始末 | レビュー(onCleanup 登録漏れの判断) |
| publication | viewer | レビュー(props の分割代入の禁止) |
| publication | viewer の telemetry | 型(ui port の型)+レビュー(SDK の adapter への隔離の判断) |
| publication | styling | レビュー |
| publication | web の host | レビュー |
| publication | extension | 型(port の interface) |
| publication | ide の host | 型(判別子つき union の schema・safeParse)+実行テスト(postMessage 受信の単体テスト) |
| publication | core への接続 | 型(RequestType・NotificationType の型宣言) |
| publication | 可視性 | 構造検査(package.json の exports フィールドの検査) |

## 参照
検証の機械化は [verification](../../principles/verification.md)、構造を守る進化は [evolution](../../principles/evolution.md)、仕様と実装の継ぎ目の解消は [documentation](../../principles/documentation.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
