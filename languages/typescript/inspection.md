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
テストを速く回し、検証入口では一度きりの実行になる。
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
一つの固定入力だけでは、性質が他の入力でも成り立つかは分からない。

```typescript
test("rev", () => { expect(reverse(reverse([1, 2, 3]))).toEqual([1, 2, 3]); });
```

property-based testing では、同じ性質を生成した多くの入力で確かめる。

```typescript
fc.assert(fc.property(fc.array(fc.integer()), (values) => {
  expect(reverse(reverse(values))).toEqual(values);
}));
```

## 仕様

### 要求
業務語彙の executable spec は、[verification](../../principles/verification.md) が定める同じ検査経路で、cucumber-js として実行する。
feature の各 step は、一つの step binding と、その binding が呼ぶ公開 interface の operation に対応させる。
feature、step binding、公開 interface の対応は、各一覧を実体から導く drift 検査と executable spec の実行で検証する。
UI の E2E smoke と visual は playwright-bdd と Playwright で書き、両者は目的が別なので代替として並べない。
[experience](../../concerns/experience.md) が定める状態または feedback の100ms、1秒を超える operation の progress 開始までの1秒と完了までの継続は、Playwright の E2E で表示時刻を測定する。
visual の baseline 画像は、画像ごとか同じ実行環境を使う画像集合ごとに対応する metadata と組にし、レビューを通して版管理する。
metadata は、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport を持つ。
metadata の各値は、形式を固定した canonical serialization から environment fingerprint を生成できる形で記録する。
visual は、実行環境の現在値から生成した environment fingerprint と metadata の fingerprint を screenshot の比較前に照合する。
fingerprint が一致しないときは、visual を失敗させ、旧い baseline 画像との screenshot 比較を実行しない。
baseline を更新するときは、画像と metadata を一つの更新単位として生成し、同じ変更で明示的にレビューする。

### 根拠
[verification](../../principles/verification.md) が定める、実行可能な仕様と実装を同じ検査経路に載せ、別成果物なら対応を検証する要求に、cucumber-js で応える。
feature、step binding、公開 interface は別の成果物なので、対応の drift 検査がなければ一方だけ古くなりうる。
executable spec は、業務の振る舞いを公開の interface 越しに確かめる。
UI の E2E smoke と visual は、ブラウザ越しの見た目と疎通を確かめる。
操作の入力と表示結果を同じ E2E で測れば、handler の起動や server の完了でなく、利用者が状態、feedback、progress を見られるまでの時間を判定できる。
baseline 画像と実行環境の metadata を組にすれば、画像を承認した環境を再現できる。
canonical serialization から fingerprint を生成すれば、metadata の表記揺れを環境差と誤認しない。
fingerprint を screenshot の比較前に照合すれば、実行環境の差を見た目の変更として承認する経路を閉じられる。
画像と metadata を一つの更新単位にすれば、画像だけを別の環境へ持ち越さない。
`toHaveScreenshot` の差分を検証入口で検出すれば、未レビューの見た目の変更が baseline へ混入しない。
cucumber-js は Cucumber 自身を test runner にして、業務語彙のシナリオを公開の interface 越しに検証する。
playwright-bdd は Gherkin の feature ファイルを Playwright Test のテストファイルへ変換する変換器で、実行は Playwright の runner が担い、UI を操作して見た目と疎通を確かめる。
同じ Gherkin の記法でも、前者は業務語彙の仕様の実行系、後者は UI smoke を Gherkin で書くための変換器であり、担う目的が違う。
両者は目的が違う。
目的の違うものを代替として並べると、どちらの役割も果たせなくなる。

### 完了条件
業務語彙の executable spec が、cucumber-js で書かれ、実行されている。
feature の全 step が、一つの step binding と公開 interface の operation に対応している。
feature、step binding、公開 interface の対応に欠落と余剰がなく、drift 検査と executable spec の実行が同じ検証入口で通っている。
UI の E2E smoke と visual が、playwright-bdd と Playwright で書かれている。
各操作の入力時刻、状態または feedback の表示時刻、1秒を超える operation の progress 表示時刻と完了時刻が Playwright で測定され、experience の閾値と継続条件を満たしている。
visual の baseline 画像と対応する metadata が、レビュー済みの状態で版管理されている。
各 baseline 画像か同じ実行環境を使う画像集合の metadata に、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport が記録されている。
metadata と実行環境の現在値が、同じ canonical serialization から environment fingerprint を生成している。
二つの fingerprint が一致した場合だけ、`toHaveScreenshot` が baseline 画像を比較している。
fingerprint が一致しない場合は、screenshot を比較せずに visual が失敗している。
baseline 画像と metadata の更新が一つの更新単位で行われ、同じ変更として明示的にレビューされている。
baseline 画像か metadata の生成に失敗した場合は、どちらも更新されていない。
両者が、代替として並べられていない。

