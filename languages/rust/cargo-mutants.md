# cargo-mutants

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、Rust は cargo-mutants である。
判断基準は、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、生存した mutant の機械可読な報告または非ゼロ終了の廃止を再評価のトリガーとする。

## 有効性

### 要求
mutation は、cargo-mutants で検査する。
変更ごとの検査は、push する範囲の `git diff` を file に保存し、その file を `--in-diff` に渡して、変更した行に重なる mutant だけを試す。
検出されなかった mutant の有無は、cargo-mutants の終了コードで判定する。
baseline のテストが走らない実行は、失敗として扱う。
変更ごとの検査と全量の実行の合否、対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
アサーションが弱いと、カバレッジが高くても欠陥が生き残る。
cargo-mutants は検出されなかった mutant の有無を exit code で報告するので、report を読み直さずに合否を判定できる。
`--in-diff` は diff の変更範囲に重なる mutant だけを試すので、変更ごとの検査が変更の量に応じた時間で終わる。
baseline のテストが走らない実行は、mutant を一件も試していない。

### 完了条件
変更した行の mutant が、保存した diff を渡した `--in-diff` で検査されている。
検出されなかった mutant の有無が、cargo-mutants の終了コードで判定されている。
baseline のテストが走らない実行が、検証入口を失敗で止めている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
結果が揺れるテストの上で、mutation を測ること。
終了コードを読まず、cargo-mutants の表示だけで合否を判断すること。
diff を `--in-diff` に渡さず、変更ごとの検査で全量を実行すること。

### 行動
安定したテストの土台の上で cargo-mutants を回し、生き残った欠陥にテストを足す。
push する範囲の `git diff` を file に保存し、`cargo mutants --in-diff <保存した file>` を変更ごとの検証入口に組み、終了コードが 0 以外なら止める。
絞り込みは、変異演算子と低リスク要素(参照データ表・等価変異)に限る。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
