# TypeSpec

用途は、UI が参照する契約の型の真実源となる契約記述である。
採用は、TypeScript は TypeSpec と `@typespec/openapi3` の OpenAPI 出力である。
判断基準は、契約から OpenAPI を出力でき、openapi-typescript で runtime のコードを持たない型だけを生成できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 契約の型を生成する

### 要求
contracts/generated の TypeScript の型は、TypeSpec から `@typespec/openapi3` で出力した OpenAPI を、openapi-typescript で型だけに生成する。

### 根拠
openapi-typescript は型定義だけを出力し runtime のコードを持たないので、生成型を型としてのみ使い runtime の依存を持ち込まない規律とかみ合う。
契約から型を生成すれば、UI が参照する型が契約に従う。

### 完了条件
型が、TypeSpec から `@typespec/openapi3` を経て openapi-typescript で生成されている。

### 禁止事項
契約の型を、runtime のコードを含む生成器で作ること。

### 行動
TypeSpec から `@typespec/openapi3` で OpenAPI を出力し、openapi-typescript で型を生成する。
