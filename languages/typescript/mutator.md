# mutator

用途は、テストの検出力を評価し改善する mutation 分析である。
採用は、TypeScript は @mizchi/mutator である。
判断基準は、[vite-plus](./vite-plus.md) が同梱する Vitest で mutant ごとに被覆テストを絞って実行し、変更の diff とテストの変更から分析する mutant を選び、関数と被覆テストが変わらない mutant の判定を継承し、テストが検出しなかった mutant と分析の状態を機械可読な report で報告できることである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、`vite-plus` が同梱する Vitest の major に対応する版の欠如、report 形式と snapshot の互換の変化、採用している版の組で mutant の判定またはテストの変更による検出の低下の報告が変わることを再評価のトリガーとする。

## 有効性

### 要求
mutation は、`vite-plus` が同梱する Vitest を runner とする @mizchi/mutator で分析する。
@mizchi/mutator は project の devDependency に置いて版を manifest と lockfile に記録し、環境はその `engines` を満たす Node.js を供給する。
分析の候補は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所から導き、生成対象は `include` と `exclude` で production の source に指定する。
変更部分は、比較元を `--since` に渡す実行で選び、diff にテストの変更を含む場合は `--include-test-changes` を加える。
影響部分を分析する場合は、build graph が導く影響する project の source を `include` に指定し、`--since` を付けない別の実行で、前回の snapshot から継承できない mutant を再判定して選び、diff で選んだ変更部分の結果を影響部分の代わりにしない。
テストの変更が届く mutant は、比較元の source に対して同じ `include` の範囲で書いた snapshot と比べる。
間にテストの変更後の source で別の実行が snapshot を更新した report と、`comparison` が `unavailable` の report では、比較を未分析として記録する。
mutator が照合しない入力の変更が届く mutant は道具が選べない影響部分とし、届く範囲は前回の snapshot を読まない実行で再判定するか未分析として記録する。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更が届く影響部分を、上の選択か未分析の記録へ割り当てる。
道具が選べない影響部分は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従って未分析として関係とともに記録し、mutator の実装課題として扱う。
生成対象と各 mutant を観測する被覆テストの選択を分け、被覆テストの絞り込みで生成対象を狭めない。
変異の型検査は `typecheck` を `true` にして行い、型検査器を解決できず終了した実行を分析の不成立として報告する。
`json` reporter の report の status は生の値のまま保持し、`Survived` と `NoCoverage` の合計をそのまま未検出として分類に渡さない。
未検出に数えるのは、被覆の確認が成立した `NoCoverage` と、被覆テストの実行を確かめて検出されなかった `Survived` である。
`Pending` は、`statusReason` に範囲外の再判定の結果を持つものを `detectionRegression` の finding とともに読み、それ以外を、`--since` の範囲外は選ばなかった範囲、`--time-budget` と `--mutants-per-line` が実行しなかったものは選んだ範囲の未判定として、text の要約の内訳とともに記録する。
report の `statusReason` が `possibly reached in a child process` を示す変異は、`Pending` として報告された範囲外の再判定を含め、変異を観測できない範囲として別に記録し、未検出に数えない。
runner が変更したテスト file を収集しない warning、テストがどの mutant にも到達しない warning、dry run が見つけたテスト file が 0 件の実行は、分析の不成立として報告し、その実行の未検出の件数を分類の入力にしない。
mutator は被覆によって選んだテストを一件も実行しなかった mutant を `Survived` と報告して report で区別しない。
観測できない範囲を除いた `Survived` を分類するには、`coveredBy` と runner の収集結果から、mutant に到達するテストを特定する。
`coveredBy` だけで選択を確定できない場合は、runner の収集結果と実行の観測から到達するテストを特定する。
module の読み込み時に評価される変異は、その module の読み込みを観測する。
変異の差分だけを隔離した入力で、特定したテストの実行と結果を [structure/tests/methods](../../structure/tests/methods.md) の「テストの有効性」に従って確かめる。
実行して失敗しなかったことを確かめた `Survived` だけを未検出に数え、runner がそのテストを実行しなかった mutant は分析の不成立として、確かめていない mutant は実行未確認として、検出にも未検出にも数えない。
`detectionRegression` は、同じ変異を比較でき、今回の結果を未検出に数えられると確かめたときだけ、検出の低下と判定する。
検出の維持は、同じ変異が比較元と現在の両方で検出された証拠から判定する。
同じ変異を比較できない場合と、今回の観測が成立しない場合は、その理由を記録して低下も維持も確定しない。
この区別を mutator の実装課題として記録し、採用する版の組を下の確認で固定する。
等価変異と契約内の観測差の判断は、[structure/tests/methods](../../structure/tests/methods.md) の「テストの有効性」の分類の記録に残し、`mutator accept` で report の status を書き換えない。
`thresholds.break`、`failOnSurvived`、`critical` を設定せず、終了 status を分析の状態だけに使う。
T3b の時間枠は [process/verification](../../process/verification.md) に従い、`--time-budget` を枠の内側に置き、枠で取り消した走行は report の無い未完了として記録する。
採用する @mizchi/mutator と `vite-plus` の版の組は、既知の欠陥を仕込んだ確認で mutant が検出側に数えられ、テストだけを弱めた差分で以前検出した mutant が `detectionRegression` として報告されることを確かめてから固定する。
report、text の要約、log と終了 status は生の値のまま保持する。
生成対象、除外、結果の分類と修正後の確認は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従い、実行と結果の取込は [process/verification](../../process/verification.md) に従う。

