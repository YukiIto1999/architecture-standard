# build

build は、task の編成、共有ライブラリの取得、契約と release metadata の生成、成果物の署名に使う道具の採用を定める。
エントリは、[README](./README.md) の書式と選定の共通基準に従う。

## task orchestrator

用途は、言語ごとの package を task graph で横断し、変更の影響範囲だけを実行する orchestrator である。
採用は、Nx である。
判断基準は、task graph、affected 実行、cache を持つことであり、依存境界の強制は各言語の構造検査へ割り当てて Nx へ要求しない。
撤回条件は、判断基準を満たさなくなることであり、task graph・affected・cache の互換性喪失と保守の停止を再評価のトリガーとする。

## 共有ライブラリの取得

用途は、独立した機構リポジトリの exact commit を、target の `libs/<mechanism>` へ再現することである。
採用は、Git submodule である。
判断基準は、target の tree が gitlink で機構の commit object ID を固定し、`.gitmodules` が origin と path を記録し、clean clone から同じ commit のコードと `spec.md` を同じ path へ checkout できることである。
撤回条件は、gitlink、origin、path のいずれかを target の履歴で再現できなくなることであり、Git の submodule 仕様と利用する repository host の取得条件の変化を再評価のトリガーとする。

