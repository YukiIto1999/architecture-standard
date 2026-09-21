# StrykerJS

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、TypeScript は StrykerJS である。
判断基準は、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Stryker.NET の MTP test runner の preview status、TUnit との互換性、StrykerJS の report 形式の変化を再評価のトリガーとする。

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
