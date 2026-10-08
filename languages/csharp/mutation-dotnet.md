# mutation-dotnet

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、C# は mutation-dotnet であり、入手は mutation-dotnet と、その build が参照する上流 repository の、release タグが指す commit ID を固定した source build である。
判断基準は、採用している test の実行系のテストを発見して実行し、その実行で mutant の判定が再現し、テストが検出しなかった mutant を機械可読な結果で報告し、テストが一件も見つからない実行を非ゼロ終了で止められることであり、これらを同時に満たす他の機構が無いことである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、同じ用途と判断基準を満たす機構の出現、採用している .NET の版を target しなくなること、報告形式の変化を再評価のトリガーとする。

## 有効性

### 要求
mutation は、mutation-dotnet で検査する。
変更ごとの生成対象は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所の和集合にする。
`run --since <基点> --changed-lines` と `changed-lines --report <報告> --since <基点>` は、そのうち変更部分の生成と報告判定に使い、影響部分を含む検査全体の入口と同一視しない。
影響部分は採用版が受け付ける対象指定と project の検証入口で別に生成・判定し、変更行だけを選ぶ制限で対象から落とさない。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更から影響部分を選ぶ。
変更入力から影響部分を導く impact planner と、その対象を生成・報告判定へ接続する処理は、mutation-dotnet と検証入口で満たす実装要件であり、上記の diff 機能が自動で満たすとはみなさない。
採用版と検証入口に必要な対象選択や判定の実装がなければ、mutation-dotnet 側の実装課題として扱い、変更部分の成功で未完了の影響部分を代替しない。
検証入口は、生成対象と被覆テストの選択を分け、生成時と判定時の source、比較元と実行条件の同一性を確認する。
既存証跡は [process/verification](../../process/verification.md) の同一性を満たす範囲だけで再利用し、既存の report を現在の diff に当てるだけで合格にしない。
未検出の mutant は、報告の状態別件数のうち生存と未被覆の合計で数える。
生成対象、除外、合否、結果の分類と修正後の再実行は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
未被覆の mutant は検出しなかった側に入るため、生存だけを数えると未検出の件数が少なく出る。
`--since` は変更した file を選び、`--changed-lines` は変更した行に重なる mutant だけを生成するため、この組だけでは未変更の影響する箇所を検査しない。
テストが一件も見つからない実行は、対象の中断として非ゼロ終了になる。

### 完了条件
変更部分と影響部分の和集合が生成対象として列挙され、各範囲の検査が完了しているか、有効な同一検査の証跡で覆われている。
未検出の mutant が報告の生存と未被覆の合計で数えられ、型として成立しない変異と runner などによる未完了が検出件数へ加えられていない。
テストが一件も見つからない実行が、検証入口を失敗で止めている。
mutation-dotnet の取得が、release タグが指す commit ID で固定されている。
生成対象、除外、合否、結果の分類と修正後の再実行が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
生存だけを数え、未被覆を未検出の件数から除くこと。
変更行の report だけで影響部分も完了したとみなすことと、影響する箇所を未変更という理由で生成対象から外すこと。
変更部分へ無関係な全量の結果を混ぜることと、impact planner の未実装を範囲縮小で隠すこと。
変異演算子と低リスク要素の外へ絞り込みを広げ、母数から変異を外すこと。
mutation-dotnet の取得を、commit ID を固定しない参照で行うこと。

### 行動
mutation-dotnet と、その build が参照する上流 repository を、release タグが指す commit ID を固定して取得する。
変更入力から生成対象の変更部分と影響部分を計画し、被覆テストの選択とは別の対象として検証入口へ渡す。
変更部分は `run --since <基点> --changed-lines` で生成し、同じ source と比較元に対する report を `changed-lines --report <報告> --since <基点>` で判定する。
影響部分は採用版で扱える対象指定を別に使い、その範囲の生成、実行と report の判定を検証入口へ組み込む。
対象指定や判定を接続できない場合は mutation-dotnet 側の impact planner と実行経路を実装するまで承認を止め、存在しない flag や API を検証入口に仮定しない。
検査全体の mutant の生存と未被覆の合計を合否の判定へ渡し、変更行だけを抽出した件数で影響部分の結果を捨てない。
影響する既存証跡を無効化し、影響しない証跡は同一性が成立する間再利用する。
生成と判定のあいだで入力が変わった report、対象の完了を確認できない report、理由のない生成 0 件を、成功の証跡にしない。
report と `run` および `changed-lines` の終了 status を保持し、結果の分類と修正後の再実行は [structure/tests/methods](../../structure/tests/methods.md) の「テストの有効性」に従う。
影響範囲として選んだ mutation の対象内での除外は、変異演算子と低リスク要素に限る。
