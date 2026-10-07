# StrykerJS

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、TypeScript は StrykerJS である。
判断基準は、採用しているテスト実行系と組んで mutant ごとのテストの絞り込みが効き、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、StrykerJS の report 形式の変化、採用しているテスト実行系との組で mutant の判定が変わること、実行系の最新の系と組める版の公開を再評価のトリガーとする。

## 有効性

### 要求
mutation は、StrykerJS で検査する。
変更ごとの生成対象は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所の和集合にする。
変更部分は push する範囲の diff から行範囲を作り、`mutate` に `file:startLine-endLine` で渡す。
影響部分も別に導いた範囲を `mutate` の対象指定へ含め、diff から作った変更行の範囲だけで検査しない。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更から影響部分を選ぶ。
生成対象と各 mutant を観測する被覆テストの選択を分け、被覆テストの絞り込みで生成対象を狭めない。
検出されなかった mutant の件数は、機械可読な report の `totalUndetected` で数え、値が無い形式では `Survived` と `NoCoverage` の合計で数える。
採用する StrykerJS とテスト実行系の版の組は、既知の欠陥を仕込んだ確認で mutant が検出側に数えられることを確かめてから固定する。
被覆の確認でテストを選べなかった mutant は `NoCoverage` として未検出に数える。
被覆によって選んだテストがあるのに一件も実行しなかった場合は、未検出でも検出でもなく、検証入口を止める失敗として扱う。
生成対象、除外と合否は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
`Survived` と `NoCoverage` は、どちらもテストが検出していない変更である。
`totalUndetected` または両 status の合計を直接数えれば、score の丸めや集約に判断を委ねず、未検出の変更が残っている事実で判定できる。
mutant ごとのテストの絞り込みが壊れると、検出できるはずの mutant が生存として数えられ、gate は通らないまま未検出の件数だけが増える。
`NoCoverage` は未被覆という検証不足を示し、非空の選択集合を runner が実行しなかった障害とは原因が異なる。
`mutate` は変異を生成する対象の指定であり、diff から作る行範囲だけでは未変更の影響部分を選ばない。
実行時間には影響部分の検査、起動とテストの費用も含まれるため、変更行の数だけで所要時間を保証しない。

### 完了条件
変更部分と影響部分の和集合が `mutate` の対象指定で検査されているか、有効な同一検査の証跡で覆われている。
検出されなかった mutant の件数が report の `totalUndetected`、または `Survived` と `NoCoverage` の合計で数えられ、型として成立しない変異と runner などによる未完了が検出件数へ加えられていない。
既知の欠陥を仕込んだ確認で、その mutant が検出側に数えられている。
未被覆の mutant が `NoCoverage` として未検出に数えられ、選んだテストがあるのに実行しなかった場合は検証入口を失敗で止めている。
生成対象、除外と合否が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
`Survived` だけを数え、`NoCoverage` を件数から除くこと。
mutant ごとのテストの絞り込みが効かない版の組で、mutation の結果を判定に使うこと。
被覆によって選んだテストがあるのに実行しなかった mutant を、未検出または検出として数えること。
影響する箇所を未変更という理由で生成対象から外すことと、変更部分の成功で影響部分の検査を代替すること。
未確定の影響と関係のない保証も含む全量を繰り返すこと。

### 行動
変更入力から生成対象の変更部分と影響部分を計画し、diff から作る変更部分の行範囲と、別に導いた影響部分の範囲を `mutate` に渡して StrykerJS を検証入口で回す。
生成対象の選択と被覆テストの選択を別に確認し、生き残った欠陥にテストを足す。
生成と判定の source と条件の同一性、生成対象全体の生成と判定の完了を確認する。
影響する既存証跡を無効化し、影響しない証跡は [process/verification](../../process/verification.md) の同一性が成立する間再利用する。
StrykerJS の機械可読な report から `totalUndetected` を読み、無い場合は `Survived` と `NoCoverage` の件数を合計して、件数を合否の判定に渡す。
StrykerJS とテスト実行系の版を上げるときは、既知の欠陥を仕込んだ確認で検出が成立することを確かめる。
各 mutant について、被覆の確認からテストの選択と実行までを照合し、未被覆と runner の未実行を分けて報告する。
影響範囲として選んだ mutation の対象内での除外は、変異演算子と低リスク要素に限る。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。
