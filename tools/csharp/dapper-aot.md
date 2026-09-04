# DapperAOT

用途は、SQL 中の placeholder と parameter member の対応を DB を起動せずに補助検査する道具である。
採用は、C# は DapperAOT である。
判断基準は、PostgreSQL では補助検査として basic match の診断を使い、列の型と nullable を含む最終判定を [dapper](./dapper.md) が定める SQL と DTO の照合テストで行うことである。
CancellationToken を受ける CommandDefinition の呼び出しは DapperAOT の検査対象にならないため、取り消しの伝播を落とさず、その呼び出しの名前対応は照合テストが最終判定として担う。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