### 根拠
テストの検出力を mutation で分析する理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
被覆の確認が成立した `NoCoverage` は、変異を覆うテストがなく検出できなかったことを示す。
mutator は mutant ごとの被覆テストの実行件数を報告しないため、`Survived` は被覆するテストを実行して失敗しなかった mutant と、選んだテストを runner が実行しなかった mutant の両方を含み、status だけではテストが検出しなかった変更と分析の不成立を分けられない。
module の読み込みで評価される変異に対し、runner が実行したテストは `coveredBy` に無いことがある。
範囲外の再判定では、JSON reporter は `coveredBy` を空にする。
変異の差分だけを隔離した入力で被覆テストを runner に実行させれば、その mutant についてテストの実行と結果を観測できる。
`--since` は diff に触れる mutant だけを実行して報告し、変更したテストが被覆する未変更の mutant を選ばないため、テストの編集で検出しなくなった mutant を見落とす。
例外として、以前の検出テストがすべて削除または改名された範囲外の mutant は再判定され、report では `Pending` の status と再判定の結果を持つ `statusReason` で示される。
`--include-test-changes` は、追加、編集、削除したテストが被覆または import する mutant を選択に加え、互換な snapshot がある場合だけ、以前 `Killed` で関数の変わらない mutant が `Survived` か `NoCoverage` になったことを `detectionRegression` として報告する。
互換な snapshot が無い report の `comparison` は `unavailable` であり、検出が維持された証拠にならない。
比較の基準は直前に snapshot を書いた実行であり、テストの変更後の source で `--include-test-changes` を付けない `--since` の実行が snapshot を書くと、以前の `Killed` の判定と変更前のテストの fingerprint が置き換わり、低下が `detectionRegression` として報告されない。
mutator は、mutant を囲む関数の hash と、被覆テストの fingerprint(テスト file とそれが import する local file)が変わらない mutant の判定を継承し、変更した関数を実行したテストが被覆する mutant を再判定する。
Node.js の版、manifest と lockfile、`tsconfig.json`、runner の設定、変異の設定のいずれかが変わると snapshot 全体を継承しないため、依存と設定の変更は届く範囲の全 mutant の再判定になる。
これら以外の入力(環境変数、import を経ずに読む file など)は照合せず、継承を止める option も無いため、その変更が届く mutant の継承した判定は現在の source の分析結果にならない。
`typecheck` が `auto` の場合は、型検査器を解決できなければ型として成立しない変異をテストで実行し、検出か未検出に数える。
変異の型検査は project が `typescript` として解決する compiler で行うため、[typescript-compiler-api](./typescript-compiler-api.md) の alias の下では6系の compiler API が判定し、変異した file の診断だけを比べるので他の file にだけ誤りが出る変異は実行される。
変異を memory 上で適用するため、テストが子 process で実行する source の変異は観測されない。
`mutator accept` は記録した mutant を以後の report で `Ignored` に変え、道具が返した未検出の status を report から除く。
品質 gate は score、生存した mutant、`critical` の範囲の未検出を終了 status 2 へ写し、分析の状態と承認の条件を同じ値に混ぜる。
`--time-budget` は新しい mutant の型検査と実行を止めて残りを `Pending` とし、実行中の run は完了させる。
実行時間には影響部分の分析、起動とテストの費用も含まれるため、変更行の数だけで所要時間を保証しない。

