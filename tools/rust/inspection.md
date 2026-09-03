# inspection

## 概要
inspection は、Rust で検証を扱う実現軸である。
principles の [verification](../../principles/verification.md) が定める検証の機械化を、Rust の機構で満たす。

## 構造

### 要求
依存方向は workspace の crate 依存で強制し、crate 依存に乗らない規則は root の tests/ に置く構造検査で検証する。
検査は import の走査で、層の参照禁止・公開面・配置の文法を確かめる。
root の構造検査は、skeleton の実行時表と build・test-only 表から runtime・build・test phase の許可 edge を生成する。
root の構造検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。

### 根拠
依存方向を crate の依存グラフにすれば、下位が上位を参照できず、向きがビルドで強制される。
crate の依存に乗らない規則は、import を走査する構造検査で確かめれば、構造の劣化が検査で止まる。
import の走査は型を介さない静的な呼び出しを見ないので、その禁止は clippy::disallowed_methods などの banned API の lint に割り当てる。

### 完了条件
依存方向が、crate 依存で強制されている。
crate 依存に乗らない規則が、import を走査する構造検査で検証されている。
root の構造検査が、skeleton の両表から phase ごとの許可 edge を生成している。
build または test の edge が runtime の成果物へ混入した場合に、構造検査が失敗している。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。

### 行動
skeleton の境界を workspace の crate で分け、依存方向を Cargo の依存で強制する。
残りの規則を root の tests/ の構造検査で確かめる。
skeleton の両表を読み、runtime・build・test phase の許可 edge を生成して実際の crate 依存と照合する。
runtime の成果物を構成する依存 closure に build または test の edge があれば失敗させる。

## 予防

### 要求
rustc と clippy の警告は、`[workspace.lints.rust]` の `warnings = "deny"` で検証入口のエラーとして扱う。
lint は clippy を `[workspace.lints.clippy]` で強制し、unwrap_used・expect_used を deny にする。
テストの unwrap・expect は、clippy.toml の allow-unwrap-in-tests・allow-expect-in-tests で許可する。
大きさとネストのしきい値は too_many_lines・excessive_nesting の lint の規則として定め、既定値から緩める変更は project の ADR に明記する。
excessive_nesting は既定のしきい値を持たないため、project が clippy.toml にしきい値を定め、ADR に記録する。
認知的複雑さは SonarQube の cognitive complexity(S3776)で測り、clippy 側に複雑度の規則を重ねて持たせない。
SonarQube の profile は cognitive complexity(S3776)に絞り、ローカル lint と同目的の規則を重ねない。
unsafe の使用は `[workspace.lints.rust]` の `unsafe_code = "deny"` で既定禁止にする。
unsafe を要する project は理由を ADR に記録し、`#[allow(unsafe_code)]` を unsafe を含む最小の item に付ける。
同じ理由を共有する複数の item に限り、それらを収める最小の module に `#[allow(unsafe_code)]` を付ける。

### 根拠
`warnings = "deny"` を workspace の lints に設定すれば、個別に deny を書き漏らした警告も含めて検証入口が黙って通過しない。
lint を workspace の lints で強制すれば、規則が全体に一律に効く。
unwrap_used・expect_used を deny にすれば、想定された失敗を握り潰すコードがビルドで止まる。
`unsafe_code = "deny"` を workspace の lints に設定すれば、unsafe の使用が既定でビルドを止め、無秩序な混入を防ぐ。
unsafe が要る最小の item に `#[allow(unsafe_code)]` を付け、理由を ADR に残せば、逸脱が可視化されたまま最小に保たれる。
同じ理由を共有する item だけを最小の module にまとめれば、同じ allow の重複を避けても許可範囲を広げずに済む。
clippy の lint 属性は crate 全体と item の単位に付けられ(文・式への属性は stable Rust では安定化されていない stmt_expr_attributes を要するため使えない)、Cargo.toml の `[lints]` はターゲット単位の上書きを持たないため、テストの除外は clippy.toml の allow-unwrap-in-tests・allow-expect-in-tests で行う。
too_many_lines と excessive_nesting は、関数の肥大化とネストの深さを早く気づかせる。
clippy 自身の cognitive_complexity lint は、原典と異なる clippy 固有のヒューリスティックで実装され、clippy 公式が測定ツールとしての使用を推奨していないため採用しない。
SonarQube の cognitive complexity は switch・match の構造化を一度だけ加点し、分岐の数に比例しないので、閉じた直和の網羅的な match を罰しない。
既定から緩める判断を ADR に残せば、緩和の理由が追える。

