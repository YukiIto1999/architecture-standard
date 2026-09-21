# DapperAOT

用途は、SQL 中の placeholder と parameter member の対応を DB を起動せずに補助検査する道具である。
採用は、C# は DapperAOT である。
判断基準は、PostgreSQL では補助検査として basic match の診断を使い、列の型と nullable を含む最終判定を [dapper](./dapper.md) が定める SQL と DTO の照合テストで行うことであり、Dapper.AOT 1.1.0 では CancellationToken を受ける CommandDefinition の呼び出しが DAP057 で報告され、PublishAot では warning、それ以外では information となるが、名前対応の生成検査は受けないことである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
