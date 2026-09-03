# Microsoft.CodeAnalysis.BannedApiAnalyzers

用途は、禁止した API の呼び出しを、ビルドで検出する検査である。
採用は、C# は Microsoft.CodeAnalysis.BannedApiAnalyzers である。
判断基準は、禁止の一覧を設定として宣言でき、違反をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
