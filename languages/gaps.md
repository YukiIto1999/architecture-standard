# 未充足台帳

## 概要
この台帳は、上位規律が求める能力について、Rust・C#・TypeScript の充足状況を横断して示す。
各言語の実現は、それぞれの実現軸ファイルを正本とする。
この台帳は、不揃いと未充足を見つけるための索引であり、新しい採用機構を決めない。
セルに採用機構を書くときは、対応する実現軸ファイルの名指しと一致させる。

## セルの値
表のセルは、次の値で書く。

- 言語機能は、言語の構文・型システムが標準への追加なしに満たす状態を示す。
- 採用は、対応する実現軸ファイルが名指す既製の機構で満たす状態を示す。
- 自作は、companion または submodule として作った機構で満たす状態を示す。
- 未充足は、採用済みの機構も自作済みの機構もない状態を示す。
- 対象外は、その言語の役割に能力が及ばず、満たす対象にしない状態を示す。

未充足のセルには、自作・委譲のどちらで扱うかを書く。
対象外は、未充足の扱いに含めない。
自作は、companion または core の submodule として機構を作る扱いである。
委譲は、project が単一の採用または検証方法を ADR に明記する扱いである。
対象外は、機構化を追求しない扱いである。

TypeScript は viewer・extension・web と ide の host だけを担い、Rust と C# が担う server・console・worker を担わない。
対象外の多くは、この役割の差による。
役割の差は [languages/README](./README.md) の言語と役割の表に従う。

## 更新
新しい未充足を見つけたら、standard-update の手順でこの台帳へ行を足す。
自作を実装したら、実装した機構名をセルに書き、未充足の扱いから自作の状態へ変える。

## 型と網羅
閉じた直和・値の封入・不変の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 業務値の型封入 | 言語機能(newtype tuple struct・非公開フィールド) | 言語機能(record・非公開 constructor・static factory) | 採用(valibot の brand・safeParse) |
| 閉じた直和の網羅維持 | 言語機能(enum・網羅 match・コンパイラの網羅性検査) | 自作(sealed record 階層・companion の CS8509 抑止 suppressor・ArchUnitNET の階層外派生検査) | 言語機能(判別子つき union・never 網羅) |
| 継承を判別共用体に限る検証 | 対象外(enum が閉じた直和を言語機能として提供する) | 未充足(自作: companion の検査で、閉じた階層の外にある継承を検出する) | 対象外(union が閉じた直和を言語機能として提供する) |
| 不変性の型強制 | 言語機能(所有権・既定で不変な束縛) | 言語機能(init 専用プロパティ) | 言語機能(readonly・as const) |

## 効果とエラー
効果システム・4つの終了(成功・想定内失敗・欠陥・取り消し)・出所での判別の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 効果システムの実装 | 言語機能(async fn の Future・Result・所有権。自前の効果モナドを重ねない) | 自作(Effect<TRequirements,TFailure,TValue> と、成功・想定内失敗・欠陥・取り消しを表す EffectExit の階層・combinator・default 構築を検出する companion analyzer) | 採用(neverthrow の Result・ResultAsync)・言語機能(環境と AbortSignal を受け取る関数の型) |
| 想定内失敗と欠陥の判別 | 言語機能(Result 対 panic) | 言語機能(TFailure の sealed record 階層 対 Defected) | 採用(neverthrow の Result 対 throw) |
| 配線誤用の機械検出 | 自作(root tests/ の構造検査。composition root 外の具象生成を検出)・レビュー(残りの判断) | 自作(root tests/ 相当の構造検査。IServiceProvider の直接解決を検出)・レビュー(残りの判断) | 未充足(自作: dependency-cruiser または oxlint の独自規則で、module 最上位の可変 export を検出する) |
| 純粋核に効果が侵入しないことの機械検証 | 未充足(自作: domain crate の async fn 定義を clippy の独自 lint または proc-macro companion で検出する) | 未充足(自作: ArchUnitNET の規則で、domain 名前空間から Task を返す型を検出する) | 未充足(自作: dependency-cruiser または oxlint の独自規則で、domain 層の async・await と Promise を禁止する) |

## 取り消しと期限
協調取り消し・絶対期限の伝播の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 協調取り消しの伝播検証 | 未充足(委譲: project が統合テストで select! の分岐の cancellation safety を検証する) | 未充足(委譲: project が統合テストで CancellationToken が下流まで渡ることを検証する) | 採用(AbortSignal の伝播の単体テスト) |
| 絶対期限の文脈伝播機構 | 未充足(委譲: project の ADR に単一機構を明記する。規律は [coordination](./rust/coordination.md) に置く) | 未充足(委譲: project の ADR に単一機構を明記する。規律は [coordination](./csharp/coordination.md) に置く) | 未充足(委譲: project の ADR に単一機構を明記する。相対期限だけで済ませない) |

