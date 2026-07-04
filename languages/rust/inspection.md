# inspection

## 概要
inspection は、Rust で検証を扱う実現軸である。
principles の [verification](../../principles/verification.md) が定める検証の機械化と、[evolution](../../principles/evolution.md) が定める構造を機械で守ることを、Rust の機構で満たす。

## 実行

### 要求
単体・性質・結合のテストの実行は cargo-nextest で行う。
doctest は cargo-nextest が対応しないため、`cargo test --doc` で別に実行する。

### 根拠
cargo-nextest は各テストを別のプロセスで実行し、状態を汚したテストが兄弟のテストを汚さない。
フィルタ・再試行・CI の分割を持ち、テストを速く決定的に回せる。
cargo-nextest はコンパイル済みのテストバイナリを実行する仕組みで、通常のテストバイナリの外で個別にコンパイルされる doctest には対応しない。
doctest は `cargo test --doc` で別に実行する。

### 完了条件
単体・性質・結合のテストの実行が、cargo-nextest で行われている。
doctest が、`cargo test --doc` で別に実行されている。

### 禁止事項
テスト同士が、共有した状態を通じて結果に影響し合うこと。

### 行動
単体・性質・結合のテストを cargo-nextest で実行し、CI の設定をリポジトリに固定する。
doctest は `cargo test --doc` を CI に別途組む。

## 性質

### 要求
property-based testing は proptest で書き、状態の遷移は proptest の stateful な形で書く。

### 根拠
例ベースのテストは、作者が選んだ少数の入力しか踏まない。
入出力の不変量を性質にし多くの入力を自動で生成すれば、見落とした領域の欠陥が出る。
失敗した入力は最小化され、小さな反例で原因を追える。
状態の遷移は、操作の列を生成して不変量を確かめる stateful な形で突ける。

### 完了条件
性質が proptest で書かれ、入出力の不変量を多くの入力で突いている。
状態の遷移が、stateful な形で書かれている。

### 禁止事項
性質の検査の本体で、最小化の効かない通常の assert を使うこと。

### 行動
入出力の不変量を性質にし、proptest で多くの入力を突く。
失敗の seed を回帰として残し、状態の遷移は stateful な形で書く。

### 例
```rust
// 一つの例しか踏まない
#[test] fn rev() { assert_eq!(reverse(reverse(vec![1,2,3])), vec![1,2,3]); }

// 性質を多くの入力で突き、最小化の効くアサーションを使う
proptest! {
    #[test]
    fn rev_twice(values in proptest::collection::vec(any::<i32>(), 0..100)) {
        prop_assert_eq!(reverse(&reverse(&values)), values);
    }
}
```

## 仕様

### 要求
業務語彙の executable spec は cucumber の Rust 実装で書く。

### 根拠
業務の語彙で書いた例を実行可能にすれば、仕様とコードが一緒に走り、ずれが検出される。
一つの文書が仕様であり検査でもあるので、片方だけ古くならない。

### 完了条件
業務語彙の executable spec が、cucumber の Rust 実装で書かれ、実行されている。

### 禁止事項
仕様に、実装の操作の語を書くこと。

### 行動
業務の語彙でシナリオを書き、cucumber の Rust 実装でステップを実装する。

## 実依存

### 要求
実依存のコンテナは testcontainers で起動する。

### 根拠
実依存を mock で置き換えると、実際のドライバや SQL の振る舞いを踏まない。
testcontainers で実依存のコンテナを起動すれば、本物に近い依存で検証でき、コンテナはテストの終わりに片づく。

### 完了条件
実依存のコンテナが、testcontainers で起動され、テストの終わりに片づいている。

### 禁止事項
接続の host や port を、固定で書くこと。

### 行動
実依存を testcontainers で起動し、割り当てられた host と port を取得して使う。

## 有効性

### 要求
mutation は cargo-mutants で検査し、検出されなかった mutant が一件でもあれば CI を失敗させる。
対象と絞り方の床は、structure/tests の methods に従う。