### 完了条件
`[workspace.lints.rust]` に `warnings = "deny"` が設定され、rustc と clippy の警告が検証入口でエラーとして扱われている。
workspace の lints に、unwrap_used・expect_used の deny の設定がある。
テストの unwrap・expect が、clippy.toml の allow-unwrap-in-tests・allow-expect-in-tests で許可されている。
大きさとネストのしきい値が、too_many_lines・excessive_nesting の lint の規則として定められている。
excessive_nesting のしきい値が、project の clippy.toml に定められ ADR に記録されている。
緩和が、project の ADR に明記されている。
`[workspace.lints.rust]` に `unsafe_code = "deny"` が設定されている。
unsafe を要する箇所では、`#[allow(unsafe_code)]` が unsafe を含む最小の item に付いている。
同じ理由を共有する複数の item に module 単位で許可する場合は、それらを収める最小の module に限られている。
unsafe を許可する理由が、project の ADR に記録されている。

### 禁止事項
警告を、検証入口でエラーとして扱わず黙って通過させること。
大きさと複雑さのしきい値を、既定から黙って緩めること。
閉じた直和の網羅的な分岐を、複雑度の加点対象にする指標を採ること。
cognitive complexity を、clippy の cognitive_complexity lint で測ること。
`#![allow(unsafe_code)]` を crate root に置き、crate 全体を許可すること。
異なる理由の unsafe をまとめて、module 単位で許可すること。

### 行動
`[workspace.lints.rust]` に `warnings = "deny"` を設定する。
`[workspace.lints.clippy]` に unwrap_used・expect_used を deny で設定し、clippy.toml に allow-unwrap-in-tests・allow-expect-in-tests を設定する。
too_many_lines・excessive_nesting を有効にし、excessive_nesting のしきい値と緩和は project の ADR に明記する。
`[workspace.lints.rust]` に `unsafe_code = "deny"` を設定する。
unsafe を含む最小の item に `#[allow(unsafe_code)]` を付け、同じ理由を共有する複数の item は最小の module にまとめて許可し、その理由を ADR に記録する。

### 例
`Cargo.toml` の workspace lint は、警告、unsafe、対象の clippy lint を次のように設定する。

```toml
[workspace.lints.clippy]
unwrap_used = "deny"
expect_used = "deny"
too_many_lines = "warn"
excessive_nesting = "warn"

[workspace.lints.rust]
warnings = "deny"
unsafe_code = "deny"
```

ワークスペースルートの `clippy.toml` では、テストの `unwrap` と `expect` だけを許可する。

```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
```

## ドキュメントコメントの存在

### 要求
crate ルートに `#![deny(missing_docs)]` を置き、`pub` な要素のドキュメントコメントの欠落をビルドの失敗にする。
非公開の要素は `clippy::missing_docs_in_private_items` を deny にし、ドキュメントコメントの欠落を検出する。
`# Errors`・`# Panics`・`# Safety` の節の欠落は、`clippy::missing_errors_doc`・`clippy::missing_panics_doc`・`clippy::missing_safety_doc` を deny にして検出する。
最初の一行が [conventions](./conventions.md) の体裁(一行の体言止め・句読点なし)を満たしているかは、構造検査で確かめる。
ドキュメントコメントが、公開要素では可視境界の利用側への外部契約を、非公開要素では同一境界内の呼び出し側への内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致しているかは、レビューで確かめる。

