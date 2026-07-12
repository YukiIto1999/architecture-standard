# inspection

inspection は、検証の道具の採用を定める。
エントリは、[README](./README.md) の書式と選定の共通基準に従う。
道具の使い方と規則の割り当ては、[languages](../languages/) の inspection と [structure/tests](../structure/tests/layout.md) に従う。

## 整形

用途は、表記を道具の既定で一意に揃える formatter である。
採用は、Rust は rustfmt、C# は CSharpier、TypeScript は oxfmt である。
判断基準は、既定の設定で出力が一意に決まることである。
CSharpier は、設定項目が少ない opinionated な formatter で、.editorconfig の書き方に出力が左右されない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と oxfmt の安定版のリリースを再評価のトリガーとする。

## lint

用途は、規則の違反をビルドで止める linter である。
採用は、Rust は clippy、C# は SonarAnalyzer.CSharp、TypeScript は oxlint と tsgolint の type-aware 実行である。
判断基準は、規則を全体に一律に強制でき、警告を CI でエラーとして扱えることである。
SonarAnalyzer.CSharp は、cognitive complexity(S3776)を実装する数少ない候補で、保守も活発である。
oxlint は、既に採用した Vite・Vitest と同じ基盤の単一の linter で、tsgolint の type-aware 実行により floating promise や unsafe な型変換を検出できる。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Vite Plus の統合 CLI(vp)の 1.0 到達を再評価のトリガーとする。

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
判断基準は、Gherkin の記法で smoke を書きながら実行を Playwright の runner に委ねられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## mutation

用途は、テストが振る舞いを固定しているかを測る mutation 検査である。
採用は、Rust は cargo-mutants、C# は Stryker.NET、TypeScript は Stryker である。
判断基準は、生存した mutant を exit code で報告し、CI を失敗で止められることである。
cargo-mutants は、生存した mutant の有無を exit code で報告するので、しきい値は検出されない mutant が無いという二値の床になる。
Stryker.NET は、test-runner を mtp に設定すれば、Microsoft.Testing.Platform 専用の TUnit のテストを発見して mutation を実行できる。
撤回条件は、判断基準を満たさなくなることであり、test runner の対応状況の変化と Stryker.NET の mtp test-runner の正式化を再評価のトリガーとする。

## 構造検査

用途は、依存方向と境界の禁止を実行できる検査として検証する道具である。
採用は、Rust は自作(root の tests/ に置く構造検査)、C# は ArchUnitNET、TypeScript は dependency-cruiser である。
判断基準は、層の参照禁止・公開面・副作用の参照禁止を規則として書け、違反を CI で止められることである。
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

## 契約の記述と生成

用途は、契約の意味の正本の記述と、そこからの client・型の生成である。
採用は、記述は TypeSpec、OpenAPI の出力は `@typespec/openapi3`、生成は Rust が openapi-generator の rust generator(library=reqwest)、C# が NSwag(client・型の生成に限る)、TypeScript が openapi-typescript である。
判断基準は、判別のある直和を判別が生成先で保たれる形で記述できることと、生成の入口が安定した OpenAPI であることである。
`@typespec/openapi3` は OpenAPI を安定した出力として持ち、openapi-generator は生成元を特定の emitter に縛らない。
openapi-typescript は型定義だけを出力し、runtime のコードを持たない。
撤回条件は、判断基準を満たさなくなることであり、emitter と generator の対応状況の変化と typespec-rust の unbranded 化を再評価のトリガーとする。

## ドキュメントコメントの体裁検査

用途は、ドキュメントコメントの最初の一行の体裁と節の網羅を検査する道具である。
採用は、C# は companion の自作 analyzer である。
判断基準は、既製の analyzer(StyleCop.Analyzers・Meziantou.Analyzer・SonarAnalyzer.CSharp)がいずれも保守停止か、この標準の体裁要求を実装していないことである。
撤回条件は、判断基準を満たさなくなることであり、既製 analyzer の対応状況の変化を再評価のトリガーとする。

## SQL の parameter 対応検査

用途は、SQL 中の変数と parameter の対応を DB を起動せずに検査する道具である。
採用は、C# は DapperAOT である。
判断基準は、ソース生成に基づくビルド時解析で、DB へ接続せずに対応を検査できることである。
DapperAOT は DB のスキーマを参照しないため、列の型と nullable の対応は対象外であり、structure/tests の照合テストで別に埋める。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## orchestrator

用途は、言語ごとの package を横断する build の実行である。
採用は、単一の名指しを持たず、project が単一の採用を ADR に明記する。
判断基準は、package の依存境界を強制できることと、依存グラフから変更の影響範囲を出して差分で build とテストを行えることである。
依存境界を強制できない orchestrator を、選ばない。
撤回条件と再評価のトリガーは、採用を記録する project の ADR に定める。
