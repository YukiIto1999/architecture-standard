# TypeSpec

用途は、契約の意味の正本を記述し、そこから OpenAPI・client・型を生成する道具である。
採用は、記述に TypeSpec を使い、判別付き直和を `@oneOf` と `@discriminated(#{ envelope: "none" })` で宣言する。OpenAPI の出力には `@typespec/openapi3`、Rust の生成には openapi-generator の rust generator(`library=reqwest`)、C# の client と型の生成には NSwag、TypeScript の型生成には openapi-typescript を使う。
判断基準は、`@typespec/openapi3` が各 variant を `oneOf` と OpenAPI discriminator へ出力し、各 generator が生成した表現で判別子と payload を失わずに serialize と deserialize を往復し、[tests の方法](../../structure/tests/methods.md) が定める generated-contract round-trip を通ることである。
撤回条件は、判断基準を満たさなくなることであり、採用済みの emitter または generator が判別付き直和を互換に生成できなくなることを再評価のトリガーとする。
