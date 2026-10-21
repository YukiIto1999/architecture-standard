# cargo-auditable

用途は、Rust の最終成果物へ、実際に含まれる crate の依存情報を埋め込み、成果物の走査だけで SBOM の部品を回収できるようにする機構である。
採用は、Rust は cargo-auditable である。
判断基準は、依存情報を成果物の中へ埋め込み、[syft](../../tools/build/syft.md) が最終成果物だけから crate と版を回収できることであり、build の経路が既に適用している場合はその経路を使い、同じ機構を重ねて要求しないことを含む。
撤回条件は、判断基準を満たさなくなることであり、Cargo 本体が安定版で依存情報を成果物へ埋め込むようになること、Syft の対応の終了、保守の停止を再評価のトリガーとする。

## 成果物の依存情報

### 要求
Rust の release する binary は、cargo-auditable が埋め込んだ依存情報を持つ。
build の経路が既に cargo auditable を適用する場合は、その経路を使い、同じ wrapper を追加しない。
適用しない経路の release の build は、`cargo auditable build` で行う。
依存情報の有無は、build の設定でなく最終 binary で確かめる。
依存情報は SBOM の部品を回収するためだけに使い、脆弱性の判定は [osv-scanner](../../tools/build/osv-scanner.md) に単一にして、別の advisory 検査を並置しない。

### 根拠
Rust の binary は静的に結合され、build の後は Cargo.toml と Cargo.lock が成果物に残らないので、binary だけを渡された Syft は crate の部品を回収できず、SBOM が部品を欠く。
cargo-auditable は、依存の木を成果物の linker section へ埋め込むので、Syft が最終成果物だけから crate と版を回収できる。
Nix の buildRustPackage は、`auditable` の既定を cargo-auditable の `meta.broken` が偽であることで決め、有効なら auditable 用の cargo wrapper を build の入力へ加える。
NixOS に載せることと Nix で build することは別であり、NixOS に載せる成果物でも build の経路が Nix とは限らないので、要求は build の経路でなく最終 binary に掛ける。
cargo-auditable は host と build の platform が異なるとき `meta.broken` が真になるので、クロスコンパイルでは Nix の既定が黙って無効になりうる。
設定でなく最終 binary を検査すれば、既定が無効になった build を release の前に拒否できる。
build の経路が既に埋め込みを行うなら、別の wrapper を足しても成果物の依存情報は増えず、同じ機構を作る手段が二つに分かれる。
cargo-auditable は供給網の攻撃を防がず、build が見た依存の一覧を成果物へ残すだけであり、既知の脆弱性の判定は SBOM を入力にする OSV-Scanner が担う。

### 完了条件
release する binary が、cargo-auditable の依存情報を持っている。
依存情報の crate と版が、成果物の package の runtime 依存の集合を欠かさず含んでいる。
build の経路が既に cargo auditable を適用する場合に、同じ wrapper が追加されていない。
適用しない経路の release の build が、`cargo auditable build` で行われている。
依存情報を持たない binary が、検証入口で拒否されている。
脆弱性の gate が OSV-Scanner だけであり、別の advisory 検査が並置されていない。

### 禁止事項
依存情報を持たない binary を、release すること。
build の経路が既に適用している cargo auditable に、別の wrapper を重ねること。
build の設定の有無だけで、最終 binary の依存情報を検査済みとすること。
cargo audit など、OSV-Scanner と別の advisory 検査を、脆弱性の gate として並置すること。

### 行動
Nix の buildRustPackage で build するときは、既定の経路を使い、`auditable` を無効にしない。
それ以外の経路では、release の build を `cargo auditable build --release` で行う。
最終 binary だけを入力にして Syft で走査し、crate の部品が runtime 依存の集合を含むことを確かめる。
脆弱性の判定は、SBOM から OSV-Scanner で行う。
