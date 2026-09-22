# Nx

用途は、言語ごとの package を task graph で横断し、変更の影響範囲だけを実行する orchestrator である。
採用は、Nx である。
判断基準は、task graph、affected 実行、local cache を持ち、remote cache に廃止された self-host package を使わないことであり、依存境界の強制は各言語の構造検査へ割り当てて Nx へ要求しない。
撤回条件は、判断基準を満たさなくなることであり、task graph・affected・cache の互換性喪失と保守の停止を再評価のトリガーとする。

## task の正本

### 要求
task の定義と実行の正本は、Nx に一本化する。
recipe runner や環境ツールへ、task の定義を並置しない。
環境の供給は、task の正本を持たない。

### 根拠
task の定義が複数の機構に散ると、同じ task が場所ごとに違う手順で動く。
環境の供給と task の実行を分ければ、どの入口から実行しても同じ task graph が使われる。

### 完了条件
task の定義が、Nx の設定だけにある。
recipe runner と環境ツールに、task の定義が無い。
環境の供給が、task を定義していない。

### 禁止事項
Nx の外に、task の定義を置くこと。
環境ツールに、task の正本を持たせること。

### 行動
task を Nx の設定へ定義し、環境ツールは実行環境の供給だけを担わせる。
