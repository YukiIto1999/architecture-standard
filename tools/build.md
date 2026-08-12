# build

build は、task の編成、共有ライブラリの取得、契約と release metadata の生成、成果物の署名に使う道具の採用を定める。
エントリは、[README](./README.md) の書式と選定の共通基準に従う。

## task orchestrator

用途は、言語ごとの package を task graph で横断し、変更の影響範囲だけを実行する orchestrator である。
採用は、Nx である。
判断基準は、task graph、affected 実行、cache を持つことであり、依存境界の強制は各言語の構造検査へ割り当てて Nx へ要求しない。
撤回条件は、判断基準を満たさなくなることであり、task graph・affected・cache の互換性喪失と保守の停止を再評価のトリガーとする。

## 共有ライブラリの取得

用途は、独立した機構リポジトリの exact commit を、target の `libs/<mechanism>` へ再現することである。
採用は、Git submodule である。
判断基準は、target の tree が gitlink で機構の commit object ID を固定し、`.gitmodules` が origin と path を記録し、clean clone から同じ commit のコードと `spec.md` を同じ path へ checkout できることである。
撤回条件は、gitlink、origin、path のいずれかを target の履歴で再現できなくなることであり、Git の submodule 仕様と利用する repository host の取得条件の変化を再評価のトリガーとする。

## 契約の記述と生成

用途は、契約の意味の正本を記述し、そこから OpenAPI・client・型を生成する道具である。
採用は、記述に TypeSpec を使い、判別付き直和を `@oneOf` と `@discriminated(#{ envelope: "none" })` で宣言する。OpenAPI の出力には `@typespec/openapi3`、Rust の生成には openapi-generator の rust generator(`library=reqwest`)、C# の client と型の生成には NSwag、TypeScript の型生成には openapi-typescript を使う。
判断基準は、`@typespec/openapi3` が各 variant を `oneOf` と OpenAPI discriminator へ出力し、各 generator が生成した表現で判別子と payload を失わずに serialize と deserialize を往復し、[tests の方法](../structure/tests/methods.md) が定める generated-contract round-trip を通ることである。
撤回条件は、判断基準を満たさなくなることであり、採用済みの emitter または generator が判別付き直和を互換に生成できなくなることを再評価のトリガーとする。

## SBOM の生成

用途は、release する成果物の部品を、言語横断の機械可読な一覧へ生成する道具である。
採用は、Syft であり、出力は SPDX JSON とする。
判断基準は、filesystem・archive・container image の完成した成果物を走査し、対象言語と OS package を署名と脆弱性検査の共通入力へ出力できることである。
撤回条件は、判断基準を満たさなくなることであり、対象 ecosystem の対応終了と保守の停止を再評価のトリガーとする。

## 成果物の署名と provenance

用途は、release 成果物の digest と生成経路を、検証可能な署名済みの provenance に結び付ける機構である。
採用は、署名と検証に Cosign keyless、provenance に SLSA v1.2 の Build Provenance を使い、生成する build platform は project が外部 service を一つ選んで ADR に記録する。
判断基準は、検証時に期待する identity と issuer、成果物と attestation Statement の subject digest、Build Provenance の builder identity、build type、external parameters を照合できることである。
撤回条件は、判断基準を満たさなくなることであり、Cosign の keyless identity 検証、SLSA Build Provenance、採用した build platform の提供条件の変化を再評価のトリガーとする。