### 禁止事項
executable spec と UI の E2E smoke・visual を、代替として並べること。
handler の起動時刻または server の完了時刻を、状態、feedback、progress が利用者へ表示された時刻として扱うこと。
visual の baseline 画像か metadata のどちらか一方だけを更新すること。
baseline 画像と metadata の更新を、レビューなしに確定すること。
実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport のいずれかを metadata から省くこと。
environment fingerprint が一致しない状態で、旧い baseline 画像との screenshot 比較を実行すること。
baseline 画像と metadata を別々の変更で更新すること。
仕様に、実装の操作の語を書くこと。
実行可能であることを理由に、feature、step binding、公開 interface の継ぎ目が消えたとみなすこと。
feature、step binding、公開 interface の対応を、人が固定した件数だけで検査すること。

### 行動
業務の語彙でシナリオを書き、cucumber-js のステップで実装する。
feature の step、step binding、公開 interface の operation をそれぞれ実体から列挙し、対応の欠落と余剰を drift 検査で失敗させる。
drift 検査と executable spec を、実装と同じ検証入口で実行する。
UI の E2E smoke と visual は playwright-bdd と Playwright で別に書く。
Playwright で操作を入力し、入力時刻、状態または feedback の表示時刻、progress の表示時刻、完了時刻を記録して、experience の閾値と継続条件を検査する。
baseline 画像ごとか同じ実行環境を使う画像集合ごとに metadata を置き、画像とともに版管理する。
実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport を metadata へ記録する。
metadata と実行環境の現在値を同じ形式で canonical serialization し、それぞれの environment fingerprint を生成する。
二つの fingerprint を screenshot の比較前に照合し、一致しなければ失敗させる。
fingerprint が一致した場合だけ、`toHaveScreenshot` で baseline 画像を比較する。
baseline を更新するときは、画像と metadata の両方を生成する単一の更新処理を使い、片方の生成に失敗したら両方を確定しない。
baseline の画像と metadata の差分を、同じ変更として明示的にレビューする。

### 例

baseline 集合の metadata は、次のように環境の値だけを持つ。

```json
{
  "arch": "x86_64",
  "browserVersion": "1.2.3",
  "ciImageDigest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "fontManifestDigest": "sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
  "hardwareRenderingClass": "software",
  "headlessMode": true,
  "os": "linux",
  "playwrightVersion": "1.2.3",
  "viewport": { "height": 720, "width": 1280 }
}
```

metadata と実行環境の現在値には同じ canonical serializer を適用し、fingerprint が一致した後だけ screenshot を比較する。

```ts
const expectedFingerprint = sha256(canonicalSerialize(baselineMetadata));
const actualFingerprint = sha256(canonicalSerialize(readVisualEnvironment()));

if (actualFingerprint !== expectedFingerprint) {
  throw new Error("visual environment fingerprint mismatch");
}

await expect(page).toHaveScreenshot();
```

baseline の更新処理は画像と metadata を同時に生成し、両方を同じ変更としてレビューへ出す。

## accessibility

### 要求
自動判定できる accessibility の違反は、E2E で機械検査する。これを @axe-core/playwright で満たす。
キーボードの到達性は、Playwright の操作と focus の assertion で E2E シナリオとして確かめる。
pointer target は、Playwright で表示後の bounding box を CSS px で測定し、Success Criterion 2.5.8 の例外記録と照合する。
text と non-text の contrast は、Playwright で表示結果の style、font face、user agent の font metadata、font metrics、隣接色を取得し、Success Criterion 1.4.3 と1.4.11の閾値と例外記録に照合する。

### 根拠
[experience](../../concerns/experience.md) が要求する対比・ラベル・色だけに頼らない表現のうち、機械判定できる違反は axe の規則が検出する。
playwright-bdd は Playwright Test へ変換するので、生成されたテストの page に AxeBuilder を適用すれば、既存の runner のまま検査が加わる。
axe は focus trap やキーボードの全機能への到達を判定し切れないので、到達性は操作のシナリオで確かめる。
axe の規則だけでは、project が記録した Success Criterion 2.5.8 の例外、Roman と CJK の large text の根拠、Success Criterion 1.4.3 と1.4.11の対象別の例外を照合できない。
Playwright で表示結果と例外記録を同じ E2E に入力すれば、experience の観測可能な閾値と証拠要件をそのまま検査できる。

