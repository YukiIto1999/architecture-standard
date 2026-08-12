# inspection

inspection は、検証の道具の採用を定める。
エントリは、[README](./README.md) の書式と選定の共通基準に従う。
道具の使い方と規則の割り当ては、[languages](../languages/) の inspection と [structure/tests](../structure/tests/layout.md) に従う。
計算の重い解析は、ビルド時の lint に載せず、独立の道具かセルフホストの基盤に分ける。

## 整形

用途は、表記を道具の既定で一意に揃える formatter である。
採用は、Rust は rustfmt、C# は CSharpier、TypeScript は oxfmt である。
判断基準は、既定の設定で出力が一意に決まることである。
CSharpier は、設定項目を少数に絞った opinionated な formatter で、整形の細部を設定で変える余地が狭い。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と oxfmt の安定版のリリースを再評価のトリガーとする。

## lint

用途は、規則の違反をビルドで止める linter である。
採用は、Rust は clippy、C# は SonarAnalyzer.CSharp、TypeScript は oxlint と tsgolint の type-aware 実行である。
判断基準は、[languages の inspection](../languages/) が割り当てる規則を全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Vite Plus の統合 CLI(vp)の 1.0 到達を再評価のトリガーとする。

## API の禁止

用途は、禁止した API の呼び出しを、ビルドで検出する検査である。
採用は、C# は Microsoft.CodeAnalysis.BannedApiAnalyzers である。
Rust は clippy の disallowed_methods で満たし、TypeScript は oxlint の no-restricted-imports・no-restricted-properties で満たし、専用の道具を置かない。
判断基準は、禁止の一覧を設定として宣言でき、違反をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## テストの実行

用途は、単体・性質・結合のテストの実行系である。
採用は、Rust は cargo-nextest、C# は TUnit、TypeScript は Vitest である。
判断基準は、テストを速く決定的に回せることである。
cargo-nextest は、各テストを別のプロセスで実行し、状態を汚したテストが兄弟のテストを汚さない。
TUnit は、ソース生成に基づき、テストの発見と実行を実行時のリフレクションに頼らない。
Vitest は、build の設定をテストと共有し、変換の前提がテストと本体でずれない。
撤回条件は、判断基準を満たさなくなることであり、実行基盤の対応状況の変化を再評価のトリガーとする。

## 性質検査

用途は、入出力の不変量を性質として多くの入力で検査する property-based testing である。
採用は、Rust は proptest、C# は CsCheck、TypeScript は fast-check である。
判断基準は、失敗した入力を最小化でき、状態の遷移を操作の列を生成する stateful な形で突けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 仕様の実行

用途は、業務語彙の executable spec を実行する道具である。
採用は、Rust は cucumber の Rust 実装、C# は Reqnroll、TypeScript は cucumber-js である。
判断基準は、業務語彙のシナリオを公開の interface 越しに検証できることである。
Reqnroll は自前のテスト実行系を持たないため、実行基盤は Reqnroll.TUnit で単体・性質と同じ TUnit に揃える。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 実依存の起動

用途は、実依存のコンテナを起動し、本物に近い依存で検証する道具である。
採用は、Rust は testcontainers、C# は Testcontainers for .NET、TypeScript は testcontainers の node 実装である。
判断基準は、割り当てられた host と port を取得して使え、コンテナをテストの終わりに片づけられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## UI の E2E smoke と visual

用途は、UI をブラウザ越しに操作し見た目と疎通を確かめる道具である。
採用は、TypeScript は playwright-bdd と Playwright である。
判断基準は、Gherkin の記法で smoke を書け、baseline 画像ごとか同じ実行環境を使う画像集合ごとに実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport の metadata を画像とともに版管理し、metadata の canonical serialization から environment fingerprint を生成し、検証時の現在値から生成した fingerprint と一致しなければ screenshot の比較前に失敗し、画像と metadata を一つの更新単位として明示的にレビューできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## UI の accessibility 検査

用途は、UI の E2E で、自動判定できる accessibility の違反を検出する道具である。
採用は、TypeScript は @axe-core/playwright である。
Rust と C# は、viewer を TypeScript に委ねるため採用を持たない。
判断基準は、採用済みの Playwright の runner と page に対して、操作後の各状態で対比・ラベル・focus の機械判定できる違反を検査し、リポジトリの検証入口で止められることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と Playwright との互換性の喪失を再評価のトリガーとする。

