# cargo-mutants

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、Rust は cargo-mutants である。
判断基準は、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Stryker.NET の MTP test runner の preview status、TUnit との互換性、StrykerJS の report 形式の変化を再評価のトリガーとする。

## 有効性

### 要求
mutation は cargo-mutants で検査し、検出されなかった mutant が一件でもあれば検証入口を失敗させる。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
アサーションが弱いと、カバレッジが高くても欠陥が生き残る。
cargo-mutants は生存した mutant の有無を exit code で報告するので、しきい値は「検出されない mutant が無い」という二値の床になる。

### 完了条件
mutation が cargo-mutants で検査され、生き残った欠陥が潰されている。
検出されなかった mutant が一件でもあれば、検証入口が失敗で止まっている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
結果が揺れるテストの上で、mutation を測ること。
生存した mutant を、しきい値の緩和や無視で見逃すこと。

### 行動
安定したテストの土台の上で cargo-mutants を回し、生き残った欠陥にテストを足す。
絞り込みは変異演算子と低リスク要素(参照データ表・等価変異)に限り、cargo-mutants を検証入口に組んで失敗で止める。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
