# Roslyn documentation-comment analyzer

用途は、ドキュメントコメントの存在、構文、宣言と tag の機械判定できる対応、最初の一行と句読点を検査する道具である。
採用は、C# は Roslyn の documentation-comment analyzer である。
判断基準は、comment の存在と構文、宣言と tag の対応、最初の一行と句読点を一律に検査し、違反をリポジトリの検証入口で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Roslyn、TypeScript compiler API、`@microsoft/tsdoc` の互換性の変化を再評価のトリガーとする。
