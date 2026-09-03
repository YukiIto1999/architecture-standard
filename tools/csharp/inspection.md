# inspection

## 概要
inspection は、C# で検証を扱う実現軸である。
principles の [verification](../../principles/verification/README.md) が定める検証の機械化を、C# の機構で満たす。

## ドキュメントコメントの検査

### 要求
CS1591 を `WarningsAsErrors` でエラー扱いにし、公開の型・メンバのドキュメントコメントの欠落をビルドの失敗にする。
NoWarn で CS1591 を抑止しない。
公開範囲を問わず全ての型とメンバにコメントがあることは、Roslyn analyzer で検査する。
summary の先頭行の体言止め・句読点禁止・一行の体裁と、param・typeparam・returns・value の網羅は Roslyn analyzer で検査する。
当該宣言内の直接の throw など、構文と semantic model で判定できる欠陥に対応する exception は Roslyn analyzer で検査する。
呼び出し先から伝播して当該宣言の契約になる欠陥と exception の対応は、公開範囲を問わずレビューで確かめる。
内容が、実効的な可視境界を基準に、境界外へ公開される宣言では外部契約を、同一境界内だけの宣言では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致しているかは、レビューで確かめる。

### 根拠
CS1591 は `GenerateDocumentationFile` を有効にしたときだけ発火する既定 level 4 の警告で、エラー扱いにしなければビルドを止めない。
CS1591 が検出するのは公開の型とメンバのコメント欠落だけであり、非公開の宣言やコメントの項目と体裁は検査しない。
NoWarn は CS1591 を丸ごと無効化し、欠落の検出そのものを消す。
全宣言での存在と項目と体裁の検査は Roslyn analyzer で実現する。
直接の throw などは、構文と semantic model から当該宣言の exception と対応づけられる。
呼び出し先から伝播する欠陥が当該宣言の契約に含まれるかは、呼び出しの意味を読むレビューが要る。
内容が可視性に応じた外部契約または内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致しているかの判断は意味を読む必要があり、機械化できない。

### 完了条件
CS1591 が、`WarningsAsErrors` でエラー扱いになっている。
CS1591 が、NoWarn で抑止されていない。
全ての型とメンバのコメントの存在が、Roslyn analyzer で検査されている。
summary の先頭行の体裁と param・typeparam・returns・value の網羅が、Roslyn analyzer で検査されている。
当該宣言内で機械判定できる欠陥と exception の対応が、Roslyn analyzer で検査されている。
呼び出し先から伝播して当該宣言の契約になる欠陥と exception の対応が、公開範囲を問わずレビューで確かめられている。
内容が、境界外へ公開される宣言では外部契約を、同一境界内だけの宣言では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致していることが、レビューで確かめられている。

### 禁止事項
CS1591 を、NoWarn で抑止すること。
CS1591 だけで、全宣言のコメントの存在と項目と体裁を検査できるとみなすこと。
呼び出し先から伝播する欠陥まで、Roslyn analyzer で網羅できるとみなすこと。

### 行動
`GenerateDocumentationFile` を有効にし、`WarningsAsErrors` に CS1591 を加える。
Roslyn analyzer で全宣言のコメントの存在、param・typeparam・returns・value、先頭行の体裁を検査し、検証入口で実行する。
Roslyn analyzer で当該宣言内の機械判定できる欠陥と exception の対応を検査し、検証入口で実行する。
公開範囲を問わず、呼び出し先から伝播して当該宣言の契約になる欠陥と exception の対応をレビューする。
ドキュメントコメントが、実効的な可視境界を基準に、境界外へ公開される宣言では外部契約を、同一境界内だけの宣言では内部契約を述べ、名前や実装の言い換えになっていないことをレビューする。

## nullable と警告を検証入口でエラーにする

### 要求
nullable reference types と analyzer の警告は、検証入口でエラーとして扱う。

### 根拠
nullable reference types と analyzer の警告をエラーにすれば、不在の取り違えや規則の違反がビルドで止まる。

### 完了条件
nullable reference types と analyzer の警告が、検証入口でエラーとして扱われている。

### 禁止事項
analyzer の警告を、エラーにせず警告のまま残すこと。

### 行動
nullable reference types を有効にし、警告を検証入口でエラーにする。

## 非同期の形と期限の伝播を analyzer で検査する

