# cargo-mutants

用途は、テストの検出力を評価し改善する mutation 分析である。
採用は、Rust は cargo-mutants である。
判断基準は、テストが検出しなかった mutant と分析の状態を、機械可読な結果と終了コードで報告できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、生存した mutant の機械可読な報告または非ゼロ終了の廃止を再評価のトリガーとする。

## 有効性

### 要求
mutation は、cargo-mutants で分析する。
分析の候補は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所から導く。
変更部分は、分析する変更の `git diff` を file に保存し、その file を `--in-diff` に渡して選ぶ。
影響部分を分析する場合は、採用版が受け付ける対象指定を使う別の実行にし、`--in-diff` の変更行の制限で影響の候補から落とさない。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更から影響部分の候補を導く。
生成対象と各 mutant を観測するテスト群の選択を分け、被覆テストの絞り込みで生成対象を狭めない。
検出されなかった mutant の有無は cargo-mutants の終了コードと report で読み、終了コードは生の値のまま保存する。
baseline のテストが正常に実行された証跡を確認し、baseline の実行 0 件、失敗または証跡の欠落は分析の不成立として報告し、製品の合否へ直結しない。
同一の source と検証入力に対する有効な成功証跡がある場合だけ baseline を省略でき、証跡の同一性は [process/verification](../../process/verification.md) に従う。
生成対象、除外、結果の分類と修正後の確認は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従い、実行と結果の取込は [process/verification](../../process/verification.md) に従う。

### 根拠
テストの検出力を mutation で分析する理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
アサーションが弱いと、カバレッジが高くても欠陥が生き残る。
cargo-mutants の終了コードは分析の状態として保存し、対象の生成件数、実行成立、未検出と compile 不能の内訳は report で読む。
`--in-diff` は変更部分の対象選択に使い、影響部分を自動で選ぶ機能とはみなさない。
実行時間には影響部分の分析、build とテストの費用も含まれるため、変更行の数だけで所要時間を保証しない。
baseline の省略は mutant の未実行を意味せず、cargo-mutants は `--baseline=skip` でも変異を試す。
baseline の command の成功だけでは実行テスト件数を保証できないため、project の入口で test runner の実行証跡も確認する。

### 完了条件
分析した範囲が、保存した diff を渡した `--in-diff` による変更部分と、影響部分を分析した場合はその対象指定とに分けて記録され、選ばなかった範囲が未分析として残っている。
各実行の終了コードが生の値のまま保存され、終了コードと report から、選んだ範囲の生成、未検出、Rust の構文や型として成立しない変異と runner などによる不成立を区別できている。
正常に実行された baseline の成功証跡があり、再利用時は検査入力の同一性が確認されている。
baseline の実行 0 件、失敗または有効な証跡の欠落が、分析の不成立として記録されている。
生成対象、除外、結果の分類と修正後の確認が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
結果が揺れるテストの上で、mutation を分析すること。
終了コードと report を読まず、cargo-mutants の表示だけで分析結果を判断すること。
非ゼロの終了コードや未検出の件数だけを、製品の欠陥または承認の可否に読み替えること。
影響する箇所を未変更という理由で候補から外すことと、変更部分の結果で影響部分を分析済みとすること。
未確定の影響と関係のない保証も含む全量の分析を、変更ごとに繰り返すこと。

### 行動
安定したテストの土台の上で cargo-mutants を回し、検出されなかった mutant を分類して、検査の不足なら必要な振る舞いの検査を足す。
変更入力から変更部分と影響部分の候補を導き、問いに応じて選んだ範囲のうち、変更部分は `git diff` を file に保存して `cargo mutants --in-diff <保存した file>` で試す。
影響部分は採用版で扱える対象指定を別に使って試す。
選んだ範囲の終了コード、report、baseline の証跡を保存し、生成と結果の source と条件の同一性、生成件数、実行成立と未検出の内訳を report で確認する。
採用版で対象指定や集計を扱えない範囲は、未分析として明示し、存在しない flag や API を仮定せず、変更部分の結果で補わない。
影響する既存証跡を無効化し、影響しない証跡は [process/verification](../../process/verification.md) の同一性が成立する間再利用する。
対象の選び方と結果の分類は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
