# inspection

## 概要
inspection は、C# で検証を扱う実現軸である。
principles の [verification](../../principles/verification.md) が定める検証の機械化と、[evolution](../../principles/evolution.md) が定める構造を機械で守ることを、C# の機構で満たす。

## 実行

### 要求
テストの実行は TUnit で行い、アサーションは await して実行する。
未 await のアサーションを検出する CS4014 は、WarningsAsErrors でエラー扱いにする。

### 根拠
TUnit はソース生成に基づき、テストの発見と実行を実行時のリフレクションに頼らない。
アサーションが awaitable な型を返すので、await せず文として使うとコンパイラが CS4014 を出す。
CS4014 を既定の警告のままにすると、await を忘れた検査が素通りしてもビルドは通る。
CS4014 を WarningsAsErrors でエラー化すれば、未 await の検査の取りこぼしがビルドで止まる。

### 完了条件
テストの実行が、TUnit で行われている。
アサーションが、await されている。
CS4014 が、WarningsAsErrors でエラー扱いになっている。

### 禁止事項
アサーションを await せず、検査を素通りさせること。

### 行動
テストを TUnit で書き、アサーションを await する。
`WarningsAsErrors` に CS4014 を加え、未 await のアサーションをビルドの失敗にする。

## 性質

### 要求
property-based testing は CsCheck で書き、状態の遷移は CsCheck の stateful な形で書く。

### 根拠
[verification](../../principles/verification.md) が定める、例だけを並べるより性質を書いて入力を多数生成すると見落とした場合が見つかるという要求に、CsCheck の入力生成で応える。
失敗した入力は最小化され、seed で再現できる。
状態の遷移は、操作の列を生成して実体とモデルの等価を確かめる stateful な形で突ける。

### 完了条件
性質が CsCheck で書かれ、入出力の不変量を多くの入力で突いている。
状態の遷移が、stateful な形で書かれている。

### 禁止事項
性質の本体を、常に成功する形にして何も検査しないこと。

### 行動
入出力の不変量を性質にし、CsCheck の Sample で多くの入力を突く。
状態の遷移は、実体とモデルを並べる stateful な形で書く。

### 例
```csharp
// 一つの例しか踏まない
[Test] public async Task Rev() => await Assert.That(Reverse(Reverse([1, 2, 3]))).IsEqualTo([1, 2, 3]);

// 性質を多くの入力で突く
Gen.Int.Array.Sample(values => values.Reverse().Reverse().SequenceEqual(values));
```

## 仕様

### 要求
業務語彙の executable spec は、実行可能にして仕様と実装の継ぎ目を消す。これを Reqnroll で満たす。
Reqnroll の実行基盤は Reqnroll.TUnit を使い、単体・性質と同じ TUnit に一本化する。

### 根拠
[documentation](../../principles/documentation.md) が定める、仕様の記述にプログラミング言語を使えば仕様と実装の継ぎ目が消えるという要求に、Reqnroll で応える。
一つの文書が仕様であり検査でもあるので、片方だけ古くならない。
Reqnroll は自前のテスト実行系を持たず、xUnit・NUnit・MSTest・TUnit のいずれかの実行基盤を要する。
Reqnroll.TUnit を使えば、仕様の実行基盤が単体・性質と同じ TUnit に揃い、実行基盤を二つに割らずに済む。

### 完了条件
業務語彙の executable spec が、Reqnroll で書かれ、実行されている。
Reqnroll の実行基盤が、Reqnroll.TUnit で TUnit に揃っている。

### 禁止事項
仕様に、実装の操作の語を書くこと。

### 行動
業務の語彙でシナリオを書き、Reqnroll のステップで実装する。
Reqnroll.TUnit を参照し、実行基盤を TUnit に揃える。

## 実依存

### 要求
実依存のコンテナは、本物に近い依存で検証しテストの終わりに片づける。これを Testcontainers for .NET で満たす。