### 完了条件
分析した範囲が、`--since` による変更部分と、影響部分を分析した場合は `--since` なしの実行で再判定した mutant と継承した結果とに分けて記録され、選ばなかった範囲、`Pending` の未判定、道具が選べない影響部分が残っている。
テストの変更が届く mutant について、比較元の snapshot に対する判定とその根拠が記録され、比較不能と観測不能が検出の低下および維持から分けられている。
report の生の status が保持され、未検出の件数には被覆の確認が成立した `NoCoverage` と実行を確かめて検出されなかった `Survived` だけが含まれる。
分類に使う結果が、`typecheck` を `true` にした実行のものである。
変更したテスト file の未収集、mutant に到達しないテスト、dry run のテスト file 0 件は分析の不成立として報告され、子 process で到達しうる変異の観測不能は未検出と分けて記録されている。
等価変異と契約内の観測差の判断が分類の記録にあり、`mutator accept` による status の書換えが無い。
品質 gate の設定が無く、report、text の要約、log と終了 status が生の値のまま保持されている。
既知の欠陥を仕込んだ確認でその mutant が検出側に数えられ、テストだけを弱めた差分で以前検出した mutant が `detectionRegression` として報告されている。
生成対象、除外、結果の分類と修正後の確認が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
観測不能な `NoCoverage` または `Survived` と、被覆テストを実行したことを確かめていない `Survived` を、未検出または検出の低下として扱うこと。
被覆の確認が成立した `NoCoverage` を未検出から除くこと。
`--since` だけの実行で、影響部分と、変更したテストが被覆する mutant の検出の維持を分析済みとすること。
`detectionRegression` の finding が無いことだけを、検出が維持された証拠とすること。
mutator が照合しない入力の変更の後に、その変更が届く範囲の継承した判定を現在の分析結果とすること。
型検査を省いた実行の結果を、分類に使うこと。
`mutator accept` で未検出の mutant の status を書き換えることと、品質 gate で未検出や score を終了 status の失敗へ写すこと。
未検出の件数、score、終了 status だけを、製品の欠陥または承認の可否に読み替えること。
影響する箇所を未変更という理由で候補から外すこと。
未確定の影響と関係のない保証も含む全量の分析を、変更ごとに繰り返すこと。

### 行動
@mizchi/mutator を devDependency に加え、`vite-plus` が同梱する Vitest を runner とし、`typecheck` を `true`、reporter を `text` と `json` にして実行する。
問いに応じて変更部分、影響部分、またはその両方を選び、変更部分は `mutator --since <基点>` で、テストの変更を含む diff では `--include-test-changes` を加えて試す。
影響部分は、build graph が導く影響する project の source を `--include` に渡し、`--since` を付けない別の実行で試す。
mutator が照合しない入力を変えた後は、届く範囲を `.mutator/` を持たない作業木で `--shared-cache` を付けずに再判定するか、継承した判定を未分析として残す。
生成対象の選択と被覆テストの選択を別に確認する。
比較元の snapshot と現在の変異の同一性と判定を照合し、低下と維持をそれぞれ該当する証拠から記録する。
report の status と生の件数を保持し、warning と `statusReason` から分析の不成立と子 process の範囲を先に分ける。
残る `NoCoverage` の被覆の確認が成立しているかを判定する。
残る `Survived` は、特定できたテストで変異を再実行して結果を確かめ、テストを特定できないものは実行未確認に残す。
text の要約から `Pending` の内訳を読む。
影響する既存証跡を無効化し、影響しない証跡は [process/verification](../../process/verification.md) の同一性が成立する間再利用する。
@mizchi/mutator と `vite-plus` の版を上げるときは、既知の欠陥を仕込んだ確認と、テストだけを弱めた差分の確認を行う。
report、text の要約、log と終了 status を生の値のまま保持し、対象と絞り方、結果の分類と修正後の確認は [structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従う。

## 参照
- [mutator README](https://github.com/mizchi/mutator/blob/v0.5.3/README.md) の `--since`、`--include-test-changes`、Type checking、Vite+ (vite-plus)。
- [mutator Reports](https://github.com/mizchi/mutator/blob/v0.5.3/packages/cli/skills/mutator/references/reports.md) の status、warning と `comparison`。
- [mutator JSON reporter](https://github.com/mizchi/mutator/blob/v0.5.3/packages/cli/src/mte-report.ts) の `statusReason` と範囲外の再判定の記録。
- [mutator Configuration](https://github.com/mizchi/mutator/blob/v0.5.3/packages/cli/skills/mutator/references/config.md) の `typecheck`、`timeBudget` と品質 gate。
- [mutator reuse](https://github.com/mizchi/mutator/blob/v0.5.3/packages/cli/src/reuse.ts) の snapshot の互換の条件。
- [mutator planner](https://github.com/mizchi/mutator/blob/v0.5.3/packages/core/src/plan.ts) と [tally](https://github.com/mizchi/mutator/blob/v0.5.3/packages/cli/src/tally.ts) の読み込み時に評価される変異のテスト選択と被覆の記録。
- [mutator test impact](https://github.com/mizchi/mutator/blob/v0.5.3/packages/cli/src/test-impact.ts) のファイル、変異の識別、関数の hash による検出の低下の比較。
