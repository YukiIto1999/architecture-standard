# cargo-mutants

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、Rust は cargo-mutants である。
判断基準は、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、生存した mutant の機械可読な報告または非ゼロ終了の廃止を再評価のトリガーとする。

## 有効性

### 要求
mutation は、cargo-mutants で検査する。
変更ごとの生成対象は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所の和集合にする。
変更部分は push する範囲の `git diff` を file に保存し、その file を `--in-diff` に渡して選ぶ。
影響部分は採用版が受け付ける対象指定を使う別の実行として検証入口へ組み込み、`--in-diff` の変更行の制限で対象から落とさない。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更から影響部分を選ぶ。
生成対象と各 mutant を観測するテスト群の選択を分け、被覆テストの絞り込みで生成対象を狭めない。
検出されなかった mutant の有無は cargo-mutants の終了コードで判定し、生成対象全体の完了と実行可能な mutant の検出を report で確認する。
baseline のテストが正常に実行された証跡を確認し、実行 0 件、失敗または証跡の欠落は検証入口を止める。
同一の source と検証入力に対する有効な成功証跡がある場合だけ baseline を省略でき、証跡の同一性は [process/verification](../../process/verification.md) に従う。
生成対象、除外と合否は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
アサーションが弱いと、カバレッジが高くても欠陥が生き残る。
cargo-mutants の exit code は実行の合否に使い、対象の生成件数、実行成立、未検出と compile 不能の内訳は report で確認する。
`--in-diff` は変更部分の対象選択に使い、影響部分を自動で選ぶ機能とはみなさない。
実行時間には影響部分の検査、build とテストの費用も含まれるため、変更行の数だけで所要時間を保証しない。
baseline の省略は mutant の未実行を意味せず、cargo-mutants は `--baseline=skip` でも変異を試す。
baseline の command の成功だけでは実行テスト件数を保証できないため、project の入口で test runner の実行証跡も確認する。

### 完了条件
変更部分が保存した diff を渡した `--in-diff` で検査され、影響部分も別に選ばれて検査されているか、有効な同一検査の証跡で覆われている。
各実行の終了コードと report から、生成対象全体の完了、未検出、型として成立しない変異と runner などによる未完了を区別できている。
正常に実行された baseline の成功証跡があり、再利用時は検査入力の同一性が確認されている。
baseline の実行 0 件、失敗または有効な証跡の欠落が、検証入口を失敗で止めている。
生成対象、除外と合否が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
結果が揺れるテストの上で、mutation を測ること。
終了コードを読まず、cargo-mutants の表示だけで合否を判断すること。
影響する箇所を未変更という理由で生成対象から外すことと、変更部分の成功で影響部分の検査を代替すること。
未確定の影響と関係のない保証も含む全量を繰り返すこと。

### 行動
安定したテストの土台の上で cargo-mutants を回し、生き残った欠陥にテストを足す。
変更入力から生成対象の変更部分と影響部分を計画し、変更部分の `git diff` を file に保存して `cargo mutants --in-diff <保存した file>` で試す。
影響部分は採用版で扱える対象指定を別に使って試し、各実行の終了コードが 0 以外なら検証入口を止める。
生成と判定の source と条件の同一性、生成対象全体の生成件数、実行成立と判定の内訳を report で確認し、対象指定や判定の不足を変更部分の成功で補わない。
影響する既存証跡を無効化し、影響しない証跡は [process/verification](../../process/verification.md) の同一性が成立する間再利用する。
影響範囲として選んだ mutation の対象内での除外は、変異演算子と低リスク要素(参照データ表・等価変異)に限る。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
