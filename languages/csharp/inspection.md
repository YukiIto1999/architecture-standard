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
公開 library API の EffectRuntime.Run は host port と区別し、その ValueTask の返却と、composition root 外の呼出しの拒否を検査する。
Roslyn analyzer は、request、message、job の境界より内側の非同期 API が、非取消の後始末である `AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` を除き、Deadline と末尾の CancellationToken を必須引数に持つことを検査する。
Roslyn analyzer は、release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を行うことを検査する。
`IAsyncDisposable.DisposeAsync` の呼出側が、同じ Deadline を後始末の scope に保持することを検査する。
Deadline の生成が request、message、job の境界に限られることを検査する。
Roslyn analyzer は、`Deadline` の `Remaining` と `At` から導いた遅延を timeout に使う全ての形(CancellationTokenSource の生成と `CancelAfter`、`WaitAsync`、`Task.Delay`、`TimeProvider.CreateTimer`)が、EffectRuntime.Run の所有する通知機構と Run を呼ばない境界だけにあり、Run を呼ぶ host と境界の内側の hop に無いことを検査する。
Roslyn analyzer は、下流へ remaining でなく同じ Deadline が渡ることを検査する。
Roslyn analyzer は、同期の純粋な domain の関数が Deadline と CancellationToken を引数に持たないことと、これらを認証主体や業務入力と同じ context の型へまとめないことを検査する。

### 根拠
Roslyn semantic model なら、method の accessibility、戻り値、引数、呼出式の symbol を結び付け、公開 host API と Effect 内部の awaitable の役割を区別できる。
同じ model で、`Deadline` の `Remaining` と `At` から遅延へ至る式の流れと、timeout を作る API の呼出式を追えば、`Deadline` から別の timeout を作る全ての形を拒否でき、adapter が自身の値で設ける上限は遅延が `Deadline` に由来しないので拒否されない。
純粋な domain の関数は期限も取消も観測しないので、引数の有無を型の宣言から検査すれば、核への実行 metadata の侵入を拒否できる。
release と `DisposeAsync` を CancellationToken の必須規則から明示的に分ければ、通常の非同期 API の伝播漏れと、非取消でなければならない後始末を混同しない。

### 完了条件
公開する surface と host の非同期 API が Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> に分かれている。
境界より内側の非同期 API が、release と `DisposeAsync` を除いて Deadline と CancellationToken を必須引数に持ち、Deadline が request、message、job の境界だけで生成されている。
release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を完了している。
`Deadline` から導いた遅延を timeout に使う全ての形が、EffectRuntime.Run の所有する通知機構と Run を呼ばない境界だけにあり、同じ Deadline が下流へ渡されている。
同期の純粋な domain の関数が Deadline と CancellationToken を引数に持たず、これらが認証主体や業務入力と同じ context の型へまとめられていない。

### 禁止事項
公開 host API と Effect 内部の awaitable の役割分担を、レビューだけで検査すること。
hop ごとの相対 timeout を含む、`Deadline` から別の timeout を作る経路を、構造検査から外すこと。
release と `DisposeAsync` へ CancellationToken を要求し、非取消の後始末を通常の非同期 API と同じ規則で検査すること。
純粋な domain の関数が持つ Deadline と CancellationToken の引数を、検査せずに許すこと。

### 行動
Roslyn analyzer で、公開 host API の Task と Effect 内部の ValueTask の戻り値を検査する。
Roslyn analyzer で、境界より内側の非同期 API の Deadline と末尾の CancellationToken、境界だけでの Deadline 生成、`Deadline` から導いた遅延を使う全ての timeout の生成が EffectRuntime.Run の所有する通知機構と Run を呼ばない境界だけにあること、同じ Deadline の下流伝播を検査する。
Roslyn analyzer で、同期の純粋な domain の関数の Deadline と CancellationToken の引数の不在と、認証主体や業務入力を含む context の型への同梱の不在を検査する。
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

## 型消去の cast allowlist

### 要求
Roslyn analyzer で、reporting boundary の型消去の symbol と、検証を完結する converter または factory の型構築の symbol を、別の allowlist として照合する。
集合の外の cast と、種類の一致しない cast を拒否する。
型消去と型構築の扱いは、[concerns/types](../../concerns/types/audited-type-loss.md) の「型の情報を失う箇所を監査する」に従う。