## mutation

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、Rust は cargo-mutants、C# は Stryker.NET の MTP runner(preview)、TypeScript は StrykerJS である。
判断基準は、テストが検出しなかった mutant を機械可読な結果で報告し、リポジトリの検証入口を失敗で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Stryker.NET の MTP test runner の preview status、TUnit との互換性、StrykerJS の report 形式の変化を再評価のトリガーとする。

## 未実行箇所の発見

用途は、テストが実行していない箇所を見つけるカバレッジ計測である。
採用は、Rust は cargo-llvm-cov、C# は Microsoft.Testing.Extensions.CodeCoverage、TypeScript は Vitest の coverage(v8 provider)である。
判断基準は、採用済みのテスト実行系と統合して機械可読な coverage report を出力し、記録した下限を判定する検証入口の入力にできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、report 形式、test runner との統合方法の変化を再評価のトリガーとする。

## 構造検査

用途は、依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である。
採用は、Rust は root の tests/ に置く構造検査、C# は ArchUnitNET、TypeScript は依存方向に dependency-cruiser、構文の形に TypeScript compiler API を使う AST 構造検査である。
判断基準は、層の参照禁止・公開面・副作用の参照禁止を規則として書け、違反をリポジトリの検証入口で止められることである。
TypeScript compiler API が、call expression の symbol、callee expression の型、parameter の initializer、destructuring の binding element を取得できることを判断基準にする。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 未使用コードの検出

用途は、エントリーポイントからの到達可能性で、未使用のファイル・エクスポート・依存を見つける道具である。
採用は、TypeScript は knip である。
判断基準は、局所の参照数でなく到達可能性で判定し、相互に参照し合う孤立した島を検出できることである。
Rust と C# は、コンパイラと lint の到達可能性に基づく検出で満たし、専用の道具を置かない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 認知的複雑さの検査

用途は、認知的複雑さを quality gate で検査する道具である。
採用は、セルフホストした SonarQube Community Build の cognitive complexity(S3776)と quality gate である。
判断基準は、switch や match の構造化を一度だけ加点し、閉じた直和の網羅的な分岐を罰しないことである。
配備の性質は、[platforms](./platforms.md) に従う。
撤回条件は、無償の Community Build で quality gate と S3776 が提供されなくなることであり、リリースポリシーの変化を再評価のトリガーとする。

## 契約駆動の fuzz

用途は、生成した OpenAPI を駆動元にした契約駆動の fuzz である。
採用は、Schemathesis である。
判断基準は、契約から検査を導出でき、実装の言語に依存しないことである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## ドキュメントコメントの体裁検査

用途は、ドキュメントコメントの存在、構文、宣言と tag の機械判定できる対応、最初の一行と句読点を検査する道具である。
採用は、C# は Roslyn の documentation-comment analyzer、TypeScript は TypeScript compiler API と `@microsoft/tsdoc` を使う構造検査である。
判断基準は、comment の存在と構文、宣言と tag の対応、最初の一行と句読点を一律に検査し、違反をリポジトリの検証入口で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Roslyn、TypeScript compiler API、`@microsoft/tsdoc` の互換性の変化を再評価のトリガーとする。

## SQL の parameter 対応検査

用途は、SQL 中の placeholder と parameter member の対応を DB を起動せずに補助検査する道具である。
採用は、C# は DapperAOT である。
判断基準は、PostgreSQL では補助検査として basic match の診断を使い、列の型と nullable を含む最終判定を [languages の csharp/retention](../languages/csharp/retention.md) が定める SQL と DTO の照合テストで行うことである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## SBOM の既知脆弱性検査

用途は、release 成果物の SBOM を既知脆弱性と照合し、検出を release の失敗にする道具である。
採用は、OSV-Scanner である。
判断基準は、SPDX の SBOM を入力にでき、言語を横断して既知脆弱性が一件でもあれば非ゼロの終了値を返すことである。
撤回条件は、判断基準を満たさなくなることであり、advisory database の更新停止と保守の停止を再評価のトリガーとする。
