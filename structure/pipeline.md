# pipeline

pipeline は、リポジトリ全体を検証し、版を付けて release するまでの流れを定める。
pipeline は、orchestrator の定義・段階の定義・release の定義を持つ。内部の形は採用する機構に従う。
pipeline は [skeleton](./skeleton.md) の命名に従う。
CI・release の定義は、root の pipeline に置く。
CI の機構がファイルの置き場を強制する場合、その置き場には pipeline の定義を呼ぶ最小の起動だけを置く。

## 検証とゲート

pipeline は、[tests](./tests/layout.md) の段階実行に従って検証する。
段階は、workspace の orchestrator の build グラフへ写し、変更の影響範囲に応じた差分で実行する。
検証が落ちたら、release を止める。
個々の検証の合否と閾値は tests と [languages](../languages/) と [principles/verification](../principles/verification.md) が定め、pipeline はそれらを release のゲートとして段階に束ねて停止を決める。
pipeline は、generated の drift を検査する。
drift が出たら、release を止める。
pipeline は、tests の段階とは別の供給網のゲートとして、依存する部品の既知の脆弱性を SBOM から検査する。
脆弱性が見つかったら、release を止める。
供給網の検査の規律は本書が定め、配備直前の provenance の検証は [deploy](./deploy/layout.md) に従う。
認知的複雑さは、セルフホストした SonarQube Community Build の quality gate を CI が待ち受けて検査し、不合格なら release を止める。

## release

release する成果物は、SLSA provenance と SBOM と署名を備える。
provenance と署名の生成は release が行い、配備直前の検証は [deploy](./deploy/layout.md) に従う。
release は、semantic versioning で版を付ける。
版は、不変とし、付け直さない。
配布の channel が成果物ごとに分かれても、版はリポジトリ単一の semver に従う。
署名のない成果物を、release しない。
release した成果物の配備は [deploy](./deploy/layout.md) に従う。

## 機構

具体の CI と release の機構は標準に固定せず、project が単一の採用を ADR に明記する。
