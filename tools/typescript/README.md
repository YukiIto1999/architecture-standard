# typescript ecosystem

typescript の言語としての採用と、実現規律、採用物を置く。
言語の採用は、TypeScript 6.0 である。
判断基準は、言語ごとの実現規律と検証方法を標準本文で完結して定められることである。
撤回条件は、判断基準を満たさなくなることであり、基盤版の保守終了または実現規律の欠落を再評価のトリガーとする。
実現軸と書式は、[tools の README](../README.md) の言語 ecosystem に従う。

## 実現軸

| ファイル | 意味 |
|---|---|
| [formation](./formation.md) | 値・型・不変条件のモデリング(実現軸) |
| [translation](./translation.md) | 外界境界での意味の出し入れ(実現軸) |
| [connection](./connection.md) | 副作用と依存の渡し方(実現軸) |
| [coordination](./coordination.md) | 非同期・並行・取り消しの実行(実現軸) |
| [publication](./publication.md) | 外部公開面と host(実現軸) |
| [inspection](./inspection.md) | 検証(実現軸) |
| [conventions](./conventions.md) | 命名・整形・ドキュメントコメント・型名接尾辞(全域規律) |

## 採用

採用物ごとに一つのファイルを置き、用途・採用・判断基準・撤回条件を持つ。

| ファイル | 用途 | 採用 |
|---|---|---|
| [axe-core-playwright](./axe-core-playwright.md) | UI の E2E で、自動判定できる accessibility の違反を検出する道具である | TypeScript は @axe-core/playwright である |
| [cucumber-js](./cucumber-js.md) | 業務語彙の executable spec を実行する道具である | TypeScript は cucumber-js である |
| [dependency-cruiser](./dependency-cruiser.md) | 依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である | TypeScript は依存方向に dependency-cruiser である |
| [fast-check](./fast-check.md) | 入出力の不変量を性質として多くの入力で検査する property-based testing である | TypeScript は fast-check である |
| [knip](./knip.md) | エントリーポイントからの到達可能性で、未使用のファイル・エクスポート・依存を見つける道具である | TypeScript は knip である |
| [kobalte](./kobalte.md) | 見た目を持たない振る舞いだけの UI component を提供する機構である | TypeScript は Kobalte である |
| [neverthrow](./neverthrow.md) | viewer・extension・host の軽い役割に見合う、副作用と想定内失敗を型で表す機構である | TypeScript は neverthrow である |
| [opentelemetry-js](./opentelemetry-js.md) | 利用者の環境で動く viewer の trace と構造化 event を、境界の殻で収集する機構である | TypeScript は OpenTelemetry JS の WebTracerProvider と span event、OTLP/HTTP の trace exporter である |
| [oxfmt](./oxfmt.md) | 表記を道具の既定で一意に揃える formatter である | TypeScript は oxfmt である |
| [oxlint](./oxlint.md) | 規則の違反をビルドで止める linter である | TypeScript は oxlint である |
| [playwright-bdd](./playwright-bdd.md) | UI をブラウザ越しに操作し見た目と疎通を確かめる道具である | TypeScript は playwright-bdd である |
| [playwright](./playwright.md) | UI をブラウザ越しに操作し見た目と疎通を確かめる道具である | TypeScript は Playwright である |
| [solidjs](./solidjs.md) | GUI の surface を組む骨格である | SolidJS である |
| [stryker-js](./stryker-js.md) | テストが振る舞いを固定しているかを測る mutation 検査である | TypeScript は StrykerJS である |
| [tailwind](./tailwind.md) | styling を組む機構である | TypeScript は Tailwind CSS の Vite plugin である |
| [testcontainers](./testcontainers.md) | 実依存のコンテナを起動し、本物に近い依存で検証する道具である | TypeScript は testcontainers の node 実装である |
| [tsdoc](./tsdoc.md) | ドキュメントコメントの存在、構文、宣言と tag の機械判定できる対応、最初の一行と句読点を検査する道具である | TypeScript は TypeScript compiler API と `@microsoft/tsdoc` を使う構造検査である |
| [tsgolint](./tsgolint.md) | 規則の違反をビルドで止める linter である | TypeScript は tsgolint の type-aware 実行である |
| [typescript-compiler-api](./typescript-compiler-api.md) | 依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である | TypeScript は構文の形に TypeScript compiler API を使う AST 構造検査である |
| [typespec](./typespec.md) | UI が参照する契約の型の真実源となる契約記述である | TypeScript は TypeSpec と `@typespec/openapi3` の OpenAPI 出力である |
| [valibot](./valibot.md) | 外部入力を schema で検証し、検証済みの値だけに型を名乗らせる機構である | TypeScript は valibot である |
| [vite](./vite.md) | web の host の entry と bundler である | Vite である |
| [vitest](./vitest.md) | 単体・性質・結合のテストの実行系である | TypeScript は Vitest である |
| [vscode-jsonrpc](./vscode-jsonrpc.md) | extension が接続する core のプロセスとの間で、JSON-RPC の小さい契約だけを外へ出す機構である | TypeScript は vscode-jsonrpc である |
| [vscode](./vscode.md) | extension の surface を動かす ide の host である | VSCode である |

## 言語機構で満たす用途

外部の採用物を持たず、言語機構または既存の採用で満たす用途を示す。

| 用途 | 満たし方 | 置き場 |
|---|---|---|
| server の middleware | server の役割を持たないため採用を持たない | — |
| 非同期の runtime | 言語・実行環境に組み込みの非同期基盤を使い、外部の runtime を別に選ばない | [coordination](./coordination.md) |
| 取り消しの伝達 | 組み込みの機構(AbortController)で表し、外部ライブラリを採らない | [coordination](./coordination.md) |
| エラー型の定義 | 判別子つきの union という言語機構で表し、外部ライブラリを採らない | [formation](./formation.md) |
| 直列化 | 境界の値検証に使う schema から導出し、外部の直列化ライブラリを別に選ばない | [translation](./translation.md) |
| schema migration | server 側の永続化の役割を持たないため採用を持たない | — |
| API の禁止 | oxlint の no-restricted-imports・no-restricted-properties で満たし、専用の道具を置かない | [oxlint](./oxlint.md) |