### 完了条件
操作後の各状態が、@axe-core/playwright で検査され、違反が検証入口で失敗になっている。
キーボードの到達性が、E2E シナリオで確かめられている。
各 pointer target の表示後の bounding box が CSS px で測定され、24×24 CSS px 以上であるか、Success Criterion 2.5.8 の例外と理由を持っている。
text と non-text の表示結果、font の分類根拠、隣接色、適用した例外が記録され、Success Criterion 1.4.3 と1.4.11の閾値に照合されている。

### 禁止事項
機械検査の通過だけで、accessibility を満たしたと称すること。
Success Criterion 2.5.8、1.4.3、1.4.11 の例外を、対象と理由の記録なしに検査から除くこと。
Roman または CJK の large text の分類根拠を記録せず、3:1の閾値を適用すること。

### 行動
E2E の各状態で AxeBuilder を適用し、違反を失敗として報告する。
Tab・Escape・focus の assertion で、キーボードの到達性のシナリオを書く。
Playwright で pointer target の表示後の bounding box を CSS px で測り、Success Criterion 2.5.8 の例外記録と照合する。
Playwright で表示結果の style、font face、user agent の font metadata、font metrics、隣接色を取得し、Success Criterion 1.4.3 と1.4.11の閾値および例外記録と照合する。

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
未使用のファイル・エクスポート・依存は、エントリーポイントからの到達可能性で検出し、検証入口で失敗にする。これを knip で満たす。

### 根拠
参照の消えた残骸は、読み手の探索と依存の把握に費用を課し続ける。
局所の参照数では、相互に参照し合う孤立した島を見つけられない。
knip はエントリーポイントからの到達可能性で判定するので、島ごと検出できる。

### 完了条件
未使用のファイル・エクスポート・依存の検出が、検証入口に配線され、検出が失敗として扱われている。

### 禁止事項
未使用の検出を、レビューの目視だけで行うこと。

### 行動
エントリーポイントを knip の設定に宣言し、検証入口で knip を実行して検出を失敗で止める。

## 有効性

### 要求
mutation は、StrykerJS で検査する。
機械可読な report の `totalUndetected` を gate にし、値が無い形式では `Survived` と `NoCoverage` の合計を gate にする。
検出されなかった mutant が一件でもあれば、検証入口を失敗で止める。
mutation score の正の threshold を、検出されなかった mutant 0件の gate の代わりにしない。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
`Survived` と `NoCoverage` は、どちらもテストが検出していない変更である。
`totalUndetected` または両 status の合計を直接 gate にすれば、score の丸めや集約に判断を委ねず、未検出の変更が残っている事実で止められる。
正の score threshold は未検出 mutant を許す設定になり得るため、0件の完了条件を代替しない。

### 完了条件
mutation が StrykerJS で検査され、検出されなかった欠陥が潰されている。
report の `totalUndetected`、または `Survived` と `NoCoverage` の合計が、0件である。
検出されなかった mutant が一件でもあれば、検証入口が失敗している。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
`Survived` だけを数え、`NoCoverage` を gate から除くこと。
検出されなかった mutant を、一件でも残したまま検証入口を通すこと。
mutation score の正の threshold を、検出されなかった mutant 0件の gate の代わりにすること。

### 行動
StrykerJS を回し、生き残った欠陥にテストを足す。
StrykerJS の機械可読な report から `totalUndetected` を読み、一件以上なら検証入口を終了コード非0で止める。
report に `totalUndetected` が無い場合は、`Survived` と `NoCoverage` の件数を合計し、一件以上なら検証入口を終了コード非0で止める。
絞り込みは、変異演算子と低リスク要素に限って検証入口に組む。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

## 構造

