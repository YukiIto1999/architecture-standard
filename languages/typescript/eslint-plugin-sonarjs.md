# eslint-plugin-sonarjs

用途は、関数の複雑さを linter の規則として測る道具である。
採用は、TypeScript は eslint-plugin-sonarjs の cognitive-complexity 規則を、oxlint の JS plugin として読み込んだものである。
判断基準は、oxlint が cognitive complexity を native の規則として持たず、eslint-plugin-sonarjs の cognitive-complexity が switch を case の数によらず一度だけ加点し、oxlint の JS plugin の適合検査を通り、linter を oxlint 一つに保てることである。
撤回条件は、判断基準を満たさなくなることであり、oxlint が同じ尺度の native の規則を持つこと、oxlint の JS plugin の安定版の到達、eslint-plugin-sonarjs の保守の停止と許諾の変更を再評価のトリガーとする。

## 関数の複雑さを lint で止める

### 要求
関数の複雑さは、[structure/tests の methods](../../structure/tests/methods.md) の「構造の検証」に従い、oxlint の jsPlugins に eslint-plugin-sonarjs を読み込み、sonarjs/cognitive-complexity を error にして測る。
しきい値は、sonarjs/cognitive-complexity の option に置く。
基線台帳に記録した既存の違反は、その関数の直前に `// oxlint-disable-next-line sonarjs/cognitive-complexity -- 理由` を置いて抑止する。
oxlint の options の reportUnusedDisableDirectives を error にする。

### 根拠
oxlint の native の complexity 規則は cyclomatic complexity を測り、cognitive complexity の規則は native に無い。
JS plugin として読み込めば、型認識の検査と同じ oxlint の実行で判定でき、linter を二つ持たない。
reportUnusedDisableDirectives を error にすれば、違反を直した後に残った抑止が検証入口を止め、抑止が基線台帳とともに減る。

### 完了条件
sonarjs/cognitive-complexity が error で、しきい値が [structure/tests の methods](../../structure/tests/methods.md) の値である。
oxlint の reportUnusedDisableDirectives が、error になっている。
sonarjs/cognitive-complexity の抑止が、基線台帳に記録した関数の理由付きの oxlint-disable-next-line に限られている。

### 禁止事項
関数の複雑さを測るために、oxlint と別の linter を検証入口へ置くこと。
sonarjs/cognitive-complexity を、file 単位の oxlint-disable で抑止すること。
理由のない oxlint-disable-next-line で、sonarjs/cognitive-complexity を抑止すること。

### 行動
oxlint の設定の jsPlugins に eslint-plugin-sonarjs を加え、rules に sonarjs/cognitive-complexity を error で置き、options の reportUnusedDisableDirectives を error にする。
基線台帳に記録した既存の違反の関数の直前に、理由を付けた oxlint-disable-next-line を置く。
