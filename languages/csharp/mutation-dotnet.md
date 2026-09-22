# mutation-dotnet

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、C# は mutation-dotnet であり、入手は mutation-dotnet と、その build が参照する上流 repository の、release タグが指す commit ID を固定した source build である。
判断基準は、採用している test の実行系のテストを preview でない経路で発見して実行し、テストが検出しなかった mutant を機械可読な結果で報告し、テストが一件も見つからない実行を非ゼロ終了で止められることであり、これらを同時に満たす他の機構が無いことである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、同じ用途と判断基準を満たす機構の出現、採用している .NET の版を target しなくなること、報告形式の変化を再評価のトリガーとする。

## 有効性

### 要求
mutation は、mutation-dotnet で検査する。
検証入口は mutation-dotnet を未検出 mutant 0 件の閾値で実行し、終了コードが 0 でなければ止める。
未検出の mutant は、報告の状態別件数のうち生存と未被覆の合計で数える。
変異の生成が 0 件の実行は、失敗として扱う。
mutation score の正の threshold を、未検出 mutant 0 件の gate の代わりにしない。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
mutation score は、検出した mutant を、検出した mutant と検出しなかった mutant の和で割った比である。
閾値を 100 に置くと、検出しなかった mutant が一件も無いという二値の床になる。
未被覆の mutant は検出しなかった側に入るため、生存だけを数えると gate が緩む。
変異が一件も生成されない実行は score が不在になり、閾値の判定を素通りする。
テストが一件も見つからない実行は、対象の中断として非ゼロ終了になる。

### 完了条件
mutation が mutation-dotnet で検査され、検出されなかった欠陥が潰されている。
報告の生存と未被覆の合計が、0 件である。
検証入口が未検出 mutant 0 件の閾値で実行され、終了コードが 0 である。
変異の生成件数が、1 件以上である。
テストが一件も見つからない実行が、検証入口を失敗で止めている。
mutation-dotnet の取得が、release タグが指す commit ID で固定されている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
生存だけを数え、未被覆を gate から除くこと。
検出されなかった mutant を、一件でも残したまま検証入口を通すこと。
mutation score の正の threshold を、未検出 mutant 0 件の gate の代わりにすること。
変異の生成が 0 件の実行を、合格として扱うこと。
変異演算子と低リスク要素の外へ絞り込みを広げ、母数から変異を外すこと。
mutation-dotnet の取得を、commit ID を固定しない参照で行うこと。

### 行動
mutation-dotnet と、その build が参照する上流 repository を、release タグが指す commit ID を固定して取得する。
mutation-dotnet を未検出 mutant 0 件の閾値で検証入口に組み、終了コードが 0 以外なら止める。
報告の状態別件数から生存と未被覆を読み、合計が 1 件以上なら止める。
変異の生成件数を読み、0 件なら止める。
生き残った欠陥に、テストを足す。
絞り込みは、変異演算子と低リスク要素に限って検証入口に組む。