### 根拠
型消去と型構築を同じ集合で扱うと、検証を経ない型構築が報告の型消去に紛れる。
allowlist を分けて照合すれば、どちらの種類の cast かを機械で判定できる。

### 完了条件
型消去の symbol と型構築の symbol が、別の allowlist で管理されている。
allowlist の集合外の cast と、種類の一致しない cast が、検証入口で拒否されている。
converter または factory が、検証を終えた後だけ型を構築していることが実行テストで確かめられている。

### 禁止事項
型消去と型構築を、一つの allowlist へまとめること。
allowlist に載せずに cast を書くこと。

### 行動
reporting boundary の型消去と、検証を完結する型構築の symbol を、別々の allowlist へ列挙する。
構造検査で allowlist と照合し、集合外と種類不一致を失敗させる。
converter と factory が検証後だけ型を構築することを、実行テストで確かめる。

## 規則と検証機構の対応

この言語 ecosystem の全規律を、検証手段へ写像する。
規律は軸ファイルと採用したツールのファイルに住み、ファイル列は規律が住むファイルの名前である。
上位規律を ecosystem の機構で満たす規律も、軸ファイルか採用したツールのファイルに置く。
標準 repository の verifier は、ecosystem の全ファイルの規律を表す H2 見出しの集合と、この対応表の規律の集合を照合し、欠落、余分、重複があれば失敗する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。
検証手段は、型・構造検査・analyzer/lint・計測・mutation・runner 検査・artifact 検査・実行テスト・レビューの語で書き、複数の手段は + で連ねる。
レビューは、括弧に判断の対象を書く。

