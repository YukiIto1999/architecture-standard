# cargo-llvm-cov

用途は、テストが実行していない箇所を見つけるカバレッジ計測である。
採用は、Rust は cargo-llvm-cov である。
判断基準は、採用済みのテスト実行系と統合して、stable toolchain で region と line を数える機械可読な coverage report を出力し、記録した下限を自身の終了値で判定できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、stable toolchain で region を数える設定、report 形式、test runner との統合方法の変化を再評価のトリガーとする。branch が stable toolchain で数えられるようになることと、match の腕・or-pattern・`?`・`.await`・macro 展開の分岐を branch が数えるようになることも、再評価のトリガーとする。

## カバレッジ

### 要求
カバレッジは cargo-llvm-cov で計測し、stable toolchain で region と line を数える。
下限は、project が region と line のそれぞれに記録する。
記録した下限は、`cargo llvm-cov nextest` に `--fail-under-regions` と `--fail-under-lines` を与えた終了値で、検証入口が判定する。
機械可読な計測の記録は、`--json` の出力で残す。
branch・MC/DC・doctest の計測は、nightly toolchain を要する間、下限の判定に使わない。
カバーしない箇所の扱いと、数値を目標にしない扱いは、[structure/tests の methods](../../structure/tests/methods.md) に従う。

### 根拠
region は stable で数えられる統計のうち最も細かく、一行の中の複数の区間を別々に数えるため、line だけでは見えない未実行を示す。
短絡する論理式の右辺のように、実行された行の中にある未実行の区間も、region なら数に入る。
branch は unstable で nightly toolchain を要するため、最新の stable toolchain に追随する言語の採用と両立しない。
branch は、match の腕と or-pattern、`?`、`.await`、macro 展開が作る分岐を今も数えないため、Rust で多く現れる分岐が母数から抜けた比率になる。
条件の真偽の片側しか実行されていない状態は region では見えないが、比較演算子と match arm guard と match の腕を変異させる cargo-mutants の検査が、同じ穴をテストの有効性の側から突く。
下限の判定を cargo-llvm-cov 自身の終了値に任せれば、report を読み直す仕組みを別に持たずに済む。

### 完了条件
カバレッジが cargo-llvm-cov で計測され、stable toolchain で region と line が数えられている。
project が、region と line の下限を記録している。
記録した下限が、`--fail-under-regions` と `--fail-under-lines` を与えた cargo-llvm-cov の終了値で、検証入口で判定されている。
機械可読な計測の記録が、`--json` の出力として残っている。
branch・MC/DC・doctest の計測が、下限の判定に使われていない。

### 禁止事項
下限の判定に、nightly toolchain を要する指標を使うこと。
line の下限だけで、カバレッジの判定を済ませること。
カバレッジの数値を、テストの有効性が足りている証拠として扱うこと。
下限を、計測した値に合わせて下げること。

### 行動
`cargo llvm-cov nextest` を検証入口に組み、region と line の下限を `--fail-under-regions` と `--fail-under-lines` で渡す。
下限の値を、project の決定の記録に残す。
`--json` の出力を、計測の記録として残す。
未実行の region を読み、テストの取りこぼしを塞ぐ。
