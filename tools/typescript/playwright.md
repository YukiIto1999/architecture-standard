# Playwright

用途は、UI をブラウザ越しに操作し見た目と疎通を確かめる実行系である。
採用は、TypeScript は Playwright である。
判断基準は、browser の操作と screenshot 比較を test runner として実行でき、baseline 画像と実行環境の記録を版管理してレビューできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## baseline 画像と環境指紋を一つの更新単位で版管理する

### 要求
baseline 画像は、画像ごとか同じ実行環境を使う画像集合ごとに、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport の metadata と組にして版管理する。
metadata の canonical serialization から、environment fingerprint を生成する。
検証時の現在値から生成した fingerprint と一致しなければ、screenshot の比較前に失敗させる。
画像と metadata は、一つの更新単位として明示的にレビューする。

### 根拠
実行環境が変わると描画が変わるので、fingerprint なしでは baseline との差分が環境差か退行かを判別できない。
比較の前に fingerprint で失敗させれば、環境差による偽の差分がレビューを汚さない。
画像と metadata を一組で更新すれば、片方だけの更新による不整合が入らない。

### 完了条件
baseline 画像が、metadata と組で版管理されている。
fingerprint の不一致が、screenshot 比較前の失敗になっている。
画像と metadata の更新が、一つの更新単位としてレビューされている。

### 禁止事項
metadata を持たない baseline 画像を、版管理すること。
fingerprint が不一致のまま、screenshot を比較すること。

### 行動
baseline の追加と更新で metadata を生成し、fingerprint の照合を検証入口の比較前に配線する。

