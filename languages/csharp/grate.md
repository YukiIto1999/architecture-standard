# grate

用途は、schema を変更する forward-only の SQL script を、履歴順に一度だけ、アプリの配備から独立して適用する道具である。
採用は、C# は grate の up の one-time script である。
判断基準は、migration を言語の class に包まず SQL script のまま扱い、適用済みの one-time script を再実行せず、独立した CLI から非対話で実行できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、PostgreSQL 対応の終了、one-time script の実行規則の変化を再評価のトリガーとする。