### 根拠
実依存を mock で置き換えると、実際のドライバや SQL の振る舞いを踏まない。
Testcontainers で実依存のコンテナを起動すれば、本物に近い依存で検証でき、コンテナはテストの終わりに片づく。

### 完了条件
実依存のコンテナが、Testcontainers for .NET で起動され、テストの終わりに片づいている。

### 禁止事項
接続の host や port を、固定で書くこと。

### 行動
実依存を Testcontainers for .NET で起動し、IAsyncInitializer で起動を、IAsyncDisposable で破棄を結ぶ。

## 有効性

### 要求
mutation は、テストが振る舞いを本当に固定しているかを人工の欠陥注入で測る。これを Stryker.NET で満たす。
Stryker.NET の test-runner は mtp に設定し、TUnit のテストを発見させる。
テストの発見件数を CI で検査し、0 件なら失敗として扱う。
対象と絞り方の床は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
テストの有効性を mutation で測る理由は [structure/tests/methods](../../structure/tests/methods.md) に従う。
Stryker.NET の既定の test-runner は vstest で、TUnit は Microsoft.Testing.Platform 専用のため既定では接続せず、テストの発見が 0 件のまま mutation が空転する。
test-runner を mtp に設定すれば、TUnit のテストを発見して mutation を実行できる。

### 完了条件
mutation が Stryker.NET で検査され、生き残った欠陥が潰されている。
mutation の実行が、テストを発見して走っている。
テストの発見が 0 件のとき、失敗として扱われている。
対象と絞り方の床が、[structure/tests の methods](../../structure/tests/methods.md) の完了条件を満たしている。

### 禁止事項
test-runner を既定の vstest のまま TUnit と組み合わせ、テストの発見が 0 件のまま mutation を空転させること。
テストの発見が 0 件のまま、mutation の結果を合格として扱うこと。

### 行動
Stryker.NET の test-runner を mtp に設定し、TUnit のテストを発見させる。
テストの発見件数を検査し、0 件なら CI を失敗させる。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

## 構造

### 要求
依存方向と境界の禁止は ArchUnitNET で検証し、namespace を層と単位に対応させて、層の参照禁止・公開面・副作用の参照禁止を規則として書く。

