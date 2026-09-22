# StrykerJS

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、TypeScript は StrykerJS である。
判断基準は、採用しているテスト実行系と組んで mutant ごとのテストの絞り込みが効き、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、StrykerJS の report 形式の変化、採用しているテスト実行系との組で mutant の判定が変わること、実行系の最新の系と組める版の公開を再評価のトリガーとする。

## 有効性

### 要求
mutation は、StrykerJS で検査する。
機械可読な report の `totalUndetected` を gate にし、値が無い形式では `Survived` と `NoCoverage` の合計を gate にする。
検出されなかった mutant が一件でもあれば、検証入口を失敗で止める。
mutation score の正の threshold を、検出されなかった mutant 0件の gate の代わりにしない。
採用する StrykerJS とテスト実行系の版の組は、既知の欠陥を仕込んだ確認で mutant が検出側に数えられることを確かめてから固定する。
選んだテストを一件も実行しなかった mutant の実行は、未検出でも検出でもなく、検証入口を止める失敗として扱う。
変異の生成が 0 件の実行は、失敗として扱う。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
`Survived` と `NoCoverage` は、どちらもテストが検出していない変更である。
`totalUndetected` または両 status の合計を直接 gate にすれば、score の丸めや集約に判断を委ねず、未検出の変更が残っている事実で止められる。
正の score threshold は未検出 mutant を許す設定になり得るため、0件の完了条件を代替しない。
mutant ごとのテストの絞り込みが壊れると、検出できるはずの mutant が生存として数えられ、gate は通らないまま未検出の件数だけが増える。
選んだテストを一件も実行しなかった実行は、その mutant について何も確かめていないので、未検出として数えると原因を偽った gate になる。
変異が一件も生成されない実行は未検出の件数が 0 になり、gate を素通りする。

### 完了条件
mutation が StrykerJS で検査され、検出されなかった欠陥が潰されている。
report の `totalUndetected`、または `Survived` と `NoCoverage` の合計が、0件である。
検出されなかった mutant が一件でもあれば、検証入口が失敗している。
既知の欠陥を仕込んだ確認で、その mutant が検出側に数えられている。
選んだテストを一件も実行しなかった mutant の実行が、検証入口を失敗で止めている。
変異の生成件数が、1 件以上である。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
`Survived` だけを数え、`NoCoverage` を gate から除くこと。
検出されなかった mutant を、一件でも残したまま検証入口を通すこと。
mutation score の正の threshold を、検出されなかった mutant 0件の gate の代わりにすること。
mutant ごとのテストの絞り込みが効かない版の組で、mutation の結果を判定に使うこと。
選んだテストを一件も実行しなかった mutant の実行を、未検出または検出として数えること。
変異の生成が 0 件の実行を、合格として扱うこと。

### 行動
StrykerJS を回し、生き残った欠陥にテストを足す。
StrykerJS の機械可読な report から `totalUndetected` を読み、一件以上なら検証入口を終了コード非0で止める。
report に `totalUndetected` が無い場合は、`Survived` と `NoCoverage` の件数を合計し、一件以上なら検証入口を終了コード非0で止める。
StrykerJS とテスト実行系の版を上げるときは、既知の欠陥を仕込んだ確認で検出が成立することを確かめる。
各 mutant について、選んだテストの実行件数が 0 件なら失敗として止める。
変異の生成件数を読み、0 件なら止める。
絞り込みは、変異演算子と低リスク要素に限って検証入口に組む。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