### 要求
Roslyn analyzer は、surface と host の公開非同期 API が Task または Task<T> を返し、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> を返すことを semantic model で検査する。
Roslyn analyzer は、request、message、job の境界より内側の非同期 API が、非取消の後始末である `AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` を除き、Deadline と CancellationToken を必須引数に持つことを検査する。
Roslyn analyzer は、release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を行うことを検査する。
`IAsyncDisposable.DisposeAsync` の呼出側が、同じ Deadline を後始末の scope に保持することを検査する。
Deadline の生成が request、message、job の境界に限られることを検査する。
Roslyn analyzer は、各 hop の CancellationTokenSource が `deadline.Remaining(timeProvider)` から作られ、下流へ remaining でなく同じ Deadline が渡ることを検査する。

### 根拠
Roslyn semantic model なら、method の accessibility、戻り値、引数、呼出式の symbol を結び付け、公開 host API と Effect 内部の awaitable の役割を区別できる。
同じ model で Deadline の生成と伝播、remaining の使用先を追えば、hop ごとに新しい相対 timeout を始める経路を拒否できる。
release と `DisposeAsync` を CancellationToken の必須規則から明示的に分ければ、通常の非同期 API の伝播漏れと、非取消でなければならない後始末を混同しない。

### 完了条件
公開する surface と host の非同期 API が Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> に分かれている。
境界より内側の非同期 API が、release と `DisposeAsync` を除いて Deadline と CancellationToken を必須引数に持ち、Deadline が request、message、job の境界だけで生成されている。
release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を完了している。
各 hop の局所 timeout が `deadline.Remaining(timeProvider)` から作られ、同じ Deadline が下流へ渡されている。

### 禁止事項
公開 host API と Effect 内部の awaitable の役割分担を、レビューだけで検査すること。
hop ごとに相対 timeout を引き直す経路を、構造検査から外すこと。
release と `DisposeAsync` へ CancellationToken を要求し、非取消の後始末を通常の非同期 API と同じ規則で検査すること。

### 行動
Roslyn analyzer で、公開 host API の Task と Effect 内部の ValueTask の戻り値を検査する。
Roslyn analyzer で、境界より内側の非同期 API の Deadline と CancellationToken、境界だけでの Deadline 生成、remaining からの局所 timeout 生成、同じ Deadline の下流伝播を検査する。
release と `DisposeAsync` は CancellationToken の必須規則から除き、元の Deadline を保持する非取消の後始末として検査する。

## 汎用名を自作 analyzer で禁止する

### 要求
識別子の汎用名は、denylist を持つ自作の Roslyn analyzer で禁止し、違反を検証入口のエラーとして扱う。
denylist には、data・info・temp・result・manager・helper のような役割を示さない名前を登録する。

### 根拠
data・info・temp のような汎用名は生成時に混入しやすく、denylist は [restrict-generic-names](../../principles/naming/restrict-generic-names.md) の「汎用名・略語・一時名を制限する」を識別子の検査として機械化する。
採用済みの linter に識別子の denylist の規則がないため、自作の Roslyn analyzer で補う。

### 完了条件
汎用名の denylist を持つ analyzer が検証入口で実行され、違反がエラーとして扱われている。

### 禁止事項
denylist を空にして検査を無効化すること。

### 行動
libs の analyzer project に denylist の analyzer を実装し、違反箇所は役割を示す名前へ付け直す。
analyzer の置き場は [formation](./formation.md) の「検証と生成を libs の analyzer project に分ける」に従う。

## Result の非網羅な取り出しを analyzer で禁止する

### 要求
判別共用体の Result からの値の取り出しは、網羅的な switch か全域の combinator に限る。
派生型への cast による直接の取り出しは、自作の Roslyn analyzer で検出し、検証入口のエラーとして扱う。

### 根拠
派生型への cast は不成功の分岐を型検査から外し、[total-functions](../../principles/construction/total-functions.md) の「関数を全域にする」に反する部分関数を作る。
採用済みの linter に判別共用体の網羅的な取り出しを検査する規則がないため、自作の Roslyn analyzer で補う。

### 完了条件
Result の値の取り出しが、網羅的な switch か全域の combinator で行われている。
派生型への cast による取り出しが、検証入口でエラーとして扱われている。

### 禁止事項
Result の派生型へ cast して、不成功の分岐を検査せずに値を取り出すこと。

