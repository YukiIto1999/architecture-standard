# Nx

用途は、言語ごとの package を task graph で横断し、変更の影響範囲だけを実行する orchestrator である。
採用は、Nx である。
判断基準は、task graph、affected 実行、cache を持つことであり、依存境界の強制は各言語の構造検査へ割り当てて Nx へ要求しない。
撤回条件は、判断基準を満たさなくなることであり、task graph・affected・cache の互換性喪失と保守の停止を再評価のトリガーとする。
