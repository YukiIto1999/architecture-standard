# mutation-dotnet

用途は、テストの検出力を評価し改善する mutation 分析である。
採用は、C# は mutation-dotnet であり、入手は mutation-dotnet と、その build が参照する上流 repository の、release タグが指す commit ID を固定した source build である。
判断基準は、採用している test の実行系のテストを発見して実行し、その実行で mutant の判定が再現し、テストが検出しなかった mutant と分析の状態を機械可読な結果で報告し、テストが一件も見つからない実行を非ゼロ終了で示せることであり、これらを同時に満たす他の機構が無いことである。
撤回条件は、判断基準を満たさなくなることであり、上流の保守の停止、同じ用途と判断基準を満たす機構の出現、採用している .NET の版を target しなくなること、報告形式の変化を再評価のトリガーとする。

## 有効性

### 要求
mutation は、mutation-dotnet で分析する。
分析の候補は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従い、変更した production の箇所と未変更の影響する production の箇所から導く。
変更部分の生成と報告の判定には、`run --since <基点> --changed-lines` と `changed-lines --report <報告> --since <基点>` を同じ source と比較元に対して使う。
影響部分は、build graph が導く影響する project を `--project` と `--test-project` へ渡し、`--with-baseline` で前回の同じ種類の保存から入力の一致する mutant の判定を継承して、それ以外の mutant を再判定する範囲で選ぶ。
`--with-baseline` が照合しない入力(設定、他の file、参照する assembly・analyzer・generator の内容)を変えた変更では、その入力が届く対象の継承した判定を現在の分析結果とせず、継承なしで再判定するか未分析として記録する。
production の diff が空の場合も、テスト、契約、設定、依存、生成器または生成元の変更が届く影響部分を、上の選択か未分析の記録へ割り当てる。
これらの機能で選べない影響部分は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」に従って未分析として関係とともに記録し、mutation-dotnet の実装課題として扱う。
検証入口は、生成対象と被覆テストの選択を分け、生成時と判定時の source、比較元と実行条件の同一性を確認する。
既存証跡は [process/verification](../../process/verification.md) の同一性を満たす範囲だけで再利用し、既存の report を現在の diff に当てるだけで現在の source の分析結果として扱わない。
未検出の mutant は、報告の状態別件数のうち生存と未被覆の合計で数える。
生成対象、除外、結果の分類と修正後の確認は、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」に従い、実行と結果の取込は [process/verification](../../process/verification.md) に従う。

### 根拠
テストの検出力を mutation で分析する理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
未被覆の mutant は検出しなかった側に入るため、生存だけを数えると未検出の件数が少なく出る。
`--since` は変更した file を選び、`--changed-lines` は変更した行に重なる mutant だけを生成するため、この組だけでは未変更の影響する箇所を分析しない。
`--with-baseline` の変異ごとの継承は、その file の内容、変異列、テスト assembly と被覆テストの集合を鍵にする内容 cache であり、設定、他の file、参照する assembly の内容を照合しない。
影響部分の自動選択は mutation-dotnet の課題であり、project ごとの検証入口へ独自の planner を置くと、選択の誤りと証跡の失効の不備が project ごとに異なる形で生じる。
テストが一件も見つからない実行は、対象の中断として非ゼロ終了になる。

### 完了条件
分析した範囲が、`run --since <基点> --changed-lines` による変更部分と、影響部分を分析した場合は `--project` と `--with-baseline` で選んだ範囲とに分けて記録され、選ばなかった範囲と道具が選べない影響部分が未分析として残っている。
未検出の mutant が報告の生存と未被覆の合計で数えられ、型として成立しない変異と runner などによる不成立が検出件数へ加えられていない。
テストが一件も見つからない実行が、非ゼロ終了の status とともに分析の不成立として記録され、製品の合否へ直結していない。
report と `run` および `changed-lines` の終了 status が、生の値のまま保持されている。
mutation-dotnet の取得が、release タグが指す commit ID で固定されている。
生成対象、除外、結果の分類と修正後の確認が、[structure/tests/methods](../../structure/tests/methods.md) の「変更と影響範囲」と「テストの有効性」を満たしている。

### 禁止事項
生存だけを数え、未被覆を未検出の件数から除くこと。
変更行の report だけで影響部分も分析済みとみなすことと、影響する箇所を未変更という理由で候補から外すこと。
変更部分へ無関係な全量の結果を混ぜることと、道具が選べない影響部分を範囲縮小で隠すこと。
`--with-baseline` が照合しない入力を変えた変更で、その入力が届く対象の継承した判定を現在の分析結果とすること。
生存と未被覆の合計や非ゼロの終了 status だけを、製品の欠陥または承認の可否に読み替えること。
mutation-dotnet の取得を、commit ID を固定しない参照で行うこと。

### 行動
mutation-dotnet と、その build が参照する上流 repository を、release タグが指す commit ID を固定して取得する。
問いに応じて、変更部分、影響部分、またはその両方を分析の範囲に選び、生成対象を被覆テストの選択とは別に確認する。
変更部分は `run --since <基点> --changed-lines` で生成し、同じ source と比較元に対する report を `changed-lines --report <報告> --since <基点>` で判定する。
影響部分は、build graph が導く影響する project を `--project` と `--test-project` へ渡し、`--with-baseline` で入力の変わった mutant を再判定する。
設定や参照する assembly などを変えた変更では、届く対象を `--with-baseline` なしで再判定するか、継承した判定を未分析として残す。
道具が選べない影響部分は、mutation-dotnet の実装課題として未分析を記録し、存在しない flag や API を仮定しない。
選んだ範囲の mutant の生存と未被覆の合計を分類の入力へ渡し、変更行だけを抽出した件数で、分析した影響部分の結果を捨てない。
影響する既存証跡を無効化し、影響しない証跡は同一性が成立する間再利用する。
生成と判定のあいだで入力が変わった report、選んだ範囲の結果を確認できない report、理由のない生成 0 件を、有効な分析結果として扱わない。
report と `run` および `changed-lines` の終了 status を生の値のまま保持し、結果の分類と修正後の確認は [structure/tests/methods](../../structure/tests/methods.md) の「テストの有効性」に従う。

## 参照
- [mutation-dotnet#1](https://github.com/YukiIto1999/mutation-dotnet/issues/1) の、変更箇所と影響箇所を含む mutation 対象の選択。
- mutation-dotnet の `docs/limitations.md` の「判定と継承」。