### 根拠
missing_docs は rustc 組み込みの allow-by-default の lint で、deny にしなければ欠落が検出されない。
missing_docs は `pub` な要素だけを対象にし、非公開の要素のドキュメントコメントの欠落は検出しないので、`clippy::missing_docs_in_private_items` を別に deny にして非公開の要素を埋める。
clippy の missing_errors_doc・missing_panics_doc は Result を返す・panic しうる `pub fn` に節の記述を求め、missing_safety_doc は `pub unsafe fn` に `# Safety` を求めるので、conventions が要求する節の網羅を公開要素の範囲で機械検査に載せられる。
最初の一行の体言止めと句読点の有無は構造として判定できるため、構造検査へ載せられる。
可視性に応じた外部契約または内部契約を述べ、名前や実装の言い換えでなく、統一した語彙に一致しているかの判断は意味を読む必要があり、機械化できない。

### 完了条件
crate ルートに `#![deny(missing_docs)]` があり、`pub` な要素のドキュメントコメントの欠落がビルドの失敗になっている。
非公開の要素のドキュメントコメントの欠落が、`clippy::missing_docs_in_private_items` で検出されている。
公開要素の `# Errors`・`# Panics`・`# Safety` の欠落が、clippy の missing_errors_doc・missing_panics_doc・missing_safety_doc で検出されている。
最初の一行の体裁が、構造検査で確かめられている。
ドキュメントコメントが、公開要素では外部契約を、非公開要素では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致していることが、レビューで確かめられている。

### 禁止事項
`#![deny(missing_docs)]` を、crate 全体の `#![allow(missing_docs)]` で無効化すること。
最初の一行の意味を、体裁の構造検査だけで検証済みと扱うこと。

### 行動
crate ルートに `#![deny(missing_docs)]` を置く。
`[workspace.lints.clippy]` に `missing_docs_in_private_items`・`missing_errors_doc`・`missing_panics_doc`・`missing_safety_doc` を deny で設定する。
最初の一行の体裁を、構造検査で確かめる。
ドキュメントコメントが、公開要素では外部契約を、非公開要素では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致していることをレビューする。

## 規則と検証機構の対応

