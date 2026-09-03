# Playwright

用途は、UI をブラウザ越しに操作し見た目と疎通を確かめる道具である。
採用は、TypeScript は Playwright である。
判断基準は、Gherkin の記法で smoke を書け、baseline 画像ごとか同じ実行環境を使う画像集合ごとに実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport の metadata を画像とともに版管理し、metadata の canonical serialization から environment fingerprint を生成し、検証時の現在値から生成した fingerprint と一致しなければ screenshot の比較前に失敗し、画像と metadata を一つの更新単位として明示的にレビューできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
