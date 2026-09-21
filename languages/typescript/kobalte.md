# Kobalte

用途は、見た目を持たない振る舞いだけの UI component を提供する機構である。
採用は、@kobalte/core の SolidJS 2.0 対応版である。
判断基準は、viewer、bundler plugin、UI component の peer 宣言が同時に成立する一組へ版を固定でき、見た目を持たない振る舞いだけの UI component と design token による見た目を分離できることである。
撤回条件は、判断基準を満たさなくなることであり、SolidJS 2.0、@solidjs/web、@solidjs/vite-plugin、@kobalte/core の各安定版の到達を再評価のトリガーとする。
