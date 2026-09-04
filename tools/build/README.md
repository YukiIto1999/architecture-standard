# build

build は、task の編成、共有ライブラリの取得、契約と release metadata の生成、成果物の署名に使う道具の採用を定める。
エントリは、[README](../README.md) の書式と選定の共通基準に従う。
各エントリは、ツールごとのファイルが持つ。

| 用途 | 採用 | ファイル |
|---|---|---|
| task orchestrator | Nx | [nx.md](./nx.md) |
| 共有ライブラリの取得 | Vendoring | [vendoring.md](./vendoring.md) |
| 契約の記述と生成 | TypeSpec | [typespec.md](./typespec.md) |
| SBOM の生成 | Syft | [syft.md](./syft.md) |
| 成果物の署名と provenance | Cosign | [cosign.md](./cosign.md) |
| 契約駆動の fuzz | Schemathesis | [schemathesis.md](./schemathesis.md) |
| SBOM の既知脆弱性検査 | OSV-Scanner | [osv-scanner.md](./osv-scanner.md) |

task の定義と実行の正本は Nx に一本化し、recipe runner や環境ツールへ task の定義を並置しない。環境の供給は task の正本を持たない。
認知的複雑さの検査と quality gate は、[platforms/sonarqube](../platforms/sonarqube.md) の採用で満たす。
