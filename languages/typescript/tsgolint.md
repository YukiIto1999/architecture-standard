# tsgolint

用途は、規則の違反をビルドで止める linter である。
採用は、TypeScript は `oxlint --type-aware` と `oxlint-tsgolint` の組である。
判断基準は、[typescript](./inspection.md) の inspection が割り当てる型情報 lint を TypeScript の全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、JavaScript/TypeScript の検証入口で `oxlint --type-aware` が type-aware rule の違反をエラーとして返せなくなることを再評価のトリガーとする。