## 並行
構造化並行・並行度上限・背圧の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 並行度上限の機構 | 採用(tokio::sync::Semaphore) | 採用(SemaphoreSlim・Parallel.ForEachAsync の MaxDegreeOfParallelism) | 未充足(委譲: project の ADR に単一機構を明記する) |
| 背圧の機構 | 採用(bounded な mpsc channel) | 採用(bounded な System.Threading.Channels) | 対象外(TypeScript は producer・consumer 型の背圧処理を担わない) |
| 構造化並行のグループ失敗時取り消しの検証 | 未充足(委譲: project が統合テストで JoinSet::shutdown による残りのタスクの取り消しを検証する) | 未充足(委譲: project が統合テストで linked CancellationTokenSource による兄弟の取り消しを検証する) | 採用(AbortController での一括 abort の単体テスト) |
| 共有可変状態の lock 保持検査 | 採用(clippy::await_holding_lock) | 未充足(自作: lock 文や SemaphoreSlim.WaitAsync の前後に await が挟まる形を Roslyn analyzer で検出する) | 対象外(TypeScript は channel を受け取る単一の実行へ状態を閉じ込める) |

## 資源
資源の取得と解放の統合の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 資源の取得解放の言語機構統合 | 言語機能(所有権と Drop) | 言語機能(using・await using)・自作(Effect の AcquireRelease combinator) | 採用(onCleanup・host の Disposable 管理) |
| 後始末の登録漏れ検証 | 対象外(Drop が生存期間の終わりに必ず呼ばれる) | 対象外(using・await using が解放を強制する) | 未充足(自作: onCleanup の呼び出しが無い購読・イベント登録を oxlint の独自規則で検出する) |

## 永続化
型付き SQL・schema migration・並行更新の版衝突検出の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 型付き SQL | 採用(sqlx の query!・query_as! のコンパイル時検証) | 採用(Npgsql 上の Dapper の薄い写像・DapperAOT) | 対象外(TypeScript は server 側の永続化を持たない) |
| schema migration の適用機構 | 採用(sqlx-cli の sqlx migrate。forward-only) | 未充足(委譲: project が単一の migration 実行ツールを ADR に明記する) | 対象外(TypeScript は server 側の永続化を持たない) |
| 並行更新の版衝突検出(CAS) | 採用(UNIQUE 制約違反の検出と Result への変換) | 採用(一意制約違反の検出と Result への変換) | 対象外(TypeScript は server 側の永続化を持たない) |

## 認証部品
BFF・phantom token の交換・m2m の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| BFF 内部機構の抽象化と token 保持 | 自作(tower-sessions・fred・openidconnect を土台にした内部機構の封入) | 自作(YARP・cookie 認証・Duende.AccessTokenManagement・ITicketStore を土台にした内部機構の封入) | 対象外(BFF は server 側 media 境界の責務であり、TypeScript は session cookie を送るだけ) |
| phantom token 交換(外部 opaque から内部 JWT)の機構 | 未充足(自作: 内部 JWT を発行する機構を封入する) | 未充足(自作: 内部 JWT を発行する機構を封入する) | 対象外(TypeScript は server 側の token 交換を担わない) |
| system 間認証(m2m)の確立方式 | 未充足(委譲: [authentication](../concerns/authentication.md) に従い project の ADR に明記する) | 未充足(委譲: [authentication](../concerns/authentication.md) に従い project の ADR に明記する) | 対象外(TypeScript は system 間の呼び出しを開始しない) |
| 認証チケット・session の永続化 | 採用(tower-sessions・fred による Valkey 保持) | 採用(ITicketStore の実装・StackExchange.Redis による Valkey 保持) | 対象外(TypeScript は server 側の session 永続化を担わない) |