### 根拠
カバレッジは行が実行されたかしか測らず、振る舞いが固定されたかを測らない。
mutation はコードに人工の欠陥を注入し、テストがそれを落とせるかで、テストが本当に振る舞いを固定しているかを測る。
アサーションが弱いと、カバレッジが高くても欠陥が生き残る。
cargo-mutants は生存した mutant の有無を exit code で報告するので、しきい値は「検出されない mutant が無い」という二値の床になる。

### 完了条件
mutation が cargo-mutants で検査され、生き残った欠陥が潰されている。
検出されなかった mutant が一件でもあれば、CI が失敗で止まっている。
対象と絞り方の床が、structure/tests の methods の完了条件を満たしている。

### 禁止事項
結果が揺れるテストの上で、mutation を測ること。
生存した mutant を、しきい値の緩和や無視で見逃すこと。

### 行動
安定したテストの土台の上で cargo-mutants を回し、生き残った欠陥にテストを足す。
絞り込みは変異演算子と低リスク要素(参照データ表・等価変異)に限り、cargo-mutants を CI に組んで失敗で止める。
対象と絞り方は、structure/tests の methods に従う。

## 構造

### 要求
依存方向は workspace の crate 依存で強制し、crate 依存に乗らない規則は root の tests/ に置く自作の構造検査で検証する。
検査は import の走査で、層の参照禁止・公開面・配置の文法を確かめる。

### 根拠
依存方向を crate の依存グラフにすれば、下位が上位を参照できず、向きがビルドで強制される。
crate の依存に乗らない規則は、import を走査する自作の検査で確かめれば、構造の劣化が検査で止まる。
import の走査は型を介さない静的な呼び出しを見ないので、その禁止は clippy::disallowed_methods などの banned API の lint に割り当てる。

### 完了条件
依存方向が、crate 依存で強制されている。
crate 依存に乗らない規則が、import を走査する構造検査で検証されている。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。

### 行動
skeleton の境界を workspace の crate で分け、依存方向を Cargo の依存で強制する。
残りの規則を root の tests/ の構造検査で確かめる。

## 予防

### 要求
lint は clippy を `[workspace.lints.clippy]` で強制し、unwrap_used・expect_used を deny にする。
テストの unwrap・expect は、clippy.toml の allow-unwrap-in-tests・allow-expect-in-tests で許可する。
大きさとネストのしきい値は too_many_lines・excessive_nesting の lint の規則として定め、既定値から緩める変更は project の ADR に明記する。
excessive_nesting は既定のしきい値を持たないため、project が clippy.toml にしきい値を定め、ADR に記録する。
認知的複雑さは SonarQube の cognitive complexity(S3776)で測り、clippy 側に複雑度の規則を重ねて持たせない。
SonarQube の profile は cognitive complexity(S3776)に絞り、ローカル lint と同目的の規則を重ねない。
unsafe の使用は `[workspace.lints.rust]` の `unsafe_code = "forbid"` で既定禁止にし、unsafe を要する project は理由と局所化した `#[allow(unsafe_code)]` を ADR に記録する。

### 根拠
lint を workspace の lints で強制すれば、規則が全体に一律に効く。
unwrap_used・expect_used を deny にすれば、想定された失敗を握り潰すコードがビルドで止まる。
`unsafe_code = "forbid"` を workspace の lints に設定すれば、unsafe の使用が既定でビルドを止め、無秩序な混入を防ぐ。
unsafe が要る箇所は `#[allow(unsafe_code)]` で局所化し、理由を ADR に残せば、逸脱が可視化されたまま最小に保たれる。
clippy の lint 属性は crate 全体と item の単位に付けられ(文・式への属性は stable Rust では安定化されていない stmt_expr_attributes を要するため使えない)、Cargo.toml の `[lints]` はターゲット単位の上書きを持たないため、テストの除外は clippy.toml の allow-unwrap-in-tests・allow-expect-in-tests で行う。
too_many_lines と excessive_nesting は、関数の肥大化とネストの深さを早く気づかせる。
clippy 自身の cognitive_complexity lint は、原典と異なる独自のヒューリスティックで実装され、clippy 公式が測定ツールとしての使用を推奨していないため採用しない。
SonarQube の cognitive complexity は switch・match の構造化を一度だけ加点し、分岐の数に比例しないので、閉じた直和の網羅的な match を罰しない。
既定から緩める判断を ADR に残せば、緩和の理由が追える。

