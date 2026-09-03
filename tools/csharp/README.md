# csharp ecosystem

csharp の言語としての採用と、実現規律、採用物を置く。
言語の採用は、.NET 10 と C# 14 である。
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
| [conventions](./conventions.md) | ドキュメントコメント・型名接尾辞(全域規律) |

## 採用

採用物ごとに一つの file を置き、用途・採用・判断基準・撤回条件を持つ。

| ファイル | 用途 | 採用 |
|---|---|---|
| [archunit-net](./archunit-net.md) | 依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である | C# は ArchUnitNET である |
| [aspnet-core](./aspnet-core.md) | server・server の middleware・BFF の session 管理・OIDC クライアント | C# は ASP.NET Core の Minimal API である |
| [banned-api-analyzers](./banned-api-analyzers.md) | 禁止した API の呼び出しを、ビルドで検出する検査である | C# は Microsoft.CodeAnalysis.BannedApiAnalyzers である |
| [consoleappframework](./consoleappframework.md) | CLI の surface の骨格である | C# は ConsoleAppFramework である |
| [cscheck](./cscheck.md) | 入出力の不変量を性質として多くの入力で検査する property-based testing である | C# は CsCheck である |
| [csharpier](./csharpier.md) | 表記を道具の既定で一意に揃える formatter である | C# は CSharpier である |
| [dapper-aot](./dapper-aot.md) | SQL 中の placeholder と parameter member の対応を DB を起動せずに補助検査する道具である | C# は DapperAOT である |
| [dapper](./dapper.md) | SQL を型で扱いながら書く永続化アクセス層である | C# は Npgsql の上の Dapper である |
| [duende-access-token-management](./duende-access-token-management.md) | BFF が保持する token の交換と更新を担う機構である | C# は Duende.AccessTokenManagement である |
| [grate](./grate.md) | schema を変更する forward-only の SQL script を、履歴順に一度だけ、アプリの配備から独立して適用する道具である | C# は grate の up の one-time script である |
| [maui-hybridwebview](./maui-hybridwebview.md) | 被ホストの viewer と core を利用者の端末で動かす host である | core が C# のときは mobile は .NET MAUI の HybridWebView である |
| [microsoft-testing-extensions-code-coverage](./microsoft-testing-extensions-code-coverage.md) | テストが実行していない箇所を見つけるカバレッジ計測である | C# は Microsoft.Testing.Extensions.CodeCoverage である |
| [npgsql](./npgsql.md) | PostgreSQL へ接続し、transaction の確定と制約違反の判別を担う data provider である | C# は Npgsql である |
| [nswag](./nswag.md) | 契約から C# の client と型を生成し、drift・conformance の検査に使う道具である | C# は NSwag である |
| [photino](./photino.md) | 被ホストの viewer と core を利用者の端末で動かす host である | core が C# のときは desktop は Photino.NET である |
| [reqnroll](./reqnroll.md) | 業務語彙の executable spec を実行する道具である | C# は Reqnroll である |
| [roslyn-documentation-comment-analyzer](./roslyn-documentation-comment-analyzer.md) | ドキュメントコメントの存在、構文、宣言と tag の機械判定できる対応、最初の一行と句読点を検査する道具である | C# は Roslyn の documentation-comment analyzer である |
| [sonaranalyzer-csharp](./sonaranalyzer-csharp.md) | 規則の違反をビルドで止める linter である | C# は SonarAnalyzer.CSharp である |
| [stackexchange-redis](./stackexchange-redis.md) | Valkey へ接続する client である | C# は StackExchange.Redis である |
| [streamjsonrpc](./streamjsonrpc.md) | extension が接続する core のプロセスとの間で、JSON-RPC の小さい契約だけを外へ出す機構である | C# は StreamJsonRpc である |
| [stryker-net](./stryker-net.md) | テストが振る舞いを固定しているかを測る mutation 検査である | C# は Stryker.NET の MTP runner(preview)である |
| [testcontainers](./testcontainers.md) | 実依存のコンテナを起動し、本物に近い依存で検証する道具である | C# は Testcontainers for .NET である |
| [tunit](./tunit.md) | 単体・性質・結合のテストの実行系である | C# は TUnit である |
| [wolverine](./wolverine.md) | 背景処理と定期実行の daemon の骨格である | C# は Wolverine であり、PostgreSQL を backend にした queue に限って使う |

## 言語機構で満たす用途

外部の採用物を持たず、言語機構または既存の採用で満たす用途を示す。

| 用途 | 満たし方 | 置き場 |
|---|---|---|
| 非同期の runtime | 言語・実行環境に組み込みの非同期基盤を使い、外部の runtime を別に選ばない | [coordination](./coordination.md) |
| 取り消しの伝達 | 組み込みの機構(CancellationToken)で表し、外部ライブラリを採らない | [coordination](./coordination.md) |
| viewer・extension・host の効果の表現 | libs の Effect 型と Result 型で表し、外部ライブラリを採らない | [connection](./connection.md) |
| エラー型の定義 | sealed record の階層という言語機構で表し、外部ライブラリを採らない | [formation](./formation.md) |
| 直列化 | 言語標準の source generation(JsonSerializerContext)を使い、外部の直列化ライブラリを別に選ばない | [translation](./translation.md) |
| 未使用コードの検出 | コンパイラと lint の到達可能性に基づく検出で満たし、専用の道具を置かない | [inspection](./inspection.md) |
| UI の accessibility 検査 | viewer を TypeScript に委ねるため採用を持たない | — |
