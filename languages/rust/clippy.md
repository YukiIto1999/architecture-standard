# clippy

用途は、規則の違反をビルドで止める linter である。
採用は、Rust は clippy である。
判断基準は、[rust](./inspection.md) の inspection が割り当てる規則を Rust の全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Vite Plus の統合 CLI(vp)の 1.0 到達を再評価のトリガーとする。