### 要求
依存方向と境界の禁止は dependency-cruiser で検証し、規則は層の参照禁止と exports の外への到達の禁止を持つ。
root の構造検査は、skeleton の実行時表と build・test-only 表から runtime・build・test phase の許可 edge を生成する。
root の構造検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。
外部 I/O、待機、下流 Effect の非同期呼出は、TypeScript compiler API による AST 構造検査で検査する。
外部 I/O と待機の symbol は、構造検査の設定に列挙する。
Promise を返す前に同期で throw し得る境界 API の symbol と、throw し得る同期 DOM API と postMessage の symbol は、構造検査の設定で別の集合に列挙する。
前者の呼出式は `ResultAsync.fromThrowable` に渡して直後に呼ぶ関数リテラルの内側だけに、後者の呼出式は `Result.fromThrowable` に渡して直後に呼ぶ関数リテラルの内側だけに許す。
同期で throw し得る呼出式を `ResultAsync.fromPromise` の第一引数へ直接渡す形は拒否する。
下流 Effect は、callee expression の型が Effect の nominal brand を持つか、branded Effect へ代入可能かで識別する。
外部 I/O、待機、下流 Effect は、`withDeadlineEffect` の operation からだけ呼ぶ。
`withDeadlineEffect` は host ごとの `ResumeSource` capability を受け、`window` と `document` を直接参照しない。
全ての公開 Effect factory は、TypeScript compiler API による AST 構造検査で検査する。
Effect の callable な型は `unique symbol` の nominal brand を持ち、`deferEffect` だけが branded value を構築する形を許す。
公開 Effect factory の parameter は、default parameter と destructuring の binding initializer を持たない形だけを許す。
公開 Effect factory の本体は、実行用の関数リテラルを `deferEffect` へ渡す形だけを許す。

