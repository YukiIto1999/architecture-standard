# release の順序

release は、成果物の検証から配備先への反映まで、戻せる状態を保って進める。
成果物、配備先、provenance、secrets の構成は [structure/deploy](../structure/deploy/layout.md) に従う。

## 順序

1. 成果物の生成と同時に、SLSA provenance と SBOM と署名を生成する([structure/deploy](../structure/deploy/layout.md) の provenance に従う)。
2. 配備の前に、provenance と署名を検証し、検証できない成果物を配備しない。
3. datastore の schema migration は、新しい版のアプリケーションへ切り替える前に適用する。migration の実施は delivery の反映手順の一部とし、アプリケーションの起動処理へ埋め込まない。
4. 配備先への反映は、準備の面が処理可能を宣言してから振り分け、全インスタンスの同時離脱を避ける。
5. 配備の回帰は、新しい版を切るのでなく、前の不変な版の desired state へ宣言を戻して反映する。

## 確認点

release 前の検証は、[verification](./verification.md) の「順序」に従って全域まで実行する。
反映時の生存と準備は、[concerns/lifecycle](../concerns/lifecycle.md) の完了条件と禁止事項に照合する。
migration の段の区切りは、[concerns/migration](../concerns/migration.md) に照合する。
稼働中のデータを移す配備は、[migration](./migration.md) に従う。

## 範囲外

成果物の版づけと不変性の規範は扱わない([concerns/security](../concerns/security.md) と [structure/deploy](../structure/deploy/layout.md) が正本である)。
