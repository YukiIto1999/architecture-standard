# DapperAOT

用途は、SQL 中の placeholder と parameter member の対応を DB を起動せずに補助検査する道具である。
採用は、C# は DapperAOT である。
判断基準は、PostgreSQL では補助検査として basic match の診断を使い、列の型と nullable を含む最終判定を [dapper](./dapper.md) が定める SQL と DTO の照合テストで行うことである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