### 根拠
[verification](../../principles/verification.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、dependency-cruiser で応える。
層の参照禁止と exports の外への到達の禁止を規則にすれば、層の越境と公開面の迂回が違反として出る。
規則を検証入口で回せば、違反でビルドが止まる。
import を介さない呼び出し(グローバル API 等)は、import の走査に現れない。
その禁止は、oxlint の no-restricted-properties などの banned API の lint に割り当てる。
TypeScript compiler API は、export され、戻り値が Effect に代入可能な function と変数を全て列挙し、本体の call expression と引数を取得できる。
TypeScript compiler API は `unique symbol` の参照と type assertion を取得できるため、型宣言を除く brand の値参照と Effect への assertion を `deferEffect` の実装内へ限定できる。
TypeScript compiler API は call expression の symbol と callee expression の型を解決できる。
Promise を返す境界と同期 DOM と postMessage の symbol を別々に列挙すれば、各呼出式を同期と非同期に対応する `fromThrowable` の関数リテラルへ限定できる。
`ResultAsync.fromPromise` の第一引数は構文木から取得できるため、同期で throw し得る call expression が先に評価される形を拒否できる。
callee expression の型に Effect の `unique symbol` brand があるか、branded Effect へ代入可能かを調べれば、呼出結果が ResultAsync でも下流 Effect の呼出を識別できる。
設定に列挙した外部 I/O と待機、および callee expression で識別した下流 Effect の呼出を、`withDeadlineEffect` の operation 内に限定できる。
TypeScript compiler API は wrapper 内の global symbol を解決できるため、`withDeadlineEffect` から `window` と `document` の直接参照を拒否できる。
TypeScript compiler API は parameter の initializer と destructuring の binding element を取得できるため、factory 本体へ入る前の副作用経路を検出できる。
公開 Effect factory の本体を `deferEffect` の直接呼出だけにし、その引数を関数リテラルだけにすれば、factory の評価中に副作用を起動する式を構造で排除できる。
`deferEffect` 自体の実行テストは constructor の遅延を確認するが、全ての公開 factory の形は確認しない。

### 完了条件
依存方向と境界の禁止が、dependency-cruiser で検証されている。
規則が、層の参照禁止と exports の外への到達の禁止を持っている。
root の構造検査が、skeleton の両表から phase ごとの許可 edge を生成している。
build または test の edge が runtime の成果物へ混入した場合に、構造検査が失敗している。
外部 I/O、待機、下流 Effect が、`withDeadlineEffect` の operation からだけ呼ばれている。
Promise を返す前に同期で throw し得る境界 API が、`ResultAsync.fromThrowable` に渡して直後に呼ぶ関数リテラルの内側からだけ呼ばれている。
throw し得る同期 DOM API と postMessage が、`Result.fromThrowable` に渡して直後に呼ぶ関数リテラルの内側からだけ呼ばれている。
同期で throw し得る呼出式が、`ResultAsync.fromPromise` の第一引数へ直接渡されていない。
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
Promise を返す前に同期で throw し得る境界 API を、`ResultAsync.fromThrowable` の関数リテラルの外から呼ぶこと。
throw し得る同期 DOM API または postMessage を、`Result.fromThrowable` の関数リテラルの外から呼ぶこと。
同期で throw し得る呼出式を、`ResultAsync.fromPromise` の第一引数へ直接渡すこと。
`withDeadlineEffect` から `window` または `document` を直接参照すること。
`deferEffect` の外で、Effect の brand を構築または型変換で偽装すること。
公開 Effect factory を一部だけ抽出して、遅延を全件保証したとみなすこと。
公開 Effect factory の default parameter または destructuring の binding initializer を、検査対象から外すこと。
`deferEffect` の実行テストだけで、全ての公開 Effect factory の遅延を保証したとみなすこと。

### 行動
dependency-cruiser に層の参照禁止と exports の外への到達の禁止を規則として書き、検証入口で回す。
skeleton の両表を TypeScript compiler API で読み、runtime・build・test phase の許可 edge を生成して dependency-cruiser の依存 graph と照合する。
runtime の成果物を構成する依存 closure に build または test の edge があれば失敗させる。
TypeScript compiler API で外部 I/O、待機、下流 Effect の call expression を列挙し、`withDeadlineEffect` の operation 内にあることを検証入口で検査する。
Promise を返す前に同期で throw し得る境界 API と、throw し得る同期 DOM API と postMessage の symbol を別々に設定へ列挙する。
前者が `ResultAsync.fromThrowable` に渡して直後に呼ぶ関数リテラルの内側に、後者が `Result.fromThrowable` に渡して直後に呼ぶ関数リテラルの内側にあることを検証入口で検査する。
`ResultAsync.fromPromise` の第一引数に、同期で throw し得る call expression が無いことを検証入口で検査する。
TypeScript compiler API で `withDeadlineEffect` の global symbol 参照を列挙し、`window` と `document` の直接参照を検証入口で拒否する。
外部 I/O と待機は、設定に列挙した symbol で識別する。
下流 Effect は、callee expression の型に nominal brand があるか、branded Effect へ代入可能かで識別する。
TypeScript compiler API で export され、戻り値が Effect に代入可能な function と変数を全て列挙する。
型宣言を除く Effect の `unique symbol` brand の値参照と Effect への type assertion が、`deferEffect` の実装内だけにあることを検証入口で検査する。
公開 Effect factory の parameter に、default parameter と destructuring の binding initializer が無いことを検証入口で検査する。
factory 本体が `deferEffect` を直接呼び、実行用の関数リテラルだけを渡す形であることを検証入口で検査する。

### 例
層の参照禁止は、実行可能な規則として設定する。

```javascript
{ name: "no-domain-to-infra", severity: "error",
  from: { path: "^src/domain" }, to: { path: "^src/infrastructure" } }
```

## 予防

### 要求
tsconfig は strict を有効にし、型検査と lint の警告を検証入口でエラーとして扱う。
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
oxlint の complexity 規則が測る cyclomatic complexity は cognitive complexity と別の性質であり、重複検証ではない。標準が必須の検証へ割り当てる複雑度は cognitive complexity であり、cyclomatic complexity は必須の検証へ割り当てていないため、oxlint の complexity 規則は有効にしない。
SonarQube の cognitive complexity は switch の構造化を一度だけ加点し case の数に比例しないので、判別子つき union の網羅的な switch を罰しない。
SonarQube の profile を cognitive complexity だけに絞れば、oxlint が既に検査する未使用変数などの規則を SonarQube 側で重ねて測ることがない。
既定から緩める判断を ADR に残せば、緩和の理由が追える。
tsc の emit は build 基盤の変換と重複し、二重の変換経路を生む。

### 完了条件
tsconfig の strict が、有効になっている。
tsconfig の noUncheckedIndexedAccess と exactOptionalPropertyTypes が、strict と併記して有効になっている。
型検査と lint の警告が、検証入口でエラーとして扱われている。
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
strict を有効にし、型検査と lint の警告を検証入口でエラーにする。
noUncheckedIndexedAccess と exactOptionalPropertyTypes を strict と併記して有効にする。
oxlint を導入し tsgolint で type-aware の検査を行い、max-lines・max-lines-per-function・max-depth のしきい値を定める。
認知的複雑さは SonarQube の cognitive complexity(S3776)を quality gate で測り、緩和は ADR に明記する。
SonarQube の profile は cognitive complexity だけに絞る。

## ドキュメントコメントの検査

### 要求
TypeScript compiler API と `@microsoft/tsdoc` による構造検査を、ドキュメントコメントの検査入口にする。
宣言した要素のドキュメントコメントの存在を、構造検査で検査する。
TSDoc の構文と @typeParam・@param・@returns の宣言との対応を、構造検査で検査する。
@throws が `@throws {@link ErrorType} 条件` の書式であることを、構造検査で検査する。
当該宣言から外へ伝播すると compiler API で判定できる直接の throw の型と、@throws の link の参照先を semantic model で照合する。
当該宣言内の try/catch で吸収される throw は、@throws の構造検査対象から除く。
最初の一行が一行であり句読点を含まないことを、構造検査で検査する。
呼出先または rejected Promise から伝播する欠陥が当該宣言の契約かと、その @throws は、公開範囲を問わずレビューで確かめる。
最初の一行が名前の直訳でないこと、用途を判断できること、体言止めであることはレビューで確かめる。
内容が、実効的な可視境界を基準に、module 外へ公開される要素では外部契約を、同一境界内だけの要素では内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致しているかは、レビューで確かめる。

### 根拠
TypeScript compiler API は宣言と型引数、引数、戻り値、直接の throw、try/catch の包含関係、対応するコメント範囲を構文木から取得できる。
TypeScript compiler API の semantic model は、throw 式の型と link が参照する symbol を解決できる。
`@microsoft/tsdoc` はコメントを TSDoc の構文として parse し、`{@link ErrorType}` を link として読める。
両者を組み合わせれば、存在、構文、宣言と tag の機械判定できる対応、外へ伝播する直接の throw の型と link、先頭行の一行と句読点を照合できる。
呼出先や rejected Promise から伝播する欠陥が当該宣言の契約かは、呼出関係と契約の意味を読む必要がある。
名前の直訳でないこと、用途を判断できること、体言止めであることは、字面だけでは判定できない。
内容が可視性に応じた外部契約または内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致しているかは、意味を読む必要があるため機械化しない。

### 完了条件
ドキュメントコメントの存在が、TypeScript compiler API による構造検査で検査されている。
TSDoc の構文が、`@microsoft/tsdoc` による構造検査で検査されている。
@typeParam・@param・@returns が宣言と対応することが、構造検査で検査されている。
@throws が、`@throws {@link ErrorType} 条件` の書式であることが構造検査で検査されている。
当該宣言から外へ伝播すると機械判定できる直接の throw の型と、@throws の link の参照先が semantic model で照合されている。
当該宣言内の try/catch で吸収される throw が、@throws の構造検査対象から除かれている。
最初の一行が一行であり句読点を含まないことが、構造検査で検査されている。
呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥と @throws の対応が、公開範囲を問わずレビューで確かめられている。
最初の一行が名前の直訳でなく用途を判断できる体言止めであることが、レビューで確かめられている。
内容が、module 外へ公開される要素では外部契約を、同一境界内だけの要素では内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致していることが、レビューで確かめられている。

### 禁止事項
ドキュメントコメントの存在、構文、機械判定できる tag の対応、最初の一行と句読点を、レビューだけで検査すること。
@throws の error type を、`{@link ErrorType}` で参照せず平文だけで書くこと。
直接の throw の型と異なる symbol を、@throws の link で参照すること。
当該宣言内の try/catch で吸収される throw に、@throws を機械的に要求すること。
呼出先または rejected Promise から伝播する欠陥の @throws を、構造検査だけで網羅できるとみなすこと。
先頭行の用途と体言止めを、構造検査だけで保証できるとみなすこと。
内容の意味とユビキタス言語との一致を、構造検査だけで保証できるとみなすこと。

### 行動
TypeScript compiler API で宣言とコメントを取得し、`@microsoft/tsdoc` でコメントを parse する構造検査を検証入口で実行する。
構造検査で、存在、構文、@typeParam・@param・@returns の宣言との対応、`@throws {@link ErrorType} 条件` の書式、最初の一行と句読点を照合する。
semantic model で当該宣言から外へ伝播する直接の throw の型と、@throws の link の参照先を照合する。
当該宣言内の try/catch で吸収される throw を、@throws の構造検査対象から除く。
公開範囲を問わず、呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥と @throws の対応をレビューする。
レビューで、先頭行が名前の直訳でなく用途を判断できる体言止めであることを確かめる。
ドキュメントコメントが、実効的な可視境界を基準に、module 外へ公開される要素では外部契約を、同一境界内だけの要素では内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致していることをレビューする。

## 規則と検証機構の対応

formation・translation・connection・retention・coordination・publication・conventions・inspection の8実現軸の各規律を、検証手段へ写像する。
inspection 軸は、この文書の規律を定める H2 見出しを対応表へ全て列挙する。
標準 repository の verifier は、各実現軸の規律を表す H2 見出しの集合と、この対応表の規律の集合を照合し、欠落、余分、重複があれば失敗する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| 実現軸 | 規律 | 検証手段 |
|---|---|---|
| inspection | 実行 | 実行テスト(Vitest の単体・性質・結合を検証入口で実行し、発見件数0を失敗にする) |
| inspection | 性質 | 実行テスト(fast-check の生成・縮小・stateful property と回帰 seed の再実行) |
| inspection | 仕様 | 構造検査(feature・step binding・公開 interface operation の実体由来一覧の drift、baseline metadata と environment fingerprint の照合)+実行テスト(cucumber-js を実装と同じ検証入口で実行し、Playwright で状態・feedback・progress の表示時間を測定し、fingerprint 一致時だけ screenshot 差分を実行)+実行テスト・レビュー(baseline 画像と metadata の原子的な更新と明示承認) |
| inspection | accessibility | 実行テスト(@axe-core/playwright による自動判定可能な違反、Playwright による keyboard 操作・pointer target の bounding box・WCAG 2.2 Level AA の text/non-text contrast と例外記録の照合)+レビュー(自動判定できない WCAG 2.2 Level AA の確認) |
| inspection | 実依存 | 実行テスト(testcontainers の割当 host・port を使う結合テストと終了時の破棄)+runner 検査(`vitest list --json` と Playwright `--list` が返す project・file・suite・test の組を native test ID とする size ごとの排他・全域集合一致、発見件数0の拒否、実行環境の資源制限。cucumber-js scenario は URI・line・name の組を同じ集合へ加える) |
| inspection | 未使用 | analyzer/lint(knip で未使用のファイル・export・依存を検出し検証入口で失敗) |
| inspection | 有効性 | mutation(StrykerJS の totalUndetected または Survived+NoCoverage が0件の gate と対象件数0の失敗) |
| inspection | 構造 | 構造検査(TypeScript compiler API と dependency-cruiser が skeleton の両表から runtime・build・test edge を生成し、runtime 成果物への build・test edge 混入を失敗にする) |
| inspection | 予防 | analyzer/lint(tsc・oxlint・tsgolint・SonarQube の設定と診断を検証入口でエラー化) |
| inspection | ドキュメントコメントの検査 | 構造検査(TypeScript compiler API と `@microsoft/tsdoc`)+レビュー(実効的な可視境界に応じた外部契約または内部契約、伝播する欠陥、再述でない意味、語彙) |
| formation | 業務の値を型に封じる | 型(valibot の brand・safeParse)+実行テスト(factory の単体テスト) |
| formation | 不正な状態を構築できなくする | 型(判別子つき union・never 網羅) |
| formation | 不変を既定にする | 型(readonly・as const) |
| formation | 意味と単位を型で区別する | 型(branded type) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(oxfmt チェック・oxlint の unicorn/filename-case)+構造検査(TypeScript compiler API による型・値の PascalCase・camelCase の命名照合) |
| conventions | ドキュメントコメントを書く | 構造検査(TypeScript compiler API と @microsoft/tsdoc。存在・構文・宣言と tag の対応・`@throws {@link ErrorType} 条件`・外へ伝播する直接の throw の型と link・try/catch で吸収される throw の除外・先頭行の一行と句読点)+レビュー(実効的な可視境界に応じた外部契約または内部契約、call/rejected Promise から伝播する欠陥と @throws、再述でない意味、ユビキタス言語) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(TypeScript compiler API による命名照合) |
| 全域 | branch coverage と safety-critical decision | 計測(Vitest coverage の v8 provider で project 記録の branch 下限を検証入口で判定)+構造検査・実行テスト([structure/tests の methods](../../structure/tests/methods.md) が定める safety analysis と MC/DC case の一対一照合) |
| translation | unknown で受けて一度だけ parse する | 型/実行テスト(valibot の safeParse・境界の parse の単体テスト) |
| translation | 受け取ったエラーを parse し、想定された失敗と欠陥を分ける | 実行テスト(契約宣言済み failure、契約外の status/body、problem+json parse 失敗、実装の throw の分岐) |
| translation | 契約の型を生成する | 実行テスト(drift 検査の検証入口の判定) |
| translation | 生成型を型としてのみ使い、通信を port に通す | 構造検査(dependency-cruiser での runtime の import の検出)+型(import type) |
| connection | 効果を遅延した関数で表す | 構造検査(TypeScript compiler API。Effect が unique symbol の nominal brand を持ち、deferEffect だけが branded value を構築し、全ての公開 Effect factory に parameter initializer がなく、本体が実行用の関数リテラルを deferEffect へ直接渡すこと)+実行テスト(deferEffect の構築時は副作用0件で、返した Effect の呼出後にだけ開始すること)+型(Effect の nominal brand・環境・AbortSignal・wall-clock の絶対期限・ResultAsync のシグネチャ) |
| connection | 想定内失敗を Result で返す | 型(neverthrow の Result・判別子つき union) |
| connection | 非同期 API の送出を ResultAsync へ変換する | 構造検査(TypeScript compiler API。設定した Promise を返す境界 API の呼出しを、直後に呼ばれる `ResultAsync.fromThrowable` の関数リテラル内へ限定し、同期で throw し得る call expression を `ResultAsync.fromPromise` の第一引数へ渡す形を拒否)+実行テスト(関数呼出時の同期 throw と返した Promise の rejection を同じ mapper が Err にし、欠陥と AbortError は rejection のままになること) |
| connection | 同期 API の送出を Result へ変換する | 構造検査(TypeScript compiler API。設定した同期 DOM API と postMessage の呼出しを、直後に呼ばれる `Result.fromThrowable` の関数リテラル内へ限定)+実行テスト(同期の戻り値と throw、想定外の欠陥の再送出) |
| connection | 依存を環境で受け、host の能力を port で宣言する | 型(環境の型・ui port の型)+レビュー(singleton を作らないことの判断) |
| 全域 | cast allowlist | 構造検査(TypeScript compiler API。reporting boundary の型消去 symbol と検証を完結する converter または factory の型構築 symbol を別の allowlist として照合し、集合外と種類不一致の assertion/cast を拒否)+実行テスト(converter または factory が検証後だけ型を構築) |
| retention | 状態の機構 | レビュー(権威による remote/local と、local の寿命・共有範囲による URL/横断 UI/一時 UI の選択) |
| retention | remote の規律 | レビュー(local の横断 UI store への複製禁止の判断) |
| retention | 保存の禁止 | analyzer/lint(oxlint の no-restricted-properties で localStorage・sessionStorage の直呼びを禁止) |
| retention | extension の保持状態 | 型(state port・secret port)+レビュー |
| coordination | 非同期 | レビュー |
| coordination | 取り消し | 型(Effect 専用 withDeadlineEffect が ResultAsync<T, E &#124; DeadlineExceeded> を返すこと)+構造検査(TypeScript compiler API。設定に列挙した外部 I/O と待機の symbol と、callee expression の nominal brand または branded Effect への代入可能性で識別した下流 Effect を withDeadlineEffect の operation からだけ呼び、wrapper 内の window と document の直接参照を拒否すること)+実行テスト(host ごとの ResumeSource、wall-clock の絶対期限の伝播、非同期境界の前後と再開時の期限確認、購読解除後の判定、解決済み Err の保持と overrun 診断、期限 reason と同一または cause chain に持つ rejection の DeadlineExceeded Err 変換、wrapper 開始前から親取消と期限超過が同時に成立した場合に AbortSignal.any が選んだ親 reason の保持、別 defect の保持と期限超過診断、Ok 後の期限超過を DeadlineExceeded Err にすること、AbortSignal.timeout が active time の局所補助であること、親 signal と期限用 controller の AbortSignal.any 合成) |
| coordination | 並行の組 | 構造検査(TypeScript compiler API。Promise.all または Promise.allSettled に渡す並行 task collection を生成する箇所では、branded Effect を開始する withDeadlineEffect の呼出しを、project の ADR で固定した単一 limiter の需要枠 callback 内へ限定)+実行テスト(最初の Err と最初の rejection の各経路で abort、controller 由来の sibling cancellation rejection の除外、allSettled で全兄弟へ合流、rejection defect が無い場合は最初に観測した Err を Result で返すこと、Err と独立した rejection が同時に成立した場合は drain 後に rejection defect を優先して送出すること、実行中の Effect が ADR の上限を越えない最大同時実行数) |
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
検証の機械化と実行可能な仕様の検査経路は [verification](../../principles/verification.md)、構造を守る進化は [evolution](../../principles/evolution.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
