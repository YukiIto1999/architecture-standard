# TypeSpec

用途は、契約の意味の正本を記述し、そこから OpenAPI・client・型を生成する道具である。
採用は、記述に TypeSpec を使い、判別付き直和の各 variant に単一の固定値を持つ判別子の property を必須で宣言する。
直和は `@discriminated` で envelope を `none` にし、判別子の property 名と variant の名前・固定値を各 variant の宣言と一致させる。
canonical の同じ直和へ、OpenAPI 用の [@TypeSpec.OpenAPI.oneOf](https://typespec.io/docs/emitters/openapi3/reference/decorators/#@TypeSpec.OpenAPI.oneOf) と JSON Schema 用の [@TypeSpec.JsonSchema.oneOf](https://typespec.io/docs/emitters/json-schema/reference/decorators/#@TypeSpec.JsonSchema.oneOf) を適用し、同名の注釈を混同しない。
成功の応答は 2xx の status を持つ `@error` でないモデルで表し、失敗の応答は `@statusCode` で 4xx か 5xx の具体の status を宣言した `@error` のモデルで表す。
status を持たない `@error` のモデルは、OpenAPI の出力で `default` の応答になるので置かない。
OpenAPI の出力には `@typespec/openapi3` を使い、`openapi-versions` は 3.0 系に固定する。
HTTP を持たない契約の型生成には `@typespec/json-schema` で JSON Schema を出力する。
出力から各言語の client と型を作る generator は、言語 ecosystem の採用が定める。
判断基準は、OpenAPI と JSON Schema の両出力が各 variant を `oneOf` と必須の固定値の判別子で表し、OpenAPI は discriminator の対応も持つことである。
宣言や discriminator の mapping の存在だけを保証とせず、各 variant の schema の必須性と固定値、および判別子の欠落、未知値、payload との不一致の拒否を検査する。
各 generator が生成した表現で判別子を一度だけ出力して payload を失わずに serialize と deserialize を往復し、[tests の方法](../../structure/tests/methods.md) が定める generated-contract round-trip を通ることを含む。
各 generator が受け取れる OpenAPI の版が、`@typespec/openapi3` が出力する版を含むことを含む。
各 generator が build 時の独立した toolchain で動き、その toolchain が要求する言語の版を製品の toolchain へ持ち込まないことを含む。
生成経路は [structure/contracts/generated](../../structure/contracts/generated.md) が定める具体的なデータ型、encoder・decoder、未知項目の扱いと通信 client・stub の分離を満たし、不足は canonical、binding、生成器の該当する入力で直す。
撤回条件は、判断基準を満たさなくなることであり、採用済みの emitter または generator が判別付き直和を互換に生成できなくなること、`@typespec/openapi3` が出力する OpenAPI の版を採用済みの generator が受け取れなくなること、採用済みの generator が同じ入力と同じ版から異なる出力を出すようになること、採用済みの generator の保守の停止、採用済みの generator が自身の toolchain への依存を解消することを再評価のトリガーとする。