| ファイル | 規律 | 検証手段 |
|---|---|---|
| tunit | 実行 | 実行テスト(TUnit の単体・性質・結合を検証入口で実行し、発見件数0を失敗にする) |
| cscheck | 性質 | 実行テスト(CsCheck の生成・縮小・stateful property と回帰 seed の再実行) |
| reqnroll | 仕様 | 構造検査(feature・step binding・公開 interface operation の実体由来一覧の drift)+実行テスト(Reqnroll.TUnit を実装と同じ検証入口で実行) |
| testcontainers | 実依存 | 実行テスト(Testcontainers for .NET の割当 host・port を使う結合テストと終了時の破棄)+runner 検査(TUnit `--list-tests` の tree node ID を native test ID とする size ごとの排他・全域集合一致、発見件数0の拒否、実行環境の資源制限。Reqnroll scenario は同じ TUnit discovery の ID を使う) |
| mutation-dotnet | 有効性 | mutation(問いに応じて変更部分と未変更の影響部分を選び、変更部分は `--since`・`--changed-lines` と `changed-lines`、影響部分は build graph が導く project と `--with-baseline` の継承で選び、選ばなかった範囲と道具が選べない範囲を未分析として残し、検証入口に独自の planner や影響の判定を置かない。被覆テストの選択は生成対象と分け、生存と未被覆の合計を未検出として数え、report と終了 status を生の値のまま保持する。型として成立しない変異は検出に数えず、runner などの不成立とテスト発見0件は分析の不成立として別に報告する) |
| archunit-net | 構造 | 構造検査(ArchUnitNET が skeleton の production のソース依存表と build・test-only 依存表から runtime・build・test edge を生成し、成果物の消費表を assembly のソース依存と区別して照合し、production の成果物への build・test edge 混入を失敗にする) |
| sonaranalyzer-csharp | 予防 | analyzer/lint(SonarAnalyzer.CSharp・BannedApiAnalyzers・Roslyn analyzer の設定と診断、S3776 による関数の複雑さのしきい値、未使用の要素と参照の検出を検証入口でエラー化) |
| inspection | ドキュメントコメントの検査 | analyzer/lint(CS1591 と Roslyn analyzer)+レビュー(実効的な可視境界に応じた外部契約または内部契約、伝播する欠陥、再述でない意味) |
| formation | 業務の値を型に封じる | 型(record・非公開 constructor・static factory)+レビュー(値型を要する独立性と、業務モデルが private に持つ値の区別、保証を増やさない値オブジェクトと値ごとの必須化の不在、複数の要素にまたがる不変条件が要素を持つ一つの record の factory で守られていること、モデルの private な値が検証前の形で公開されていないこと) |
| formation | 不正な状態を構築できなくする | 型(Closed 属性で標識した sealed record 階層)+analyzer(TypeModeling suppressor、CS8509 等の網羅警告のエラー化、明示的に error にした TYPMOD021 による将来の case を受ける arm の拒否)+構造検査(ArchUnitNET。階層外派生の検出)+consumer compile 検査(case の欠落と将来の case を隠す arm を別々に拒否すること) |
| formation | 継承を閉じた型階層と境界の契約に限る | 型(判別共用体の基底以外の自作 class と record class の sealed)+レビュー(継承が閉じた型階層の宣言か境界で必須の基底型契約への適合であること、後者の言語仕様または採用済み framework の API による根拠、業務の振る舞いの再利用と Template Method 拡張の不在) |
| formation | 不変を既定にする | 型(init 専用プロパティ)+レビュー(値とイベントの更新が元を変えず新しい値を返すこと、値オブジェクトの全構築・更新経路が検証付き factory を通り、公開 init と with が不変条件を迂回しないこと、浅い複製で共有する参照先の不変性) |
| formation | 意味と単位を型で区別する | 型(record) |
| formation | 検証と生成を libs の analyzer project に分ける | 構造検査(analyzer project 境界)+型(netstandard2.0 の Analyzer 参照制約) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(CSharpier チェック、production の SonarAnalyzer.CSharp 命名規則、test project では Sonar の method 命名規則だけを抑止して命名 analyzer で test attribute 付き entry の snake_case とその他 method の .NET 命名を検査) |
| conventions | ドキュメントコメントを書く | analyzer/lint(CS1591 エラー化。公開要素のコメント欠落)+analyzer(Roslyn analyzer。全宣言のコメント存在・param/typeparam/returns/value・先頭行・当該宣言内で機械判定できる欠陥の exception)+レビュー(実効的な可視境界に応じた外部契約または内部契約、伝播する欠陥、再述でない意味) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(ArchUnitNET による保存用と binding 固有の型の役割別の命名照合)+レビュー(行と列の保存構造、wire の全体と部分の割当、既存の契約名との対応、接尾辞だけの同義型の不在) |
| coverlet-mtp | カバレッジ | 計測(`--coverlet` で有効にする coverlet.MTP の cobertura 出力について、`branches-covered` と `branches-valid` から branch の下限を、`lines-covered` と `lines-valid` から line の下限を検証入口でそれぞれ判定) |
| translation | 境界で一度だけ parse してドメイン型へ移す | 型(生成型・生成 codec、serializer 統合の System.Text.Json source generation)+構造検査(contracts/adapters の Mapper と独立した application 入力構築、旧版変換の境界内配置、domain 非公開性)+実行テスト(endpoint と durable queue の実受信経路での必須項目・null・既知制約・判別子の検証、拒否時の業務非開始、未知キーの受容と位置・キーの警告到達、捕捉値の domain・応答への非流入、未指定時だけの既定値適用、保持する旧版の事実の変換と保存行の不変)+レビュー(真の業務上の不明と互換の都合の区別、変換が事実を作らないこと、保持の旧版解釈の存続条件) |
| aspnet-core | 公開するエラーを境界で problem+json へ写す | 構造検査(宣言した結果の HTTP 写像が生成した提供側接続にあり、手書き handler に分散しないこと)+実行テスト(未処理例外を変換する middleware と ProblemDetails の公開 body の契約適合、内部詳細の非露出) |
| translation | 生成した契約値の構築と所有権を守る | 型(private storage の readonly value type・get-only model・alias 互換・役割と payload の取り違え拒否)+実行テスト(local 構築と decode の受理値・構造化違反の一致、不正な default と null の accessor・構築・encode・操作入口での拒否、可変 collection の別参照からの変更の隔離、存在状態、decimal と日時の全受理値域・精度・offset の保持、[methods-contracts](../../structure/tests/methods-contracts.md) の「契約の意味と生成」が定める深さ・wire profile・診断保持)+構造検査(BCL parser の再利用、record の等価性・hash・文字列化を含む非再帰の処理)+レビュー(通常の field 制約だけの wrapper がなく、不変な子が不要に複製されないこと) |
| translation | 生成した通信処理を既存の効果へ接続する | 構造検査(純粋な生成 assembly の通信 runtime 非依存、core の全生成 assembly 非依存、生成 handler と独立した application Interface の Adapter 接続)+analyzer(Roslyn。TimeoutException と InnerException の型だけによる上限判定の不在)+実行テスト(複数の成功・body 不在・binary・全宣言拒否の分類、502・503・504 の中継由来不一致の通信 Failed、その他の契約不一致と要求組立の Defected、本文途中切断と接続拒否、内部取消と下位 timeout の通信 Failed、自身の上限の別の Failed、呼出側取消と同時成立時の Canceled、完了後の取消で結果が変わらないこと、提供側 dispatch と consumer transport の両端実行、再生成・異なる一時パスでの出力一致・位置付き診断・drift の検証入口への接続) |
| connection | 効果を Effect 型で組む | 型(readonly struct、Deadline と CancellationToken を受けて ValueTask を返す delegate の内包)+analyzer(EFFSYS008。明示的 default、未初期化配列・field・同一 compilation で追跡できる generic producer の拒否)+外部 consumer 実行テスト(metadata-only producer からの未初期化値が UninitializedEffectException の Defected になること)+実行テスト(Try body と AcquireRelease release は生成・Map・Bind では実行されず、runtime の実行でのみ開始すること) |
| connection | 効果の生成と combinator と資源を備える | 型(EffectContext の Succeed/Try の TValue 推論、Fail<TValue>/Defect<TValue> の値型明示、Try body の requirements・Deadline・末尾 CancellationToken と ValueTask、release の資源・Deadline と ValueTask)+analyzer(全 combinator の同じ Deadline の伝播、release の CancellationToken 不在)+実行テスト(AcquireRelease の取得成功後の全終了で release が一度だけ非取消で完了すること、複数の Bind でも期限が変わらないこと) |
| connection | 終了を成功と失敗と欠陥と取り消しに分ける | 型(Closed 属性で標識した EffectExit、Result の tag 0 は未初期化)+analyzer(default Result の生成拒否)+実行テスト(静的検査を越えた default に対し HasValue だけが false、Value・TryGetValue・Match・IsFailed・等価性の両 operand・hash・文字列化・演算子が欠陥となること、初期化済みの null payload が有効な case として保持されること)+構造検査(formation の階層外派生の検出に従う) |
| connection | 要求する依存を型に出す | 型(IEffectRequirements・generic constraints)+analyzer(Roslyn analyzer。NoRequirements への迂回の検出) |
| connection | 効果を境界で実行し analyzer と generator で縛る | analyzer と source generator(公開 library の EffectRuntime.Run の呼出しを composition root へ限定、internal の Effect.Run、Deadline と末尾 CancellationToken の伝播、ValueTask、R の合成環境、Bind の要求包含、原始効果の閉じ込め、NoRequirements の迂回拒否)+外部 consumer compile と実行テスト(公開 Run の利用、未初期化 defect、過去の期限で効果非開始、長い有効期限の通知と解放、親取消の優先、期限到達だけに由来する Failed、原因不明の取消の UnattributedCancellationException、後着の取消・期限で Succeeded/Failed/Defected が変わらないこと、通知と解放の欠陥を持つ Defected の型付き UseOutcome が元の終了を保持すること、明示した診断への超過記録、診断例外の Defected に CompletedExit と InnerException の同一 instance が保持されること。時刻はテスト用の TimeProvider で進める) |
| connection | port を interface で宣言する | 型(interface) |
| connection | 配線を composition root に限る | 構造検査(Program.cs の DI 登録 factory 外の IServiceProvider・RequestServices による直接解決と、provider の注入・保存の検出)+レビュー(登録 factory が配線だけを行い、解決 scope と lifetime が一致すること、組立点に置く依存の粒度の判断) |
| dapper | 型付き SQL | 構造検査(DapperAOT の生成した写像の適用箇所と通常の Dapper 呼出しの区別)+analyzer(DapperAOT の採用 dialect に適用される診断だけをエラー化)+実行テスト(SQL の placeholder と parameter member の名前対応、schema・SQL・DTO の型と nullable の照合)+計測(性能を比較する場合の写像の実行時間と割当量) |
| npgsql | 並行更新の表面 | 構造検査(集約の鍵の導出が一か所に定義され、`pg_advisory_xact_lock` 系の呼び出しがその導出を通り、確定対象が同一コンテキスト内に閉じること)+実行テスト(集約の鍵を排他で取る集約で全経路の直列化と READ COMMITTED での鍵の後の検証、書き込み経路の role が事実の行へ `UPDATE` も `DELETE` もできないこと、複数の鍵を bigint の値の昇順の一つの順序で取ること、種類の違う集約の鍵が衝突せず範囲外の識別子から鍵を作らないこと、鍵を待った書き込みの業務事実の時刻が待つ間に確定した業務事実の時刻以後であること、版で衝突を検出する集約で並行更新の片方だけの確定と古い版の各経路からの拒否、共有の鍵か鍵なしで更新する可変属性の行への同じ行の同時の更新で片方だけが確定し他方が競合の Result になること、影響行数 0 と名前付き version 制約違反の競合写像、一回だけ起きる業務事実の二度目の追記で名前付き主キーの違反だけが競合に写ること、version と名前付き主キー以外の制約違反の非写像、必要な業務事実の追記前後の失敗で現在情報の更新・業務事実の追記・outbox の記録が全て確定するか全て確定しないこと、同一コンテキストの複数の集約を含む確定で一つの集約の競合または失敗を注入すると全ての書き込みが確定しないことと全ての集約の鍵を検証より前に昇順で取ること、業務事実不要な更新の競合制御と追記の不在、同じ確定で更新する控えの追記との同時確定と同じ版を期待する並行更新の片方だけの確定、欠けた控えと版のずれた控えでの判定の拒否)+レビュー(集約の不変条件に対する競合制御、必要な業務事実の欠落と outbox による代用の禁止、控えの条件を満たす決定の記録) |
| npgsql | 書き込みパス | 構造検査(store・composition・domain の begin・commit・rollback の不在、application の scope port と AcquireRelease による制御と driver 型の非流入、use-case の外の機構が成否から commit か rollback かを既定で決めておらず AcquireRelease が Commit を呼ばないこと、同一コンテキスト内の複数のモデルの書き込みが同じ scope の一度の Commit に含まれること、他コンテキストへの参照・参加操作・共有 scope の不在)+実行テスト(release 失敗時の元の終わりの保持、確定応答喪失時の CommitOutcomeUnknown、エラーの種類だけによる NotCommitted 判定の拒否、確定後の DisposeAsync 失敗時の確定結果の保持、取消後の transaction と advisory lock の非残存、同一コンテキスト内の複数のモデルを含む use-case の拒否・競合・失敗で全ての書き込みが確定しないこと)+レビュー(確定の範囲と確定条件の use-case による所有、コンテキストの独立性) |
| npgsql | 冪等な要求の記録 | 構造検査(operation・actor scope・tenant・key の NOT NULL と複合一意制約)+実行テスト(認証主体、匿名の安定した opaque scope、logical system actor の分離、業務当事者への写像後も要求者 scope が変わらないこと、multi-tenant の検証済み TenantId、single-tenant sentinel、no-tenant sentinel、三表現の相互混同と未検証 tenant の拒否、scope のない匿名要求の server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否、同じ scope/key の並行競合、異なる fingerprint の conflict、業務結果・fingerprint・response の同時 rollback) |
| npgsql | durable inbox | 構造検査(scope・event ID の複合一意制約)+実行テスト(payload commit 前後の停止と upstream delivery ack、処理結果・処理済み記録 commit 前後の停止と inbox processing completion、前段の source 再配送、後段の item 再処理、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視出力) |
| stackexchange-redis | 一時データ | 構造検査(DB と Valkey の project 分離)+レビュー(一時データとして扱える範囲の判断) |
| coordination | 非同期 | analyzer/lint(SonarAnalyzer.CSharp の async void 検出規則)+analyzer(Roslyn analyzer。surface と host の公開非同期 API は Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release は ValueTask または ValueTask<T> に限定)+レビュー(domain の純粋性の判断) |
| coordination | 取り消し | analyzer(非取消の後始末以外の非同期 API の Deadline と末尾 CancellationToken、境界だけの期限生成、期限由来の timeout の生成を runtime の所有する通知機構と非 Effect 境界へ限定、同じ Deadline の下流伝播、純粋な domain と業務 context への実行 metadata 非流入)+実行テスト(通知元の単一所有、長い期限の再設定、親の Cancel・CancelAsync・timer と期限通知の各経路で callback の例外が要求元や native timer へ漏れないこと、通知競合でも callback が一度だけ実行されること、解放開始後の新しい通知の拒否、中継登録・callback・timer の完了と独立した欠陥の回収、開始時の過去の期限と取消による非開始、取消後の非取消 release と DisposeAsync、親取消を優先した帰属判定、帰属不能な取消と通知機構の欠陥の区別、確定結果の不変と診断、adapter 独自の上限と Deadline の短い方による中断、自身の上限と親の取消と下位の通信中断の区別。時刻はテスト用の TimeProvider で進め、native timer からの流出は別 process の実行でも確認する) |
| coordination | 並行の組 | 構造検査(Roslyn analyzer。個別 job の RunAsync 呼出しを SemaphoreSlim の permit 保持区間へ限定)+実行テスト(最大同時実行数、子の例外と業務結果の失敗の各経路で兄弟取消と全 Task の drain、開始途中の同期例外または列挙失敗でも開始済みの子の回収、Cancel callback の例外と兄弟の追加失敗の回収、実行中の外部取消 callback の完了より前に CTS を解放しないこと、取消要求後も子が未完了の間は所有者が終了しないこと、子の例外と判定の時点で取り消し済みの外部 token と業務結果の失敗が重なる組が OperationCanceledException を含む集約、OperationCanceledException、業務結果の順で終わること、外部 token が取り消されておらず組が自ら取消した兄弟を除いて最初の業務結果の失敗で終わること、全ての子が業務結果を返した組が外部取消で書き換えられないこと)+レビュー(全 Task の所有者と長寿命の処理の停止経路、開始と停止の競合、Task.Exception と外部取消の回収) |
| coordination | blocking 禁止 | analyzer/lint(Microsoft.CodeAnalysis.BannedApiAnalyzers)+実行テスト(開始済みの Task.Run の同期処理が取消要求だけでは終了せず、所有者が完了まで保持すること)+レビュー(同期処理の協調停止点または process 分離) |
| coordination | 共有状態 | 構造検査(Roslyn analyzer。可変な静的状態と共有 instance の検出)+レビュー(共有が必要な範囲の判断) |
| coordination | ライブラリの作法 | analyzer/lint(SonarAnalyzer.CSharp の ConfigureAwait 関連規則) |
| coordination | 資源解放 | 型(using/await using、IDisposable、引数なしの IAsyncDisposable.DisposeAsync、ResourceReleaseException の型付き UseOutcome)+analyzer(release と DisposeAsync の CancellationToken 不在、元の Deadline 保持)+実行テスト(取得成功後の release が全終了経路で一度だけ完了、子の drain 後の資源解放、使用の Returned と Threw の区別と元 instance、解放例外の InnerException の identity、両方の失敗の観測と他の必要な解放の継続) |
| aspnet-core | server | 構造検査(middleware の順序、core 公開 API への ClaimsPrincipal・token・claim・認証主体の型の流入禁止、全 endpoint が `RequireAuthorization()` か `AllowAnonymous` の宣言を持つこと、endpoint が呼ぶ業務の入口を adapter の宣言された保護を適用する入口に限ること、handler が認可の呼出と許可結果の引数を持たないこと)+実行テスト(検証済み ClaimsPrincipal から認証主体への確定、同じ認証主体に確定した限定資格情報の scope 外操作・対象の拒否、認証主体に対する認可の維持と独立した session 経路による迂回の確認、`AuthorizationOptions.FallbackPolicy` による宣言のない endpoint の拒否と匿名公開の明示、adapter の入口が適用する操作と対象の policy が endpoint の認証の要求だけでは満たされないこと、主体を必要とする operation だけが認証主体から対応づけた業務入力を受けること、要求側が指定した主体の拒否、multi-tenant の TenantId・single-tenant sentinel・no-tenant sentinel の写像と相互混同拒否、server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否)+レビュー(認証方式ごとの principal の妥当性の判断) |
| aspnet-core | BFF | 構造検査(認証主体を確定する request-scoped IMiddleware への SubjectAccessor の constructor 注入、middleware と route の本体での provider 直接解決の不在、同じ request scope の SubjectAccessor から AuthenticatedSubject を解決する DI 登録 factory の配置、SubjectMapper 呼出を認証 middleware に限定すること、route の ClaimsPrincipal 参照と認証主体の再構築を拒否すること、route の業務呼出を adapter の宣言された保護を適用する入口に限定し、技術的な処理では libs の公開 API の直接利用を許すこと、利用者の代理で API を呼ばない BFF での `SaveTokens` の無効と token management の未登録)+実行テスト(cookie 属性、認証 middleware が格納した主体が後続の route と adapter へ同じ主体として注入されること、並行する別 request の SubjectAccessor と認証主体の非共有、adapter の入口が認証主体から対応づけた業務入力と検証済み入力による core 公開 API 呼出、利用者の代理で API を呼ばない BFF の認証チケットに access token と refresh token が載らないこと)+レビュー(DI 登録 factory が解決時に実行され、主体の格納より前に解決せず、scoped な主体を singleton と root provider に保持しないこと) |
| wolverine | worker | 構造検査(Wolverine の PostgreSQL の message store と予約先 local queue の durable 設定・IMessageBus の constructor injection、予約の鍵の一意制約と業務更新の transaction に含める outbox の記録、cron 式の scheduler の package の不在)+実行テスト(payload commit 後の upstream delivery ack、処理結果・処理済み記録 commit 後の inbox processing completion、各停止点の再配送、安定した effect operation と event ID の冪等キー、外部効果成功後の処理済み記録、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視、予約した message の実行時刻前の不処理と停止後の保持と実行時刻後の処理、同じ業務事実から二度積んだ予約の一件化、必須項目の欠落・契約が許さない null・既知項目の不正・判別子と payload の不一致の message を store から受ける実際の受信経路へ渡した拒否と行き止まりへの送付と handler の業務処理の非開始と業務状態・outbox の不変、既知の契約を満たす message に未知の追加項目だけを加えた場合の受容、一時的な旧版対応の撤去時に発行と再投入の停止後も予約を含む各経路に未完了の旧版が残らないこと)+レビュー(CancellationToken の伝播、撤去する旧版対応の範囲と検査した経路の列挙の完全性) |
| inspection | 型消去の cast allowlist | analyzer(Roslyn analyzer。reporting boundary の型消去 symbol と検証を完結する converter または factory の型構築 symbol を別の allowlist として照合し、集合外と種類不一致の cast を拒否)+実行テスト(converter または factory が検証後だけ型を構築) |
| publication | mobile の native 組込入口 | 型(生成した C ABI の blittable な署名と codec)+構造検査(embedded surface の組立、公開 assembly の export、管理型と業務 DTO の ABI への非露出、AOT・trimming 診断)+artifact 検査(OS・CPU ごとの共有ライブラリと依存物、iOS framework の同梱と署名)+実行テスト(端末上の実受信経路での結果と状態変化、不正 payload・偽造主体の拒否と状態不変、空 payload と pointer・長さの不整合、並行要求、期限・取消と完了の競合、失敗・欠陥・取消の区別、初期化失敗・準備前・停止後の不受付、要求と callback の完了後の一度だけの資源解放)+レビュー(所有権と allocator の一致、unload の不在、Android の実行条件) |
| streamjsonrpc | extension の接続 | 型(StreamJsonRpc の型付き proxy)+レビュー(custom method が公開面を広げていないことの判断) |
| consoleappframework | console | 型(ConsoleAppFramework の constructor injection) |
| publication | 可視性 | 型(internal・file 修飾子)+構造検査(`InternalsVisibleTo` の宛先が同じコンテキストの tests の assembly に限られることの照合) |
| banned-api-analyzers | 直読と自由文出力を禁止 API で止める | analyzer/lint(BannedApiAnalyzers の禁止一覧を検証入口でエラー化) |
| inspection | nullable と警告を検証入口でエラーにする | analyzer/lint(nullable reference types と WarningsAsErrors の compiler 設定) |
| inspection | 非同期の形と期限の伝播を analyzer で検査する | 構造検査(自作 Roslyn analyzer を検証入口で実行) |
| inspection | 汎用名を自作 analyzer で禁止する | analyzer/lint(自作 Roslyn analyzer の denylist を検証入口でエラー化) |
| inspection | Result の非網羅な取り出しを analyzer で禁止する | analyzer/lint(自作 Roslyn analyzer の cast 検出を検証入口でエラー化) |

## 参照
検証の機械化と実行可能な仕様の検査経路は [verification](../../principles/verification/README.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
