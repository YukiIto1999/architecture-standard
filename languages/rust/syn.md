# syn

用途は、依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である。
採用は、Rust の構造検査に syn の `parsing` と `full` の feature を使う。
判断基準は、層の参照禁止・公開面・配置の文法を規則として書け、違反をリポジトリの検証入口で止められることである。採用している stable toolchain が Rust の構文木を検査へ公開せず、syn が `parse_file` でその構文木を提供することを含む。
撤回条件は、判断基準を満たさなくなることであり、syn の保守の停止と、stable toolchain が構文木を読む API を公開したことを再評価のトリガーとする。

## 構造検査

### 要求
Rust の構造検査は、source を syn の `parse_file` で構文木へ読む。
use 宣言の module path、item の可視性と配置、impl の trait path と self type、関数の signature、属性とドキュメントコメント、macro の呼び出しを構造検査で取得する。
取得した構造を、依存方向・公開面・配置の文法の規則へ照合する。

### 根拠
採用している stable toolchain は、Rust の構文木を検査へ公開しない。
`proc_macro` は手続き的 macro の実装の中だけで使え、その外から呼ぶと panic する。
`rustc_private` は nightly の機能であり、`rustc-dev` component を要するので stable の採用と両立しない。
syn は stable の crate として `parse_file` を提供し、use 宣言・可視性・impl の trait path と self type・signature・属性・macro 呼び出しを同じ構文木から取れる。

### 完了条件
構造検査が、syn の `parse_file` で source を構文木へ読んでいる。
構造検査が、use 宣言の module path、item の可視性と配置、impl の trait path と self type、関数の signature、属性とドキュメントコメント、macro の呼び出しを取得している。
取得した構造が、依存方向・公開面・配置の文法の規則へ照合されている。

### 禁止事項
構文木で判定できる構造を、文字列の検索だけで判定すること。
構造検査のために、nightly の toolchain または `rustc_private` を要する機構を検証入口へ持ち込むこと。

### 行動
root の tests に置く構造検査から、対象の source を syn の `parse_file` で読む。
use 宣言・可視性・impl の trait path と self type・signature・属性・macro 呼び出しを列挙する。
列挙した構造を、検証入口で規則へ照合する。
