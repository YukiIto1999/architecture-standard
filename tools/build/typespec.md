# TypeSpec

用途は、契約の意味の正本を記述し、そこから OpenAPI・client・型を生成する道具である。
採用は、記述に TypeSpec を使い、判別付き直和を `@oneOf` と `@discriminated(#{ envelope: "none" })` で宣言する。OpenAPI の出力には `@typespec/openapi3` を使い、`openapi-versions` は 3.0 系に固定する。Rust の client と型の生成には progenitor、C# の client と型の生成には NSwag、TypeScript の型生成には openapi-typescript を使う。HTTP を持たない契約の型生成には `@typespec/json-schema` で JSON Schema を出力し、Rust は typify、C# は NSwag の JSON Schema 入力、TypeScript は json-schema-to-typescript を使う。
判断基準は、`@typespec/openapi3` が各 variant を `oneOf` と OpenAPI discriminator へ出力し、各 variant の schema が判別子の property を required かつ単一の固定値として持ち、各 generator が生成した表現で判別子を一度だけ出力して payload を失わずに serialize と deserialize を往復し、[tests の方法](../../structure/tests/methods.md) が定める generated-contract round-trip を通ることである。各 generator が受け取れる OpenAPI の版が、`@typespec/openapi3` が出力する版を含むことを含む。
撤回条件は、判断基準を満たさなくなることであり、採用済みの emitter または generator が判別付き直和を互換に生成できなくなること、`@typespec/openapi3` が出力する OpenAPI の版を採用済みの generator が受け取れなくなること、採用済みの generator が同じ入力と同じ版から異なる出力を出すようになることを再評価のトリガーとする。
