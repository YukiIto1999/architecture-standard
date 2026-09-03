# build

build は、task の編成、共有ライブラリの取得、契約と release metadata の生成、成果物の署名に使う道具の採用を定める。
エントリは、[README](../README.md) の書式と選定の共通基準に従う。
各エントリは、ツールごとの file が持つ。

| 用途 | 採用 | file |
|---|---|---|
| task orchestrator | Nx | [nx.md](./nx.md) |
| 共有ライブラリの取得 | Git submodule | [git-submodule.md](./git-submodule.md) |
| 契約の記述と生成 | TypeSpec | [typespec.md](./typespec.md) |
| SBOM の生成 | Syft | [syft.md](./syft.md) |
| 成果物の署名と provenance | Cosign | [cosign.md](./cosign.md) |
| 契約駆動の fuzz | Schemathesis | [schemathesis.md](./schemathesis.md) |
| SBOM の既知脆弱性検査 | OSV-Scanner | [osv-scanner.md](./osv-scanner.md) |

認知的複雑さの検査と quality gate は、[platforms/sonarqube](../platforms/sonarqube.md) の採用で満たす。