### 完了条件
workspace の lints に、unwrap_used・expect_used の deny の設定がある。
テストの unwrap・expect が、clippy.toml の allow-unwrap-in-tests・allow-expect-in-tests で許可されている。
大きさとネストのしきい値が、too_many_lines・excessive_nesting の lint の規則として定められている。
excessive_nesting のしきい値が、project の clippy.toml に定められ ADR に記録されている。
緩和が、project の ADR に明記されている。
`[workspace.lints.rust]` に `unsafe_code = "forbid"` が設定されている。
unsafe を要する箇所が、`#[allow(unsafe_code)]` で局所化され、project の ADR に記録されている。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
閉じた直和の網羅的な分岐を、複雑度の加点対象にする指標を採ること。
cognitive complexity を、clippy の cognitive_complexity lint で測ること。
unsafe を、workspace 全体で `#[allow(unsafe_code)]` して許可すること。

### 行動
`[workspace.lints.clippy]` に unwrap_used・expect_used を deny で設定し、clippy.toml に allow-unwrap-in-tests・allow-expect-in-tests を設定する。
too_many_lines・excessive_nesting を有効にし、excessive_nesting のしきい値と緩和は project の ADR に明記する。
`[workspace.lints.rust]` に `unsafe_code = "forbid"` を設定し、unsafe を要する箇所だけ `#[allow(unsafe_code)]` を局所的に付けて ADR に記録する。

### 例
```toml
# Cargo.toml
[workspace.lints.clippy]
unwrap_used = "deny"
expect_used = "deny"
too_many_lines = "warn"
excessive_nesting = "warn"

[workspace.lints.rust]
unsafe_code = "forbid"
```
```toml
# clippy.toml(ワークスペースルート)。テストの unwrap・expect は許可する
allow-unwrap-in-tests = true
allow-expect-in-tests = true
```

## ドキュメントコメントの存在

### 要求
crate ルートに `#![deny(missing_docs)]` を置き、`pub` な要素のドキュメントコメントの欠落をビルドの失敗にする。
非公開の要素は `clippy::missing_docs_in_private_items` を deny にし、ドキュメントコメントの欠落を検出する。
`# Errors`・`# Panics`・`# Safety` の節の欠落は、`clippy::missing_errors_doc`・`clippy::missing_panics_doc`・`clippy::missing_safety_doc` を deny にして検出する。
最初の一行がユビキタス言語と一致しているかは、レビューで確かめる。

### 根拠
missing_docs は rustc 組み込みの allow-by-default の lint で、deny にしなければ欠落が検出されない。
missing_docs は `pub` な要素だけを対象にし、非公開の要素のドキュメントコメントの欠落は検出しないので、`clippy::missing_docs_in_private_items` を別に deny にして非公開の要素を埋める。
clippy の missing_errors_doc・missing_panics_doc は Result を返す・panic しうる `pub fn` に節の記述を求め、missing_safety_doc は `pub unsafe fn` に `# Safety` を求めるので、formation が要求する節の網羅を公開要素の範囲で機械検査に載せられる。
内容がユビキタス言語と一致しているかの判断は意味を読む必要があり、機械化できない。

### 完了条件
crate ルートに `#![deny(missing_docs)]` があり、`pub` な要素のドキュメントコメントの欠落がビルドの失敗になっている。
非公開の要素のドキュメントコメントの欠落が、`clippy::missing_docs_in_private_items` で検出されている。
公開要素の `# Errors`・`# Panics`・`# Safety` の欠落が、clippy の missing_errors_doc・missing_panics_doc・missing_safety_doc で検出されている。
最初の一行とユビキタス言語の一致が、レビューで確かめられている。

### 禁止事項
`#![deny(missing_docs)]` を、crate 全体の `#![allow(missing_docs)]` で無効化すること。

