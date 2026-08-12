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
固定した一つの入力だけを検査すると、他の入力に対する性質を確かめられない。

```csharp
[Test] public async Task Rev() => await Assert.That(Reverse(Reverse([1, 2, 3]))).IsEqualTo([1, 2, 3]);
```

生成した多くの入力に対して、逆順を二度適用すると元へ戻る性質を検査する。

```csharp
[Test]
public void ReversingTwiceReturnsOriginal() =>
    Gen.Int.Array.Sample(values => values.Reverse().Reverse().SequenceEqual(values));
```

## 仕様

### 要求
業務語彙の executable spec は、[verification](../../principles/verification.md) が定める同じ検査経路で、Reqnroll として実行する。
feature の各 step は、一つの step binding と、その binding が呼ぶ公開 interface の operation に対応させる。
feature、step binding、公開 interface の対応は、各一覧を実体から導く drift 検査と executable spec の実行で検証する。
Reqnroll の実行基盤は Reqnroll.TUnit を使い、単体・性質と同じ TUnit に一本化する。

### 根拠
[verification](../../principles/verification.md) が定める、実行可能な仕様と実装を同じ検査経路に載せ、別成果物なら対応を検証する要求に、Reqnroll で応える。
feature、step binding、公開 interface は別の成果物なので、対応の drift 検査がなければ一方だけ古くなりうる。
Reqnroll は自前のテスト実行系を持たず、xUnit・NUnit・MSTest・TUnit のいずれかの実行基盤を要する。
Reqnroll.TUnit を使えば、仕様の実行基盤が単体・性質と同じ TUnit に揃い、実行基盤を二つに割らずに済む。

### 完了条件
業務語彙の executable spec が、Reqnroll で書かれ、実行されている。
feature の全 step が、一つの step binding と公開 interface の operation に対応している。
feature、step binding、公開 interface の対応に欠落と余剰がなく、drift 検査と executable spec の実行が同じ検証入口で通っている。
Reqnroll の実行基盤が、Reqnroll.TUnit で TUnit に揃っている。

### 禁止事項
仕様に、実装の操作の語を書くこと。
実行可能であることを理由に、feature、step binding、公開 interface の継ぎ目が消えたとみなすこと。
feature、step binding、公開 interface の対応を、人が固定した件数だけで検査すること。

### 行動
業務の語彙でシナリオを書き、Reqnroll のステップで実装する。
feature の step、step binding、公開 interface の operation をそれぞれ実体から列挙し、対応の欠落と余剰を drift 検査で失敗させる。
drift 検査と executable spec を、実装と同じ検証入口で実行する。
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
テストの発見件数を検証入口で検査し、0 件なら失敗として扱う。
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
テストの発見件数を検査し、0 件なら検証入口を失敗させる。
対象と絞り方は、[structure/tests の methods](../../structure/tests/methods.md) に従う。

## 構造

### 要求
依存方向と境界の禁止は ArchUnitNET で検証し、namespace を層と単位に対応させて、層の参照禁止・公開面・副作用の参照禁止を規則として書く。
root の ArchUnitNET 検査は、skeleton の実行時表と build・test-only 表から runtime・build・test phase の許可 edge を生成する。
root の ArchUnitNET 検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。
Roslyn analyzer は、surface と host の公開非同期 API が Task または Task<T> を返し、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> を返すことを semantic model で検査する。
Roslyn analyzer は、request、message、job の境界より内側の非同期 API が、非取消の後始末である `AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` を除き、Deadline と CancellationToken を必須引数に持つことを検査する。
Roslyn analyzer は、release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を行うことを検査する。
`IAsyncDisposable.DisposeAsync` の呼出側が、同じ Deadline を後始末の scope に保持することを検査する。
Deadline の生成が request、message、job の境界に限られることを検査する。
Roslyn analyzer は、各 hop の CancellationTokenSource が `deadline.Remaining(timeProvider)` から作られ、下流へ remaining でなく同じ Deadline が渡ることを検査する。

