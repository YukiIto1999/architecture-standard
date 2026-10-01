# mutation-dotnet

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、C# は mutation-dotnet であり、入手は mutation-dotnet と、その build が参照する上流 repository の、release タグが指す commit ID を固定した source build である。
判断基準は、採用している test の実行系のテストを発見して実行し、その実行で mutant の判定が再現し、テストが検出しなかった mutant を機械可読な結果で報告し、テストが一件も見つからない実行を非ゼロ終了で止められることであり、これらを同時に満たす他の機構が無いことである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、同じ用途と判断基準を満たす機構の出現、採用している .NET の版を target しなくなること、報告形式の変化を再評価のトリガーとする。

## 有効性

### 要求
mutation は、mutation-dotnet で検査する。
変更ごとの検査は、`--since` に push する範囲の比較の基点を渡して変更した file に絞って実行し、`mutation-report.json` から変更した行に位置する mutant を取り出す。
未検出の mutant は、報告の状態別件数のうち生存と未被覆の合計で数える。
変更ごとの検査と全量の実行の合否、対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
未被覆の mutant は検出しなかった側に入るため、生存だけを数えると未検出の件数が少なく出る。
`--since` は file の単位で絞るので、変更した行の判定は report の mutant の位置で行う。
テストが一件も見つからない実行は、対象の中断として非ゼロ終了になる。

### 完了条件
変更した行の mutant が、`--since` で絞った mutation-dotnet の実行の report から取り出されている。
未検出の mutant が、報告の生存と未被覆の合計で数えられている。
テストが一件も見つからない実行が、検証入口を失敗で止めている。
mutation-dotnet の取得が、release タグが指す commit ID で固定されている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
生存だけを数え、未被覆を未検出の件数から除くこと。
変更ごとの検査で、変更した行の外の mutant の結果を合否に混ぜること。
変異演算子と低リスク要素の外へ絞り込みを広げ、母数から変異を外すこと。
mutation-dotnet の取得を、commit ID を固定しない参照で行うこと。

### 行動
mutation-dotnet と、その build が参照する上流 repository を、release タグが指す commit ID を固定して取得する。
mutation-dotnet を `--since` で変更した file に絞って変更ごとの検証入口に組み、report から変更した行の mutant を取り出す。
変更した行の mutant の生存と未被覆の合計を、合否の判定に渡す。
生き残った欠陥に、テストを足す。
絞り込みは、変異演算子と低リスク要素に限る。