## 観測
構造化ログ・trace 伝播・利用者側の観測の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 構造化ログ・trace 伝播の機構 | 未充足(自作: OpenTelemetry SDK を薄く封入する submodule を shell に置く) | 未充足(自作: OpenTelemetry SDK を薄く封入する submodule を shell に置く) | 対象外(server 側の trace 伝播は Rust と C# が担う) |
| 利用者側の観測(viewer・extension host の telemetry) | 対象外(Rust は GUI viewer を担わない) | 対象外(C# は GUI viewer を担わない) | 未充足(自作: viewer と extension host の telemetry を扱う機構を作る。規律は observability に従う) |

## 検証の機械化
ドキュメントコメント・命名規約・網羅 suppressor・構造検査・mutation ゲート・SQL 束縛検証・複雑度の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 構造検査ツールそのもの | 未充足(自作: root tests/ の構造検査を実装し、import の走査で層参照禁止・公開面・配置文法を検査する) | 採用(ArchUnitNET) | 採用(dependency-cruiser) |
| ドキュメントコメントの存在検査 | 採用(missing_docs deny・clippy::missing_docs_in_private_items) | 採用(CS1591 の WarningsAsErrors 化) | 未充足(自作: TSDoc の存在を検査する companion tool。oxlint は存在検査を持たない) |
| ドキュメントコメントの体裁・網羅検査 | 採用(公開要素の節の網羅は clippy の missing_errors_doc・missing_panics_doc・missing_safety_doc)・未充足(自作: 最初の一行の体裁と非公開要素の節網羅を検査する) | 自作(companion の analyzer。summary の体裁と param・typeparam・returns・exception の網羅を検査する) | 未充足(自作: @typeParam・@throws の網羅と TSDoc の構文準拠を検査する companion tool) |
| ドキュメントコメントの内容とユビキタス言語の一致 | 対象外(意味判断なので機械化しない) | 対象外(意味判断なので機械化しない) | 対象外(意味判断なので機械化しない) |
| 命名規約(型は PascalCase・値は camelCase)の検査 | 採用(rustfmt --check・rustc の non_snake_case 系 lint) | 採用(CSharpier・SonarAnalyzer.CSharp の命名規則) | 未充足(自作: 型と値の PascalCase・camelCase を AST 検査で確かめる) |
| mutation ゲート | 採用(cargo-mutants。生存 mutant 0 件を床にする) | 採用(Stryker.NET。test-runner を mtp に設定) | 採用(Stryker。thresholds.break) |
| SQL 束縛検証 | 言語機能(sqlx のコンパイル時検証) | 自作(DapperAOT の DAP214・DAP236・SQL から抽出した列挙と DTO のプロパティを突き合わせる照合テスト) | 対象外(TypeScript は server 側の SQL を持たない) |
| 複雑度(cognitive complexity)の検査 | 採用(SonarQube の S3776) | 採用(SonarQube の S3776) | 採用(SonarQube の S3776) |
| host・公開面の構造検証 | 対象外(desktop・mobile host の配線は統合テストや E2E の領域とする) | 対象外(desktop・mobile host の配線は統合テストや E2E の領域とする) | 対象外(web host と styling の配線は UI E2E の領域とする) |

## 生成
契約 client・型の生成の充足状況。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| 契約からの client・型生成 | 採用(openapi-generator の rust generator。library=reqwest) | 採用(NSwag。client・型生成に限定) | 採用(openapi-typescript) |
| 契約準拠の server 実装の保証 | 未充足(自作: TypeSpec 由来の OpenAPI から axum の route・handler の雛形を生成する。drift・conformance 検査は併用する) | 採用(実装から Microsoft.AspNetCore.OpenApi で導出した OpenAPI と、canonical から生成した OpenAPI との drift 検査。server stub の生成は使わない) | 対象外(TypeScript は server 実装を担わない) |
| host 間 IPC の型付けの生成 | 対象外(desktop・mobile の host 接続は Tauri command、extension の接続は tower-lsp または JSON-RPC の型付き proxy で満たす) | 対象外(StreamJsonRpc の型付き proxy で満たす) | 未充足(自作: TypeSpec から postMessage の型を生成する。現在は手書きの valibot schema で代替する) |

## UI 系
TypeScript のみが担う styling・状態・a11y の充足状況。
Rust と C# の欄は、GUI viewer を担わないことによる対象外である。

| 能力 | Rust | C# | TypeScript |
|---|---|---|---|
| a11y の機械検証 | 対象外(GUI viewer を担わない) | 対象外(GUI viewer を担わない) | 未充足(委譲: project が既製の a11y 検査を ADR に明記する) |
| styling の規律の機械検証 | 対象外(GUI viewer を担わない) | 対象外(GUI viewer を担わない) | 対象外(design token の一元化や component 単位 CSS の回避は視覚判断を含む) |
| 状態管理パターンの機械検証 | 対象外(GUI viewer を担わない) | 対象外(GUI viewer を担わない) | 未充足(自作: createResource の出力を createStore へ複製する形を oxlint の独自規則で検出する) |
| props の分割代入禁止の機械検証 | 対象外(GUI viewer を担わない) | 対象外(GUI viewer を担わない) | 未充足(自作: oxlint 向けの規則を作る。eslint-plugin-solid の no-destructure は、単一 linter 採用との整合を ADR で裁定する) |

## 参照
検証の機械化は [verification](../principles/verification.md) に従う。
効果システムは [effect](../concerns/effect.md)、並行は [concurrency](../concerns/concurrency.md)、永続化は [persistence](../concerns/persistence.md)、認証は [authentication](../concerns/authentication.md)、観測は [observability](../concerns/observability.md)、利用者に向けた体験は [experience](../concerns/experience.md) に従う。
テストの技法と mutation の床は [structure/tests/methods](../structure/tests/methods.md) に従う。
各言語の詳細は [rust](./rust/)・[csharp](./csharp/)・[typescript](./typescript/) の該当する実現軸に従う。