### 根拠
[verification](../../principles/verification.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、ArchUnitNET で応える。
namespace を層と単位に対応させれば、層の参照禁止や副作用の参照禁止を規則として表せる。
規則をテストとして回せば、違反でビルドが止まる。
ArchUnitNET の namespace の走査は型を介さない静的な呼び出しを見ないので、その禁止は Microsoft.CodeAnalysis.BannedApiAnalyzers などの banned API の lint に割り当てる。
Roslyn semantic model なら、method の accessibility、戻り値、引数、呼出式の symbol を結び付け、公開 host API と Effect 内部の awaitable の役割を区別できる。
同じ model で Deadline の生成と伝播、remaining の使用先を追えば、hop ごとに新しい相対 timeout を始める経路を拒否できる。
release と `DisposeAsync` を CancellationToken の必須規則から明示的に分ければ、通常の非同期 API の伝播漏れと、非取消でなければならない後始末を混同しない。

### 完了条件
依存方向と境界の禁止が、ArchUnitNET で検証されている。
namespace が層と単位に対応し、層の参照禁止・公開面・副作用の参照禁止が規則として書かれている。
root の ArchUnitNET 検査が、skeleton の両表から phase ごとの許可 edge を生成している。
build または test の edge が runtime の成果物へ混入した場合に、ArchUnitNET 検査が失敗している。
公開する surface と host の非同期 API が Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> に分かれている。
境界より内側の非同期 API が、release と `DisposeAsync` を除いて Deadline と CancellationToken を必須引数に持ち、Deadline が request、message、job の境界だけで生成されている。
release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を完了している。
各 hop の局所 timeout が `deadline.Remaining(timeProvider)` から作られ、同じ Deadline が下流へ渡されている。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。
公開 host API と Effect 内部の awaitable の役割分担を、レビューだけで検査すること。
hop ごとに相対 timeout を引き直す経路を、構造検査から外すこと。
release と `DisposeAsync` へ CancellationToken を要求し、非取消の後始末を通常の非同期 API と同じ規則で検査すること。

### 行動
namespace を層と単位に対応させ、ArchUnitNET で層の参照禁止・公開面・副作用の参照禁止を規則にする。
skeleton の両表を読み、runtime・build・test phase の許可 edge を生成して project 参照と照合する。
runtime の成果物を構成する参照 closure に build または test の edge があれば失敗させる。
Roslyn analyzer で、公開 host API の Task と Effect 内部の ValueTask の戻り値を検査する。
Roslyn analyzer で、境界より内側の非同期 API の Deadline と CancellationToken、境界だけでの Deadline 生成、remaining からの局所 timeout 生成、同じ Deadline の下流伝播を検査する。
release と `DisposeAsync` は CancellationToken の必須規則から除き、元の Deadline を保持する非取消の後始末として検査する。

### 例
層の参照制約は構造テストとして実行する。

```csharp
Types().That().ResideInNamespace("App.Domain")
    .Should().NotDependOnAny(Types().That().ResideInNamespace("App.Infrastructure"))
    .Check(Architecture);
```

## 予防

### 要求
linter は SonarAnalyzer.CSharp を使い、nullable reference types と analyzer の警告を検証入口でエラーとして扱う。
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
nullable reference types と analyzer の警告が、検証入口でエラーとして扱われている。
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
nullable reference types を有効にし、警告を検証入口でエラーにする。
SonarAnalyzer.CSharp を linter として導入し、S104・S138・S134 のしきい値を定める。
複雑度は SonarQube の quality gate に一本化し、緩和は ADR に明記する。
SonarQube の profile は cognitive complexity だけに絞る。

## ドキュメントコメントの検査

### 要求
CS1591 を `WarningsAsErrors` でエラー扱いにし、公開の型・メンバのドキュメントコメントの欠落をビルドの失敗にする。
NoWarn で CS1591 を抑止しない。
公開範囲を問わず全ての型とメンバにコメントがあることは、Roslyn analyzer で検査する。
summary の先頭行の体言止め・句読点禁止・一行の体裁と、param・typeparam・returns・value の網羅は Roslyn analyzer で検査する。
当該宣言内の直接の throw など、構文と semantic model で判定できる欠陥に対応する exception は Roslyn analyzer で検査する。
呼び出し先から伝播して当該宣言の契約になる欠陥と exception の対応は、公開範囲を問わずレビューで確かめる。
内容が、実効的な可視境界を基準に、境界外へ公開される宣言では外部契約を、同一境界内だけの宣言では内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致しているかは、レビューで確かめる。

### 根拠
CS1591 は `GenerateDocumentationFile` を有効にしたときだけ発火する既定 level 4 の警告で、エラー扱いにしなければビルドを止めない。
CS1591 が検出するのは公開の型とメンバのコメント欠落だけであり、非公開の宣言やコメントの項目と体裁は検査しない。
NoWarn は CS1591 を丸ごと無効化し、欠落の検出そのものを消す。
全宣言での存在と項目と体裁の検査は Roslyn analyzer で実現する。
直接の throw などは、構文と semantic model から当該宣言の exception と対応づけられる。
呼び出し先から伝播する欠陥が当該宣言の契約に含まれるかは、呼び出しの意味を読むレビューが要る。
内容が可視性に応じた外部契約または内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致しているかの判断は意味を読む必要があり、機械化できない。

### 完了条件
CS1591 が、`WarningsAsErrors` でエラー扱いになっている。
CS1591 が、NoWarn で抑止されていない。
全ての型とメンバのコメントの存在が、Roslyn analyzer で検査されている。
summary の先頭行の体裁と param・typeparam・returns・value の網羅が、Roslyn analyzer で検査されている。
当該宣言内で機械判定できる欠陥と exception の対応が、Roslyn analyzer で検査されている。
呼び出し先から伝播して当該宣言の契約になる欠陥と exception の対応が、公開範囲を問わずレビューで確かめられている。
内容が、境界外へ公開される宣言では外部契約を、同一境界内だけの宣言では内部契約を述べ、名前や実装の言い換えでなく、ユビキタス言語と一致していることが、レビューで確かめられている。

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

## 規則と検証機構の対応

formation・translation・connection・retention・coordination・publication・conventions・inspection の8実現軸の各規律を、検証手段へ写像する。
inspection 軸は、この文書の規律を定める H2 見出しを対応表へ全て列挙する。
標準 repository の verifier は、各実現軸の規律を表す H2 見出しの集合と、この対応表の規律の集合を照合し、欠落、余分、重複があれば失敗する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| 実現軸 | 規律 | 検証手段 |
|---|---|---|
| inspection | 実行 | 実行テスト(TUnit の単体・性質・結合を検証入口で実行し、発見件数0を失敗にする) |
| inspection | 性質 | 実行テスト(CsCheck の生成・縮小・stateful property と回帰 seed の再実行) |
| inspection | 仕様 | 構造検査(feature・step binding・公開 interface operation の実体由来一覧の drift)+実行テスト(Reqnroll.TUnit を実装と同じ検証入口で実行) |
| inspection | 実依存 | 実行テスト(Testcontainers for .NET の割当 host・port を使う結合テストと終了時の破棄)+runner 検査(TUnit `--list-tests` の tree node ID を native test ID とする size ごとの排他・全域集合一致、発見件数0の拒否、実行環境の資源制限。Reqnroll scenario は同じ TUnit discovery の ID を使う) |
| inspection | 有効性 | mutation(Stryker.NET の未検出 mutant 0件 gate と発見件数0の失敗) |
| inspection | 構造 | 構造検査(ArchUnitNET が skeleton の両表から runtime・build・test edge を生成し、runtime 成果物への build・test edge 混入を失敗にする) |
| inspection | 予防 | analyzer/lint(SonarAnalyzer.CSharp・BannedApiAnalyzers・Roslyn analyzer の設定と診断を検証入口でエラー化) |
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
| 全域 | branch coverage と safety-critical decision | 計測(Microsoft.Testing.Extensions.CodeCoverage で project 記録の branch 下限を検証入口で判定)+構造検査・実行テスト([structure/tests の methods](../../structure/tests/methods.md) が定める safety analysis と MC/DC case の一対一照合) |
| translation | 境界で一度だけ parse してドメイン型へ移す | 型(JsonSerializerContext・required・JsonExtensionData)+実行テスト(境界の parse の単体テスト・未知フィールドのログ出力の単体テスト) |
| translation | 公開するエラーを境界で problem+json へ写す | 実行テスト(ProblemDetails の単体テスト) |
| translation | 生成した契約を使い、drift を検査の gate にする | 実行テスト(drift 検査・conformance の検証入口の判定) |
| connection | 効果を Effect 型で組む | 型(readonly struct、Deadline と CancellationToken を受けて ValueTask を返す delegate の内包)+analyzer(Roslyn analyzer。明示的 `default(Effect<...>)`、Effect への `default` literal の代入、型解決で Effect と判定できる `default(T)` の検出)+実行テスト(配列、field、未解決の generic 由来の default を EffectRuntime.Run で実行すると Defected の `UninitializedEffectException` になること) |
| connection | 効果の生成と combinator と資源を備える | 型(EffectContext の Success/Try は引数から TValue を推論し、Fail<TValue>/Defect<TValue> は値型を明示する生成関数、Try body は Deadline、CancellationToken、ValueTask の delegate、AcquireRelease release は Deadline を受けるが CancellationToken を受け取らない ValueTask の delegate、拡張 method の combinator のシグネチャ)+analyzer(Roslyn analyzer。全 combinator が Run から受けた同じ Deadline を下流の Effect と release へ渡し、release を非取消の後始末にすること)+実行テスト(AcquireRelease の単体テスト、取消済み token の下でも release が同じ Deadline を受けて一度完了すること、複数の Bind を通っても期限が引き直されないこと) |
| connection | 終了を成功と失敗と欠陥と取り消しに分ける | 型(sealed record 階層の EffectExit、Result の tag 0 は未初期化)+analyzer(Roslyn analyzer。明示的 default(Result)、Result への default literal の代入、型解決できる default(T) の検出)+実行テスト(配列・field・generic 由来の default が全 observer・Match・unwrap 相当で欠陥になること)+構造検査(formation の階層外派生の検出に従う) |
| connection | 要求する依存を型に出す | 型(IEffectRequirements・generic constraints)+analyzer(Roslyn analyzer。NoRequirements への迂回の検出) |
| connection | 効果を境界で実行し analyzer と generator で縛る | analyzer と source generator(internal の EffectRuntime.Run に実行境界を限定し、Deadline と CancellationToken の伝播、ValueTask の戻り値、R の合成環境の生成、Bind 連鎖の要求包含、原始効果の閉じ込め、NoRequirements への迂回を検査)+実行テスト(`UninitializedEffectException` を Defected へ写すこと) |
| connection | port を interface で宣言する | 型(interface) |
| connection | 配線を composition root に限る | 構造検査(IServiceProvider の直接解決の検出)+レビュー |
| retention | 型付き SQL | analyzer(DapperAOT の DAP214・DAP236)+実行テスト(型・nullable の照合テスト) |
| retention | 並行更新の表面 | 実行テスト(結合テストでの競合検出) |
| retention | 書き込みパス | 構造検査(store が transaction の begin・commit を持たないことの検査) |
| retention | 冪等な要求の記録 | 構造検査(operation・actor scope・tenant・key の NOT NULL と複合一意制約)+実行テスト(認証済み actor、匿名の安定した opaque scope、logical system actor の分離、multi-tenant の検証済み TenantId、single-tenant sentinel、no-tenant sentinel、三表現の相互混同と未検証 tenant の拒否、scope のない匿名要求の server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否、同じ scope/key の並行競合、異なる fingerprint の conflict、業務結果・fingerprint・response の同時 rollback) |
| retention | durable inbox | 構造検査(scope・event ID の複合一意制約)+実行テスト(payload commit 前後の停止と upstream delivery ack、処理結果・処理済み記録 commit 前後の停止と inbox processing completion、前段の source 再配送、後段の item 再処理、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視出力) |
| retention | 一時データ | 構造検査(DB と Valkey の project 分離)+レビュー |
| coordination | 非同期 | analyzer/lint(SonarAnalyzer.CSharp の async void 検出規則)+analyzer(Roslyn analyzer。surface と host の公開非同期 API は Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release は ValueTask または ValueTask<T> に限定)+レビュー(domain の純粋性の判断) |
| coordination | 取り消し | analyzer(Roslyn analyzer。request、message、job の境界より内側の非同期 API が、非取消の後始末である AcquireRelease release と IAsyncDisposable.DisposeAsync を除いて Deadline と CancellationToken を必須引数に持ち、Deadline の生成を境界へ限定し、各 hop の局所 timeout が `deadline.Remaining(timeProvider)` から作られ、下流へ remaining でなく同じ Deadline が渡ることを検査。release は同じ Deadline を受けて CancellationToken を受け取らず、DisposeAsync は引数を持たないことを検査)+実行テスト(複数 hop で時間枠が引き直されず、局所 timeout が linked token で下流へ伝播すること、取消後も release と DisposeAsync が非取消で完了すること) |
| coordination | 並行の組 | 構造検査(Roslyn analyzer。個別 job の RunAsync 呼出しを SemaphoreSlim の permit 保持区間へ限定)+実行テスト(実行中の job が SemaphoreSlim の上限を越えない最大同時実行数)+レビュー(Task.WhenAny の失敗検知、兄弟用 CancellationTokenSource の取消、cancel callback 例外の収集、Task.WhenAll の drain、task と callback と外部取消の集約) |
| coordination | blocking 禁止 | analyzer/lint(Microsoft.CodeAnalysis.BannedApiAnalyzers) |
| coordination | 共有状態 | レビュー |
| coordination | ライブラリの作法 | analyzer/lint(SonarAnalyzer.CSharp の ConfigureAwait 関連規則) |
| coordination | 資源解放 | 型(using/await using、IDisposable、引数なしの IAsyncDisposable.DisposeAsync)+analyzer(Roslyn analyzer。AcquireRelease release と DisposeAsync を CancellationToken の必須規則から除外し、元の Deadline を保持する非取消の後始末として識別)+実行テスト(取消後も DisposeAsync が一度完了すること) |
| publication | server | 構造検査(middleware の順序と core 公開 API への ClaimsPrincipal・token・claim 型の流入禁止)+実行テスト(検証済み ClaimsPrincipal から actor への写像、actor と検証済み入力による core 公開 API 呼出、multi-tenant の TenantId・single-tenant sentinel・no-tenant sentinel の写像と相互混同拒否、server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否)+レビュー |
| publication | BFF | 構造検査(request-scoped ActorRequestContext から Actor を DI すること、ActorMapper 呼出を認証 middleware に限定すること、route の ClaimsPrincipal 参照と actor 再構築を拒否すること、route が埋め込んだ core の公開 API だけを呼ぶこと)+実行テスト(cookie 属性、認証 middleware が ActorRequestContext へ格納した actor と route に注入された Actor の一致、actor と検証済み入力による core 公開 API 呼出) |
| publication | console | 型(ConsoleAppFramework の constructor injection) |
| publication | worker | 構造検査(Wolverine の永続化設定・IMessageBus の constructor injection の検出)+実行テスト(payload commit 後の upstream delivery ack、処理結果・処理済み記録 commit 後の inbox processing completion、各停止点の再配送、安定した effect operation と event ID の冪等キー、外部効果成功後の処理済み記録、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視)+レビュー(CancellationToken の伝播) |
| 全域 | cast allowlist | analyzer(Roslyn analyzer。reporting boundary の型消去 symbol と検証を完結する converter または factory の型構築 symbol を別の allowlist として照合し、集合外と種類不一致の cast を拒否)+実行テスト(converter または factory が検証後だけ型を構築) |
| publication | desktop の host | レビュー |
| publication | mobile の host | レビュー |
| publication | extension の接続 | 型(StreamJsonRpc の型付き proxy)+レビュー |
| publication | 可視性 | 型(internal・file 修飾子) |

## 参照
検証の機械化と実行可能な仕様の検査経路は [verification](../../principles/verification.md)、構造を守る進化は [evolution](../../principles/evolution.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
