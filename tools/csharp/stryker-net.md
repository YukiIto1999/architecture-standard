# Stryker.NET

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、C# は Stryker.NET の MTP runner(preview)である。
判断基準は、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Stryker.NET の MTP test runner の preview status、TUnit との互換性、StrykerJS の report 形式の変化を再評価のトリガーとする。

## 有効性

### 要求
mutation は、テストが振る舞いを本当に固定しているかを人工の欠陥注入で測る。これを Stryker.NET で満たす。
Stryker.NET の test-runner は mtp に設定し、TUnit のテストを発見させる。
テストの発見件数を検証入口で検査し、0 件なら失敗として扱う。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
Stryker.NET の既定の test-runner は vstest で、TUnit は Microsoft.Testing.Platform 専用のため既定では接続せず、テストの発見が 0 件のまま mutation が空転する。
test-runner を mtp に設定すれば、TUnit のテストを発見して mutation を実行できる。

### 完了条件
mutation が Stryker.NET で検査され、生き残った欠陥が潰されている。
mutation の実行が、テストを発見して走っている。
テストの発見が 0 件のとき、失敗として扱われている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
test-runner を既定の vstest のまま TUnit と組み合わせ、テストの発見が 0 件のまま mutation を空転させること。
テストの発見が 0 件のまま、mutation の結果を合格として扱うこと。

### 行動
Stryker.NET の test-runner を mtp に設定し、TUnit のテストを発見させる。
テストの発見件数を検査し、0 件なら検証入口を失敗させる。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
