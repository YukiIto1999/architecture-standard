# DapperAOT

用途は、Dapper の SQL 結果から型への写像をビルド時に生成し、対応する呼出しの利用を補助検査する道具である。
採用は、C# は DapperAOT である。
判断基準は、対応する Dapper 呼出しの写像を reflection と実行時のコード生成に頼らず生成でき、dialect ごとの補助診断と、[dapper](./dapper.md) が定める SQL と parameter の型の名前対応と列の型と nullable の照合を区別できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
