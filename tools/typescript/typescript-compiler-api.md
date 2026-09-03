# TypeScript compiler API

用途は、依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である。
採用は、TypeScript は構文の形に TypeScript compiler API を使う AST 構造検査である。
判断基準は、層の参照禁止・公開面・副作用の参照禁止を規則として書け、違反をリポジトリの検証入口で止められることである。
TypeScript compiler API が、call expression の symbol、callee expression の型、parameter の initializer、destructuring の binding element を取得できることを判断基準にする。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