この言語 ecosystem の全規律を、検証手段へ写像する。
規律は軸 file と採用したツールの file に住み、file 列は規律が住む file の名前である。
標準 repository の verifier は、ecosystem の全 file の規律を表す H2 見出しの集合と、この対応表の規律の集合を照合し、欠落、余分、重複があれば失敗する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| file | 規律 | 検証手段 |
|---|---|---|
| cargo-nextest | 実行 | 実行テスト(cargo-nextest の単体・性質・結合と `cargo test --doc` の doctest を検証入口で実行し、発見件数0を失敗にする) |
| proptest | 性質 | 実行テスト(proptest の生成・縮小・stateful property と回帰 seed の再実行) |
| cucumber | 仕様 | 構造検査(feature・step binding・公開 interface operation の実体由来一覧の drift)+実行テスト(cucumber を実装と同じ検証入口で実行) |
| testcontainers | 実依存 | 実行テスト(testcontainers の割当 host・port を使う結合テストと終了時の破棄)+runner 検査(`cargo nextest list --message-format json` の binary と test name の組を native test ID とする size ごとの排他・全域集合一致、発見件数0の拒否、実行環境の資源制限。doctest と cucumber scenario は各実行入口の native ID を同じ集合へ加える) |
| cargo-mutants | 有効性 | mutation(cargo-mutants の未検出 mutant 0件 gate と対象件数0の失敗) |
| inspection | 構造 | 構造検査(root tests が skeleton の両表から runtime・build・test edge を生成し、runtime 成果物への build・test edge 混入を失敗にする) |
| inspection | 予防 | analyzer/lint(rustc・clippy・SonarQube の設定と診断を検証入口でエラー化)+構造検査(許可と禁止の設定逸脱) |
| inspection | ドキュメントコメントの存在 | analyzer/lint(missing_docs 系)+構造検査(先頭行の体裁)+レビュー(公開要素の外部契約、非公開要素の内部契約、再述でない意味、統一した語彙) |
| formation | 業務の値を型に封じる | 型(newtype・非公開フィールド・Rust の可視性機構) |
| formation | 不正な状態を構築できなくする | 型(enum・網羅 match・コンパイラの網羅性検査) |
| formation | 不変の束縛と共有参照を既定にする | 型(所有権・不変束縛・共有参照・排他借用) |
| formation | 意味と単位を型で区別する | 型(newtype) |
| formation | 生成と検証の macro を libs の proc-macro crate に分ける | 構造検査(proc-macro crate 境界)+型(proc-macro crate type の compiler 制約) |
| conventions | 命名と整形を道具に委ねる | analyzer/lint(rustfmt --check、rustc の non_snake_case 系 lint) |
| conventions | ドキュメントコメントを書く | analyzer/lint(missing_docs deny・clippy::missing_docs_in_private_items で存在、clippy::missing_errors_doc・clippy::missing_panics_doc・clippy::missing_safety_doc で公開要素の節の網羅)+構造検査(最初の一行の体言止め・句読点なし)+レビュー(公開要素の外部契約、非公開要素の内部契約、再述でない意味、統一した語彙) |
| conventions | 型名の接尾辞を役割で揃える | 構造検査(命名照合) |
| 全域 | branch coverage と safety-critical decision | 計測(branch を数える設定は nightly channel で実行する `cargo llvm-cov --branch` であり、その json 出力の branch 集計から project 記録の branch 下限を検証入口で判定)+構造検査・実行テスト([structure/tests の methods](../../structure/tests/methods.md) が定める safety analysis と MC/DC case の一対一照合) |
| serde | 境界で一度だけ parse してドメイン型へ移す | 型(TryFrom)+実行テスト(境界の parse の単体テスト・未知フィールドのログ出力の単体テスト) |
| translation | 終了を surface の境界表現へ写す | 実行テスト(surface ごとの成功・想定内失敗・欠陥・取り消しの写像) |
| translation | 生成した契約を使い、drift を検査の gate にする | 実行テスト(drift 検査・conformance の検証入口の判定) |
| connection | 効果を言語の効果型で表す | 型(Future・Result)+レビュー(domain の同期性の判断) |
| thiserror | 失敗を Result に、欠陥を panic にする | analyzer/lint(clippy unwrap_used・expect_used deny)+型(Result) |
| connection | 要求する依存を能力の trait bound で型に出す | 型(trait bound) |
| async-trait | port を trait で宣言する | 型(trait)+構造検査(依存方向) |
| connection | 配線を組立点に置き、境界で実行する | 構造検査(composition root 外の具象生成の検出)+レビュー |
| sqlx | 型付き SQL | 型/実行テスト(sqlx の `query!` コンパイル時検証・検証入口の offline 照合) |
| sqlx | 並行更新の表面 | 実行テスト(結合テストでの競合検出) |
| sqlx | 書き込みパス | 構造検査(store が transaction の begin・commit を持たないことの検査) |
| sqlx | 冪等な要求の記録 | 構造検査(operation・actor scope・tenant・key の NOT NULL と複合一意制約)+実行テスト(認証済み actor、匿名の安定した opaque scope、logical system actor の分離、multi-tenant の検証済み TenantId、single-tenant sentinel、no-tenant sentinel、三表現の相互混同と未検証 tenant の拒否、scope のない匿名要求の server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否、同じ scope/key の並行競合、異なる fingerprint の conflict、業務結果・fingerprint・response の同時 rollback) |
| sqlx | durable inbox | 構造検査(scope・event ID の複合一意制約)+実行テスト(payload commit 前後の停止と upstream delivery ack、処理結果・処理済み記録 commit 前後の停止と inbox processing completion、前段の source 再配送、後段の item 再処理、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視出力) |
| fred | 一時データ | 構造検査(DB と Valkey のクレート分離)+レビュー |
| tokio | runtime | 構造検査(Cargo 依存の単一 runtime 検査) |
| tokio | 構造化並行 | 構造検査(Semaphore の permit 必須を並行 job task に限定し、単一の owner task を対象外にすること)+実行テスト(並行 job task が Semaphore の permit 数を越えて走らないこと、permit 待ち中の CancellationToken 取消では permit を取得しないこと、業務の Err と JoinError のどちらでも JoinSet::shutdown が残りを取り消して drain すること、permit を持たない単一の owner task が親の JoinSet へ合流すること)+レビュー(全 task の scope 所属) |
| tokio-util | 取り消し | 構造検査(request、message、job の境界より内側にある全 async API が同じ `Deadline` と CancellationToken を受け取り、`Deadline` の生成を境界へ限定し、各 hop の局所 timeout が `deadline.remaining(clock.now())` から作られ、下流へ相対値でなく元の `Deadline` が渡ることを検査)+実行テスト(複数 hop で待っても時間枠が引き直されず、局所 timeout が子の CancellationToken を cancel すること、job task と run_blocking の permit 待ち中の親取消で即座に終了し permit を取得しないこと)+レビュー(cancellation safety の判断) |
| tokio | ブロッキング | analyzer/lint(clippy::disallowed_methods で wrapper 外の直接呼び出しを拒否)+構造検査(許可する共通 wrapper の限定、run_blocking の permit 待ちで CancellationToken を先頭に置く biased な select! と permit 取得後の取消再確認)+実行テスト(permit 数の上限、permit 待ち中の親取消で即座に終了して permit を取得しないこと、permit 取得直後の取消で spawn_blocking を開始せず permit を解放すること)+計測テスト(最大実行時間)+レビュー(process 分離と chunk の停止点) |
| tokio | 共有状態 | 構造検査(bounded mpsc と単一所有 task)+レビュー(更新経路の単一性) |
| coordination | 資源の解放 | 型(Drop) |
| axum | server | 構造検査(認証 layer の位置と core 公開 API への principal・token・claim 型の流入禁止)+実行テスト(検証済み principal から actor への写像、actor と検証済み入力による core 公開 API 呼出、IntoResponse と CatchPanicLayer の応答、multi-tenant の TenantId・single-tenant sentinel・no-tenant sentinel の写像と相互混同拒否、server 発行 key と proof、proof のない別 client への保存 response 漏洩拒否)+レビュー |
| tower-sessions | BFF | 型(openidconnect の client・actor・埋め込んだ core の公開 API)+構造検査(route が core の公開 API だけを呼ぶこと)+実行テスト(`__Host-`、Secure、HttpOnly、SameSite、Path、Domain 未設定の統合テスト、principal から actor への写像、token の交換と更新、back-channel logout token の署名と claim の検証、issuer と sid/subject による session 失効、token ID の replay 拒否、replay 記録と失効の原子的な確定) |
| clap | console | 型(clap の derive) |
| apalis | worker | 構造検査(Cargo 依存の queue backend の単一性検査)+実行テスト(payload commit 後の upstream delivery ack、処理結果・処理済み記録 commit 後の inbox processing completion、各停止点の再配送、安定した effect operation と event ID の冪等キー、外部効果成功後の処理済み記録、結果一度分、容量上限の nack、使用量・上限・backlog・nack の監視)+レビュー(Data extractor による依存注入の判断) |
| 全域 | cast allowlist | 構造検査(reporting boundary の型消去 symbol と検証を完結する converter または factory の型構築 symbol を別の allowlist として照合し、集合外と種類不一致の cast を拒否)+実行テスト(converter または factory が検証後だけ型を構築) |
| tauri | desktop と mobile の host | レビュー |
| tower-lsp-server | extension の接続 | 型(tower-lsp-server の LanguageServer 実装と custom method)+レビュー |
| publication | 可視性 | 型(pub(crate))+構造検査(skeleton 境界の crate 依存) |

## 参照
検証の機械化と実行可能な仕様の検査経路は [verification](../../principles/verification.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
