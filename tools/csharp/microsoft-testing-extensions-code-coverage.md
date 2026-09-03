# Microsoft.Testing.Extensions.CodeCoverage

用途は、テストが実行していない箇所を見つけるカバレッジ計測である。
採用は、C# は Microsoft.Testing.Extensions.CodeCoverage である。
判断基準は、採用済みのテスト実行系と統合して機械可読な coverage report を branch まで数える設定で出力し、記録した下限を判定する検証入口の入力にできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、report 形式、branch を数える設定の変化、test runner との統合方法の変化を再評価のトリガーとする。