### 行動
libs の analyzer project に、Result の派生型への cast を検出する analyzer を実装する。
違反箇所は、網羅的な switch か全域の combinator へ直す。

## 規則と検証機構の対応

この言語 ecosystem の全規律を、検証手段へ写像する。
規律は軸 file と採用したツールの file に住み、file 列は規律が住む file の名前である。
標準 repository の verifier は、ecosystem の全 file の規律を表す H2 見出しの集合と、この対応表の規律の集合を照合し、欠落、余分、重複があれば失敗する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| file | 規律 | 検証手段 |
|---|---|---|
| tunit | 実行 | 実行テスト(TUnit の単体・性質・結合を検証入口で実行し、発見件数0を失敗にする) |
| cscheck | 性質 | 実行テスト(CsCheck の生成・縮小・stateful property と回帰 seed の再実行) |
| reqnroll | 仕様 | 構造検査(feature・step binding・公開 interface operation の実体由来一覧の drift)+実行テスト(Reqnroll.TUnit を実装と同じ検証入口で実行) |
| testcontainers | 実依存 | 実行テスト(Testcontainers for .NET の割当 host・port を使う結合テストと終了時の破棄)+runner 検査(TUnit `--list-tests` の tree node ID を native test ID とする size ごとの排他・全域集合一致、発見件数0の拒否、実行環境の資源制限。Reqnroll scenario は同じ TUnit discovery の ID を使う) |
| stryker-net | 有効性 | mutation(Stryker.NET の未検出 mutant 0件 gate と発見件数0の失敗) |
| archunit-net | 構造 | 構造検査(ArchUnitNET が skeleton の両表から runtime・build・test edge を生成し、runtime 成果物への build・test edge 混入を失敗にする) |
| sonaranalyzer-csharp | 予防 | analyzer/lint(SonarAnalyzer.CSharp・BannedApiAnalyzers・Roslyn analyzer の設定と診断を検証入口でエラー化) |
| inspection | ドキュメントコメントの検査 | analyzer/lint(CS1591 と Roslyn analyzer)+レビュー(実効的な可視境界に応じた外部契約または内部契約、伝播する欠陥、再述でない意味) |
| formation | 業務の値を型に封じる | 型(record・非公開 constructor・static factory) |
| formation | 不正な状態を構築できなくする | 型(sealed record 階層)+analyzer(Roslyn suppressor・網羅の警告のエラー化)+構造検査(ArchUnitNET。階層外派生の検出) |
| formation | 継承を判別共用体に限る | レビュー(継承の目的の判断) |
| formation | 不変を既定にする | 型(init 専用プロパティ) |
| formation | 意味と単位を型で区別する | 型(record) |
| formation | 検証と生成を libs の analyzer project に分ける | 構造検査(analyzer project 境界)+型(netstandard2.0 の Analyzer 参照制約) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(CSharpier チェック、production の SonarAnalyzer.CSharp 命名規則、test project では Sonar の method 命名規則だけを抑止して命名 analyzer で test attribute 付き entry の snake_case とその他 method の .NET 命名を検査) |
| conventions | ドキュメントコメントを書く | analyzer/lint(CS1591 エラー化。公開要素のコメント欠落)+analyzer(Roslyn analyzer。全宣言のコメント存在・param/typeparam/returns/value・先頭行・当該宣言内で機械判定できる欠陥の exception)+レビュー(実効的な可視境界に応じた外部契約または内部契約、伝播する欠陥、再述でない意味) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(ArchUnitNET の命名照合) |
| 全域 | branch coverage と safety-critical decision | 計測(branch を数える設定は Microsoft.Testing.Extensions.CodeCoverage の cobertura 出力と managed instrumentation であり、その branch 情報から project 記録の branch 下限を検証入口で判定)+構造検査・実行テスト([structure/tests の methods](../../structure/tests/methods.md) が定める safety analysis と MC/DC case の一対一照合) |
| translation | 境界で一度だけ parse してドメイン型へ移す | 型(JsonSerializerContext・required・JsonExtensionData)+実行テスト(境界の parse の単体テスト・未知フィールドのログ出力の単体テスト) |
| aspnet-core | 公開するエラーを境界で problem+json へ写す | 実行テスト(ProblemDetails の単体テスト) |
| nswag | 生成した契約を使い、drift を検査の gate にする | 実行テスト(drift 検査・conformance の検証入口の判定) |
| connection | 効果を Effect 型で組む | 型(readonly struct、Deadline と CancellationToken を受けて ValueTask を返す delegate の内包)+analyzer(Roslyn analyzer。明示的 `default(Effect<...>)`、Effect への `default` literal の代入、型解決で Effect と判定できる `default(T)` の検出)+実行テスト(配列、field、未解決の generic 由来の default を EffectRuntime.Run で実行すると Defected の `UninitializedEffectException` になること) |
| connection | 効果の生成と combinator と資源を備える | 型(EffectContext の Success/Try は引数から TValue を推論し、Fail<TValue>/Defect<TValue> は値型を明示する生成関数、Try body は Deadline、CancellationToken、ValueTask の delegate、AcquireRelease release は Deadline を受けるが CancellationToken を受け取らない ValueTask の delegate、拡張 method の combinator のシグネチャ)+analyzer(Roslyn analyzer。全 combinator が Run から受けた同じ Deadline を下流の Effect と release へ渡し、release を非取消の後始末にすること)+実行テスト(AcquireRelease の単体テスト、取消済み token の下でも release が同じ Deadline を受けて一度完了すること、複数の Bind を通っても期限が引き直されないこと) |
| connection | 終了を成功と失敗と欠陥と取り消しに分ける | 型(sealed record 階層の EffectExit、Result の tag 0 は未初期化)+analyzer(Roslyn analyzer。明示的 default(Result)、Result への default literal の代入、型解決できる default(T) の検出)+実行テスト(配列・field・generic 由来の default が全 observer・Match・unwrap 相当で欠陥になること)+構造検査(formation の階層外派生の検出に従う) |
| connection | 要求する依存を型に出す | 型(IEffectRequirements・generic constraints)+analyzer(Roslyn analyzer。NoRequirements への迂回の検出) |
| connection | 効果を境界で実行し analyzer と generator で縛る | analyzer と source generator(internal の EffectRuntime.Run に実行境界を限定し、Deadline と CancellationToken の伝播、ValueTask の戻り値、R の合成環境の生成、Bind 連鎖の要求包含、原始効果の閉じ込め、NoRequirements への迂回を検査)+実行テスト(`UninitializedEffectException` を Defected へ写すこと) |
| connection | port を interface で宣言する | 型(interface) |
| connection | 配線を composition root に限る | 構造検査(IServiceProvider の直接解決の検出)+レビュー |
| dapper | 型付き SQL | analyzer(DapperAOT の DAP214・DAP236)+実行テスト(型・nullable の照合テスト) |
| npgsql | 並行更新の表面 | 実行テスト(結合テストでの競合検出) |
| npgsql | 書き込みパス | 構造検査(store が transaction の begin・commit を持たないことの検査) |
| npgsql | 冪等な要求の記録 | 構造検査(operation・actor scope・tenant・key の NOT NULL と複合一意制約)+実行テスト(認証済み actor、匿名の安定した opaque scope、logical system actor の分離、multi-tenant の検証済み TenantId、single-tenant sentinel、no-tenant sentinel、三表現の相互混同と未検証 tenant の拒否、scope のない匿名要求の server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否、同じ scope/key の並行競合、異なる fingerprint の conflict、業務結果・fingerprint・response の同時 rollback) |
| npgsql | durable inbox | 構造検査(scope・event ID の複合一意制約)+実行テスト(payload commit 前後の停止と upstream delivery ack、処理結果・処理済み記録 commit 前後の停止と inbox processing completion、前段の source 再配送、後段の item 再処理、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視出力) |
| stackexchange-redis | 一時データ | 構造検査(DB と Valkey の project 分離)+レビュー |
| coordination | 非同期 | analyzer/lint(SonarAnalyzer.CSharp の async void 検出規則)+analyzer(Roslyn analyzer。surface と host の公開非同期 API は Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release は ValueTask または ValueTask<T> に限定)+レビュー(domain の純粋性の判断) |
| coordination | 取り消し | analyzer(Roslyn analyzer。request、message、job の境界より内側の非同期 API が、非取消の後始末である AcquireRelease release と IAsyncDisposable.DisposeAsync を除いて Deadline と CancellationToken を必須引数に持ち、Deadline の生成を境界へ限定し、各 hop の局所 timeout が `deadline.Remaining(timeProvider)` から作られ、下流へ remaining でなく同じ Deadline が渡ることを検査。release は同じ Deadline を受けて CancellationToken を受け取らず、DisposeAsync は引数を持たないことを検査)+実行テスト(複数 hop で時間枠が引き直されず、局所 timeout が linked token で下流へ伝播すること、取消後も release と DisposeAsync が非取消で完了すること) |
| coordination | 並行の組 | 構造検査(Roslyn analyzer。個別 job の RunAsync 呼出しを SemaphoreSlim の permit 保持区間へ限定)+実行テスト(実行中の job が SemaphoreSlim の上限を越えない最大同時実行数)+レビュー(Task.WhenAny の失敗検知、兄弟用 CancellationTokenSource の取消、cancel callback 例外の収集、Task.WhenAll の drain、task と callback と外部取消の集約) |
| coordination | blocking 禁止 | analyzer/lint(Microsoft.CodeAnalysis.BannedApiAnalyzers) |
| coordination | 共有状態 | レビュー |
| coordination | ライブラリの作法 | analyzer/lint(SonarAnalyzer.CSharp の ConfigureAwait 関連規則) |
| coordination | 資源解放 | 型(using/await using、IDisposable、引数なしの IAsyncDisposable.DisposeAsync)+analyzer(Roslyn analyzer。AcquireRelease release と DisposeAsync を CancellationToken の必須規則から除外し、元の Deadline を保持する非取消の後始末として識別)+実行テスト(取消後も DisposeAsync が一度完了すること) |
| aspnet-core | server | 構造検査(middleware の順序と core 公開 API への ClaimsPrincipal・token・claim 型の流入禁止)+実行テスト(検証済み ClaimsPrincipal から actor への写像、actor と検証済み入力による core 公開 API 呼出、multi-tenant の TenantId・single-tenant sentinel・no-tenant sentinel の写像と相互混同拒否、server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否)+レビュー |
| aspnet-core | BFF | 構造検査(request-scoped ActorRequestContext から Actor を DI すること、ActorMapper 呼出を認証 middleware に限定すること、route の ClaimsPrincipal 参照と actor 再構築を拒否すること、route が埋め込んだ core の公開 API だけを呼ぶこと)+実行テスト(cookie 属性、認証 middleware が ActorRequestContext へ格納した actor と route に注入された Actor の一致、actor と検証済み入力による core 公開 API 呼出) |
| consoleappframework | console | 型(ConsoleAppFramework の constructor injection) |
| wolverine | worker | 構造検査(Wolverine の永続化設定・IMessageBus の constructor injection の検出)+実行テスト(payload commit 後の upstream delivery ack、処理結果・処理済み記録 commit 後の inbox processing completion、各停止点の再配送、安定した effect operation と event ID の冪等キー、外部効果成功後の処理済み記録、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視)+レビュー(CancellationToken の伝播) |
| 全域 | cast allowlist | analyzer(Roslyn analyzer。reporting boundary の型消去 symbol と検証を完結する converter または factory の型構築 symbol を別の allowlist として照合し、集合外と種類不一致の cast を拒否)+実行テスト(converter または factory が検証後だけ型を構築) |
| photino | desktop の host | レビュー |
| maui-hybridwebview | mobile の host | レビュー |
| streamjsonrpc | extension の接続 | 型(StreamJsonRpc の型付き proxy)+レビュー |
| publication | 可視性 | 型(internal・file 修飾子) |

| banned-api-analyzers | 直読と自由文出力を禁止 API で止める | analyzer/lint(BannedApiAnalyzers の禁止一覧を検証入口でエラー化) |

| inspection | nullable と警告を検証入口でエラーにする | analyzer/lint(nullable reference types と WarningsAsErrors の compiler 設定) |
| inspection | 非同期の形と期限の伝播を analyzer で検査する | 構造検査(自作 Roslyn analyzer を検証入口で実行) |

| inspection | 汎用名を自作 analyzer で禁止する | analyzer/lint(自作 Roslyn analyzer の denylist を検証入口でエラー化) |
| inspection | Result の非網羅な取り出しを analyzer で禁止する | analyzer/lint(自作 Roslyn analyzer の cast 検出を検証入口でエラー化) |
## 参照
検証の機械化と実行可能な仕様の検査経路は [verification](../../principles/verification/README.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
