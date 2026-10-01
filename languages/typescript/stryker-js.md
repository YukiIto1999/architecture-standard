# StrykerJS

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、TypeScript は StrykerJS である。
判断基準は、採用しているテスト実行系と組んで mutant ごとのテストの絞り込みが効き、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、StrykerJS の report 形式の変化、採用しているテスト実行系との組で mutant の判定が変わること、実行系の最新の系と組める版の公開を再評価のトリガーとする。

## 有効性

### 要求
mutation は、StrykerJS で検査する。
変更ごとの検査は、push する範囲の diff から変更した行の範囲を作り、`mutate` に `file:startLine-endLine` で渡して実行する。
検出されなかった mutant の件数は、機械可読な report の `totalUndetected` で数え、値が無い形式では `Survived` と `NoCoverage` の合計で数える。
採用する StrykerJS とテスト実行系の版の組は、既知の欠陥を仕込んだ確認で mutant が検出側に数えられることを確かめてから固定する。
選んだテストを一件も実行しなかった mutant の実行は、未検出でも検出でもなく、検証入口を止める失敗として扱う。
変更ごとの検査と全量の実行の合否、対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
`Survived` と `NoCoverage` は、どちらもテストが検出していない変更である。
`totalUndetected` または両 status の合計を直接数えれば、score の丸めや集約に判断を委ねず、未検出の変更が残っている事実で判定できる。
mutant ごとのテストの絞り込みが壊れると、検出できるはずの mutant が生存として数えられ、gate は通らないまま未検出の件数だけが増える。
選んだテストを一件も実行しなかった実行は、その mutant について何も確かめていないので、未検出として数えると原因を偽った gate になる。
`mutate` の行範囲で変更した行だけを変異させれば、変更ごとの検査が変更の量に応じた時間で終わる。

### 完了条件
変更した行の mutant が、`mutate` の行範囲で StrykerJS に検査されている。
検出されなかった mutant の件数が、report の `totalUndetected`、または `Survived` と `NoCoverage` の合計で数えられている。
既知の欠陥を仕込んだ確認で、その mutant が検出側に数えられている。
選んだテストを一件も実行しなかった mutant の実行が、検証入口を失敗で止めている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
`Survived` だけを数え、`NoCoverage` を件数から除くこと。
mutant ごとのテストの絞り込みが効かない版の組で、mutation の結果を判定に使うこと。
選んだテストを一件も実行しなかった mutant の実行を、未検出または検出として数えること。
変更ごとの検査で、変更した行の範囲を `mutate` に渡さず全量を実行すること。

### 行動
push する範囲の diff から変更した行の範囲を作って `mutate` に渡し、StrykerJS を変更ごとの検証入口で回し、生き残った欠陥にテストを足す。
StrykerJS の機械可読な report から `totalUndetected` を読み、無い場合は `Survived` と `NoCoverage` の件数を合計して、件数を合否の判定に渡す。
StrykerJS とテスト実行系の版を上げるときは、既知の欠陥を仕込んだ確認で検出が成立することを確かめる。
各 mutant について、選んだテストの実行件数が 0 件なら失敗として止める。
絞り込みは、変異演算子と低リスク要素に限る。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
