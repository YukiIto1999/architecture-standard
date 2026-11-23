# Nx

用途は、言語ごとの package を task graph で横断し、変更の影響範囲だけを実行する orchestrator である。
採用は、Nx である。
判断基準は、task graph、affected 実行、local cache を持ち、remote cache に廃止された self-host package を使わないことであり、依存境界の強制は各言語の構造検査へ割り当てて Nx へ要求しない。
撤回条件は、判断基準を満たさなくなることであり、task graph・affected・cache の互換性喪失と保守の停止を再評価のトリガーとする。

## task の正本

### 要求
project の task の選択、依存関係、実行順は、Nx の task graph に一本化する。
CI、hook、開発 shell が同じ task を実行するときは、同じ Nx の target を呼ぶ。
target 内の処理には各言語の標準ツールや script を使える。それらは project の task graph を別に定義しない。
開発環境の供給と開発用の依存サービスの起動・停止は、[devenv](./devenv.md) の「開発環境と依存サービスを再現する」が定める。
Nx は供給された環境を使い、供給やサービス管理の手順を別に持たない。

### 根拠
task の定義が複数の機構に散ると、同じ task が場所ごとに違う手順で動く。
環境の供給と task の実行を分ければ、どの入口から実行しても同じ task graph が使われる。
開発環境と開発用の依存サービスは、task が実行される前提であり、task graph が入力と出力を追う task ではない。

### 完了条件
各入口から同じ task を実行したときに、同じ Nx の target とその依存関係が使われる。
各 target の実処理を実装するツールや script に、project の task の選択、依存関係、実行順が再定義されていない。
開発環境と開発用の依存サービスは、参照した devenv の規律に従って供給される。

### 禁止事項
Nx の外に、project の task graph の別定義を置くこと。
同じ task を実行する入口から、Nx の target と依存関係を経由せずに実処理だけを直接呼ぶこと。

### 行動
project の task を Nx に定義し、各入口から対応する target を呼ぶ。開発環境と開発用の依存サービスは、参照した devenv の規律に従って供給する。