### 根拠
[verification](../../principles/verification.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、ArchUnitNET で応える。
namespace を層と単位に対応させれば、層の参照禁止や副作用の参照禁止を規則として表せる。
規則をテストとして回せば、違反でビルドが止まる。
ArchUnitNET の namespace の走査は型を介さない静的な呼び出しを見ないので、その禁止は Microsoft.CodeAnalysis.BannedApiAnalyzers などの banned API の lint に割り当てる。

### 完了条件
依存方向と境界の禁止が、ArchUnitNET で検証されている。
namespace が層と単位に対応し、層の参照禁止・公開面・副作用の参照禁止が規則として書かれている。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。

### 行動
namespace を層と単位に対応させ、ArchUnitNET で層の参照禁止・公開面・副作用の参照禁止を規則にする。

### 例
```csharp
// domain は infrastructure に依存してはならない、を実行できる規則にする
Types().That().ResideInNamespace("App.Domain")
    .Should().NotDependOnAny(Types().That().ResideInNamespace("App.Infrastructure"))
    .Check(Architecture);
```

## 予防

### 要求
linter は SonarAnalyzer.CSharp を使い、nullable reference types と analyzer の警告を CI でエラーとして扱う。
ファイル・関数の大きさとネストの深さのしきい値は SonarAnalyzer.CSharp の S104(ファイル)・S138(関数)・S134(ネスト)の規則として定め、既定値から緩める変更は project の ADR に明記する。
認知的複雑さは SonarQube の cognitive complexity(S3776)で測り、SonarAnalyzer.CSharp のビルド時 lint 側では複雑度の規則を重ねて有効にしない。
SonarQube の profile は cognitive complexity(S3776)に絞り、ローカル lint と同目的の規則を重ねない。

### 根拠
nullable reference types と analyzer の警告をエラーにすれば、不在の取り違えや規則の違反がビルドで止まる。
S104・S138・S134 は、ファイル・関数の大きさとネストの深さを早く気づかせる。
S3776 を SonarQube の quality gate と SonarAnalyzer.CSharp のビルド時 lint の双方で有効にすると同じ規則を二重に測ることになるため、複雑度は SonarQube 側だけで測る。
SonarQube の cognitive complexity は switch の構造化を一度だけ加点し case の数に比例しないので、閉じた階層の網羅的な switch を罰しない。
SonarQube の profile を cognitive complexity だけに絞れば、SonarAnalyzer.CSharp が既に検査する命名や未使用変数などの規則を SonarQube 側で重ねて測ることがない。
既定から緩める判断を ADR に残せば、緩和の理由が追える。

### 完了条件
nullable reference types と analyzer の警告が、CI でエラーとして扱われている。
SonarAnalyzer.CSharp が、linter として使われている。
ファイル・関数の大きさとネストの深さのしきい値が、S104・S138・S134 の規則として定められている。
緩和が、project の ADR に明記されている。
SonarAnalyzer.CSharp のビルド時 lint 側で、複雑度の規則が有効になっていない。
SonarQube の profile が、cognitive complexity に絞られている。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
閉じた階層の網羅的な switch を、複雑度の加点対象にする指標を採ること。
cognitive complexity を、SonarAnalyzer.CSharp のビルド時 lint と SonarQube の quality gate の両方で有効にすること。
SonarQube の profile に、ローカル lint と同目的の規則を重ねて有効にすること。

### 行動
nullable reference types を有効にし、警告を CI でエラーにする。
SonarAnalyzer.CSharp を linter として導入し、S104・S138・S134 のしきい値を定める。
複雑度は SonarQube の quality gate に一本化し、緩和は ADR に明記する。
SonarQube の profile は cognitive complexity だけに絞る。

## ドキュメントコメントの検査

### 要求
CS1591 を `WarningsAsErrors` でエラー扱いにし、公開の型・メンバのドキュメントコメントの欠落をビルドの失敗にする。
NoWarn で CS1591 を抑止しない。
summary の体言止め・句読点禁止・一行の体裁と、param・typeparam・returns の網羅は companion の analyzer で検査する。
内容がユビキタス言語と一致しているかは、レビューで確かめる。

### 根拠
CS1591 は `GenerateDocumentationFile` を有効にしたときだけ発火する既定 level 4 の警告で、エラー扱いにしなければビルドを止めない。
NoWarn は CS1591 を丸ごと無効化し、欠落の検出そのものを消す。
体裁と網羅の検査は companion の自作 analyzer で実現する。
内容がユビキタス言語と一致しているかの判断は意味を読む必要があり、機械化できない。

### 完了条件
CS1591 が、`WarningsAsErrors` でエラー扱いになっている。
CS1591 が、NoWarn で抑止されていない。
summary の体裁と param・typeparam・returns の網羅が、companion の analyzer で検査されている。
内容とユビキタス言語の一致が、レビューで確かめられている。

### 禁止事項
CS1591 を、NoWarn で抑止すること。
体裁と網羅の検査を、既製の analyzer で代替できると称すること。

### 行動
`GenerateDocumentationFile` を有効にし、`WarningsAsErrors` に CS1591 を加える。
companion に体裁と網羅の analyzer を実装し、CI で検査する。

## 規則と検証機構の対応

formation・translation・connection・retention・coordination・publication・conventions の各規律を、検証手段へ写像する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| 実現軸 | 規律 | 検証手段 |
|---|---|---|
| formation | 業務の値を型に封じる | 型(record・非公開 constructor・static factory) |
| formation | 不正な状態を構築できなくする | 型(sealed record 階層)+analyzer(companion の suppressor・網羅の警告のエラー化)+構造検査(ArchUnitNET。階層外派生の検出) |
| formation | 継承を判別共用体に限る | レビュー(継承の目的の判断) |
| formation | 不変を既定にする | 型(init 専用プロパティ) |
| formation | 意味と単位を型で区別する | 型(record) |
| formation | companion を libs の機構として netstandard2.0 プロジェクトに分ける | 構造検査(companion 境界)+型(netstandard2.0 の Analyzer 参照制約) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(CSharpier チェック、SonarAnalyzer.CSharp の命名規則) |
| conventions | ドキュメントコメントを書く | analyzer/lint(CS1591 エラー化・companion)+レビュー(意味の妥当性) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(ArchUnitNET の命名照合) |
| translation | 境界で一度だけ parse してドメイン型へ移す | 型(JsonSerializerContext・required・JsonExtensionData)+実行テスト(境界の parse の単体テスト・未知フィールドのログ出力の単体テスト) |
| translation | 公開するエラーを境界で problem+json へ写す | 実行テスト(ProblemDetails の単体テスト) |
| translation | 生成した契約を使い、drift を検査の gate にする | 実行テスト(drift 検査・conformance の CI gate) |
| connection | 効果を Effect 型で組む | 型(readonly struct・delegate の内包)+analyzer(companion。default(Effect) 構築の検出) |
| connection | 効果の生成と combinator と資源を備える | 型(static factory・combinator のシグネチャ)+実行テスト(AcquireRelease の単体テスト) |
| connection | 終了を成功と失敗と欠陥と取り消しに分ける | 型(sealed record 階層の EffectExit)+構造検査(formation の階層外派生の検出に従う) |
| connection | 要求する依存を型に出す | 型(IEffectRequirements・generic constraints)+analyzer(companion。NoRequirements への迂回の検出) |
| connection | 効果を境界で実行し companion で縛る | analyzer(companion。実行境界の限定・R の合成環境の生成・Bind 連鎖の要求包含の検査・原始効果の閉じ込め・NoRequirements への迂回の禁止) |
| connection | port を interface で宣言する | 型(interface) |
| connection | 配線を composition root に限る | 構造検査(自作。IServiceProvider の直接解決の検出)+レビュー |
| retention | 型付き SQL | analyzer(DapperAOT の DAP214・DAP236)+実行テスト(型・nullable の照合テスト) |
| retention | 並行更新の表面 | 実行テスト(結合テストでの競合検出) |
| retention | 書き込みパス | 構造検査(自作。store が transaction の begin・commit を持たないことの検査) |
| retention | 一時データ | 構造検査(DB と Valkey の project 分離)+レビュー |
| coordination | 非同期 | analyzer/lint(SonarAnalyzer.CSharp の async void 検出規則)+レビュー(domain の純粋性の判断) |
| coordination | 取り消し | レビュー(CancellationToken が下流まで渡ることの判断) |
| coordination | 並行の組 | レビュー(linked CancellationTokenSource による兄弟取り消しの判断) |
| coordination | blocking 禁止 | analyzer/lint(Microsoft.CodeAnalysis.BannedApiAnalyzers) |
| coordination | 共有状態 | レビュー |
| coordination | ライブラリの作法 | analyzer/lint(SonarAnalyzer.CSharp の ConfigureAwait 関連規則) |
| coordination | 資源解放 | 型(using/await using・IDisposable/IAsyncDisposable) |
| publication | server | 構造検査(自作。middleware の順序の検出)+レビュー |
| publication | BFF | レビュー+実行テスト(cookie 属性の統合テスト) |
| publication | console | 型(ConsoleAppFramework の constructor injection) |
| publication | worker | 構造検査(Wolverine の永続化設定の検出)+レビュー |
| publication | desktop の host | レビュー |
| publication | mobile の host | レビュー |
| publication | extension の接続 | 型(StreamJsonRpc の型付き proxy)+レビュー |
| publication | 可視性 | 型(internal・file 修飾子) |

## 参照
検証の機械化は [verification](../../principles/verification.md)、構造を守る進化は [evolution](../../principles/evolution.md)、仕様と実装の継ぎ目の解消は [documentation](../../principles/documentation.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
