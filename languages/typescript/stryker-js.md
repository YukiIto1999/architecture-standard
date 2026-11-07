# StrykerJS

用途は、テストの検出力を評価し改善する mutation 分析である。
採用は、TypeScript は StrykerJS である。
判断基準は、採用しているテスト実行系と組んで mutant ごとのテストの絞り込みが効き、テストが検出しなかった mutant と分析の状態を機械可読な結果で報告できることである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、StrykerJS の report 形式の変化、採用しているテスト実行系との組で mutant の判定が変わること、実行系の最新の系と組める版の公開を再評価のトリガーとする。

## 有効性

### 要求
mutation は、StrykerJS で分析する。
分析の候補は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所から導く。
変更部分は、分析する変更の diff から行範囲を作り、`mutate` に `file:startLine-endLine` で渡す。
影響部分を分析する場合は、別に導いた範囲を `mutate` の対象指定へ含め、diff から作った変更行の範囲を影響部分の代わりにしない。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更から影響部分の候補を導く。
生成対象と各 mutant を観測する被覆テストの選択を分け、被覆テストの絞り込みで生成対象を狭めない。
検出されなかった mutant の件数は、機械可読な report の `totalUndetected` で数え、値が無い形式では `Survived` と `NoCoverage` の合計で数える。
採用する StrykerJS とテスト実行系の版の組は、既知の欠陥を仕込んだ確認で mutant が検出側に数えられることを確かめてから固定する。
被覆の確認でテストを選べなかった mutant は `NoCoverage` として未検出に数える。
被覆によって選んだテストがあるのに一件も実行しなかった場合は、未検出でも検出でもなく、分析の不成立として別に報告する。
初期 dry run でテストが一件も見つからなかった場合も、分析の不成立として報告し、検出にも未検出にも算入せず、製品の合否へ直結しない。
生成対象、除外、結果の分類と修正後の確認は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従い、実行と結果の取込は [process/verification](../../process/verification.md) に従う。

### 根拠
テストの検出力を mutation で分析する理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
`Survived` と `NoCoverage` は、どちらもテストが検出していない変更である。
`totalUndetected` または両 status の合計を直接数えれば、score の丸めや集約に判断を委ねず、未検出の変更が残っている事実を分類の入力にできる。
mutant ごとのテストの絞り込みが壊れると、検出できるはずの mutant が生存として数えられ、未検出の件数だけが増えて検出力の評価が歪む。
`NoCoverage` は未被覆という検証不足を示し、非空の選択集合を runner が実行しなかった障害とは原因が異なる。
`mutate` は変異を生成する対象の指定であり、diff から作る行範囲だけでは未変更の影響部分を選ばない。
実行時間には影響部分の分析、起動とテストの費用も含まれるため、変更行の数だけで所要時間を保証しない。

### 完了条件
分析した範囲が、`mutate` へ渡した変更部分と、影響部分を分析した場合はその対象指定とに分けて記録され、選ばなかった範囲が未分析として残っている。
未検出の mutant の件数が report の `totalUndetected`、または `Survived` と `NoCoverage` の合計で数えられ、型として成立しない変異と runner などによる不成立が検出件数へ加えられていない。
既知の欠陥を仕込んだ確認で、その mutant が検出側に数えられている。
未被覆の mutant が `NoCoverage` として未検出に数えられ、選んだテストがあるのに実行しなかった場合と初期 dry run のテスト未発見が分析の不成立として別に報告されている。
report と終了 status が生の値のまま保持されている。
生成対象、除外、結果の分類と修正後の確認が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
`Survived` だけを数え、`NoCoverage` を件数から除くこと。
mutant ごとのテストの絞り込みが効かない版の組で、mutation の結果を分類に使うこと。
被覆によって選んだテストがあるのに実行しなかった mutant と初期 dry run のテスト未発見を、未検出または検出として数えること。
`totalUndetected`、`Survived` と `NoCoverage` の合計、score だけを、製品の欠陥または承認の可否に読み替えること。
影響する箇所を未変更という理由で候補から外すことと、変更部分の結果で影響部分を分析済みとすること。
未確定の影響と関係のない保証も含む全量の分析を、変更ごとに繰り返すこと。

### 行動
変更入力から変更部分と影響部分の候補を導き、問いに応じて選んだ範囲を、diff から作る変更部分の行範囲と、別に導いた影響部分の範囲として `mutate` に渡し、StrykerJS を回す。
生成対象の選択と被覆テストの選択を別に確認する。
生成と結果の source と条件の同一性、選んだ範囲の生成と結果の記録の状態を確認する。
影響する既存証跡を無効化し、影響しない証跡は [process/verification](../../process/verification.md) の同一性が成立する間再利用する。
StrykerJS の機械可読な report から `totalUndetected` を読み、無い場合は `Survived` と `NoCoverage` の件数を合計して、report と終了 status を生の値のまま保持し、分類の入力に渡す。
StrykerJS とテスト実行系の版を上げるときは、既知の欠陥を仕込んだ確認で検出が成立することを確かめる。
各 mutant について、被覆の確認からテストの選択と実行までを照合し、未被覆と runner の未実行を分けて報告し、初期 dry run のテスト未発見も分析の不成立として報告する。
対象と絞り方、結果の分類と修正後の確認は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従う。

## 参照
- [StrykerJS Configuration](https://stryker-mutator.io/docs/stryker-js/configuration/) の `coverageAnalysis` と `allowEmpty`。
