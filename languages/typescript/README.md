# typescript ecosystem

typescript の言語としての採用と、実現規律、採用物を置く。
言語の採用は、TypeScript 7.0 である。
判断基準は、上流が現に開発する最新の系に追随し、言語の型検査と JSX を標準本文の実現規律に使えることである。compiler API を要する検査は、言語版と別に安定 API を提供する採用物で満たせることである。
撤回条件は、上流が現に開発する最新の系に追随できず、上位規律が要求する機構の不足を実証した場合、または実現規律を満たせなくなることである。TypeScript 本体が安定 API を再び同梱したことを compiler API 採用の再評価トリガーとする。
実現軸と書式は、[languages の README](../README.md) の言語 ecosystem に従う。

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
| [fast-check](./fast-check.md) | 入出力の不変量を性質として多くの入力で検査する property-based testing である | TypeScript は fast-check である |
| [http-client-js](./http-client-js.md) | 契約から TypeScript の client と型を生成し、drift・conformance の検査に使う道具である | TypeScript は `@typespec/http-client-js` である |
| [json-schema-to-typescript](./json-schema-to-typescript.md) | HTTP を持たない契約の JSON Schema から TypeScript の型を生成する道具である | TypeScript は json-schema-to-typescript である |
| [knip](./knip.md) | エントリーポイントからの到達可能性で、未使用のファイル・エクスポート・依存を見つける道具である | TypeScript は knip である |
| [kobalte](./kobalte.md) | 見た目を持たない振る舞いだけの UI component を提供する機構である | @kobalte/core の SolidJS 2.0 対応版である |
| [opentelemetry-js](./opentelemetry-js.md) | 利用者の環境で動く viewer の trace と構造化 event を、境界の殻で収集する機構である | TypeScript は OpenTelemetry JS の WebTracerProvider と span event、OTLP/HTTP の trace exporter である |
| [oxfmt](./oxfmt.md) | 表記を道具の既定で一意に揃える formatter である | TypeScript は oxfmt である |
| [oxlint](./oxlint.md) | 規則の違反をビルドで止める linter である | TypeScript は oxlint である |
| [playwright-bdd](./playwright-bdd.md) | UI をブラウザ越しに操作し見た目と疎通を確かめる道具である | TypeScript は playwright-bdd である |
| [playwright](./playwright.md) | UI をブラウザ越しに操作し見た目と疎通を確かめる道具である | TypeScript は Playwright である |
| [solidjs](./solidjs.md) | GUI の surface を組む骨格である | SolidJS 2.0 系、@solidjs/web、@solidjs/vite-plugin である |
| [stryker-js](./stryker-js.md) | テストが振る舞いを固定しているかを測る mutation 検査である | TypeScript は StrykerJS である |
| [tailwind](./tailwind.md) | styling を組む機構である | TypeScript は Tailwind CSS の Vite plugin である |
| [testcontainers](./testcontainers.md) | 実依存のコンテナを起動し、本物に近い依存で検証する道具である | TypeScript は testcontainers の node 実装である |
| [ts-results-es](./ts-results-es.md) | viewer・extension・host の軽い役割に見合う、副作用と想定内失敗を型で表す機構である | TypeScript は ts-results-es である |
| [tsdoc](./tsdoc.md) | ドキュメントコメントの存在、構文、宣言と tag の機械判定できる対応、最初の一行と句読点を検査する道具である | TypeScript は @typescript/typescript6 6.0.2 と @microsoft/tsdoc を使う構造検査である |
| [tsgolint](./tsgolint.md) | 規則の違反をビルドで止める linter である | TypeScript は `oxlint --type-aware` と `oxlint-tsgolint` の組である |
| [typescript-compiler-api](./typescript-compiler-api.md) | 依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である | TypeScript は @typescript/typescript6 6.0.2 の compiler API を使う AST 構造検査である |
| [valibot](./valibot.md) | 外部入力を schema で検証し、検証済みの値だけに型を名乗らせる機構である | TypeScript は valibot である |
| [vite](./vite.md) | web の host の entry と bundler である | Vite と @solidjs/vite-plugin である |
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
