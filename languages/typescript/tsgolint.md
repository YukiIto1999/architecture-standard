# tsgolint

用途は、型情報を要する規則の違反を、ビルドで止める linter である。
採用は、TypeScript は `oxlint-tsgolint` である。
判断基準は、[typescript](./inspection.md) の inspection が割り当てる型情報 lint を TypeScript の全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱え、[vite-plus](./vite-plus.md) の `vp check` から実行できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、`vp check` が type-aware rule の違反をエラーとして返せなくなること、tsgolint が TypeScript の新しい版へ追随しなくなることを再評価のトリガーとする。