### 行動
crate ルートに `#![deny(missing_docs)]` を置く。
`[workspace.lints.clippy]` に `missing_docs_in_private_items`・`missing_errors_doc`・`missing_panics_doc`・`missing_safety_doc` を deny で設定する。
最初の一行とユビキタス言語の一致は、レビューで確かめる。

## 規則と検証機構の対応

formation・translation・connection・retention・coordination・publication の各規律を、検証手段へ写像する。
機械検査を置けない規律は、レビューで確認すると明記し、割り当てを欠かさない。

| 実現軸 | 規律 | 検証手段 |
|---|---|---|
| formation | 業務の値を型に封じる | 型(newtype・非公開フィールド・Rust の可視性機構) |
| formation | 不正な状態を構築できなくする | 型(enum・網羅 match・コンパイラの網羅性検査) |
| formation | 不変を既定にする | 型(所有権・不変束縛) |
| formation | 意味と単位を型で区別する | 型(newtype) |
| formation | 命名と整形を道具に委ねる | analyzer/lint(rustfmt --check、rustc の non_snake_case 系 lint) |
| formation | 契約をドキュメントコメントに書く | analyzer/lint(missing_docs deny・clippy::missing_docs_in_private_items で存在、clippy::missing_errors_doc・missing_panics_doc・missing_safety_doc で公開要素の節の網羅)+レビュー(ユビキタス言語の一致・最初の一行の体裁) |
| formation | companion を proc-macro crate に分ける | 構造検査(companion 境界)+型(proc-macro crate type の compiler 制約) |
| translation | 境界で一度だけ parse してドメイン型へ移す | 型(TryFrom・deny_unknown_fields)+実行テスト(境界の parse の単体テスト) |
| translation | 公開するエラーを境界で problem+json へ写す | 実行テスト(IntoResponse の単体テスト) |
| translation | 生成した契約を使い、drift を検査の gate にする | 実行テスト(drift 検査・conformance の CI gate) |
| connection | 効果を言語の効果型で表す | 型(Future・Result) |
| connection | 失敗を Result に、欠陥を panic にする | analyzer/lint(clippy unwrap_used・expect_used deny)+型(Result) |
| connection | 要求する依存を能力の trait bound で型に出す | 型(trait bound) |
| connection | port を trait で宣言する | 型(trait)+構造検査(依存方向) |
| connection | 配線を組立点に置き、境界で実行する | 構造検査(自作。composition root 外の具象生成の検出)+レビュー |
| retention | 型付き SQL | 型/実行テスト(sqlx の `query!` コンパイル時検証・CI の offline 照合) |
| retention | 並行更新の表面 | 実行テスト(結合テストでの競合検出) |
| retention | 書き込みパス | 構造検査(自作。store が transaction の begin・commit を持たないことの検査) |
| retention | 一時データ | 構造検査(DB と Valkey のクレート分離)+レビュー |
| coordination | runtime | 構造検査(Cargo 依存の単一 runtime 検査) |
| coordination | 構造化並行 | レビュー |
| coordination | 取り消し | レビュー(cancellation safety の判断) |
| coordination | ブロッキング | analyzer/lint(clippy::disallowed_methods) |
| coordination | 共有状態 | analyzer/lint(clippy::await_holding_lock) |
| coordination | 資源の解放 | 型(Drop) |
| publication | server | 構造検査(自作。認証 layer の位置の検出)+レビュー |
| publication | BFF | レビュー+実行テスト(cookie 属性の統合テスト) |
| publication | console | 型(clap の derive) |
| publication | worker | 構造検査(Cargo 依存の queue backend の単一性検査) |
| publication | desktop と mobile の host | レビュー |
| publication | extension の接続 | 型(tower-lsp の trait 実装)+レビュー |
| publication | 可視性 | 型(pub(crate))+構造検査(skeleton 境界の crate 依存) |

## 参照
検証の機械化は [verification](../../principles/verification.md)、構造を守る進化は [evolution](../../principles/evolution.md) に従う。
配置は [structure/tests](../../structure/tests/layout.md)、技法は [structure/tests/methods](../../structure/tests/methods.md) に従う。
