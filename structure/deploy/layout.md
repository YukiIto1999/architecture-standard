# deploy の構造

deploy は、成果物を配備先へ届ける ops と platform の領域である。
配備先は managed service・cluster・on-prem など様々であり、同じ規律で扱う。
deploy は、ops と platform を持つ project にだけ置く。
deploy は [skeleton](../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
deploy/
├─ infrastructure/   宣言的に定義した配備先。
├─ delivery/         immutable な成果物を配備先へ反映する。
├─ provenance/       成果物の出所の証明と署名。
└─ secrets/          at-rest で暗号化した secret。
```

`infrastructure` は配備先を宣言的に定義する。
`delivery` は成果物を配備先へ届ける。
`provenance` は成果物の完全性を検証できるようにする。
`secrets` は暗号化した secret を持つ。

## 配備対象と配備先

deploy は、surface と runtime が作る成果物を配備対象として受け取る。
他の領域は、deploy を参照しない。
deploy は、特定の配備先に縛られない。
配備先ごとの違いは、infrastructure と delivery の定義に閉じ込める。
具体の platform と tool は標準に固定せず、project が単一の採用を ADR に明記する。
利用者の端末で動く成果物(desktop・extension・console など)を store や marketplace で配布する経路は、deploy の配備先に含めない。
配布は、release の成果物を、配布 channel の提出手順へ渡す形で行う。
配布と更新は、配布 channel や store などの配布機構に任せ、自前の更新機構を作らない。
release する成果物の供給網の保証は [concerns/security](../../concerns/security.md) に従う。

## infrastructure

infrastructure は、配備先を宣言的に定義する。
手で変えた snowflake な構成を作らない。
同じ定義から、同じ配備先を再現する。
secret を含む state の暗号化は、secrets の規律に従う。
infrastructure の内部は、配備先の単位ごとに分ける。
一つの配備先の宣言を一つの単位にまとめ、複数の配備先の定義を一つの単位に混ぜない。

## delivery

delivery は、immutable な成果物を配備先へ反映する。
成果物の標準の形は、container artifact とする。
成果物の semantic versioning による版づけと不変性は [concerns/security](../../concerns/security.md) に、generated の drift 検査は [contracts/generated](../contracts/generated.md) に従う。
配備先の desired state を、宣言として版で管理する。
running な配備先を、手続きで直接書き換えない。
配備の回帰は、新しい版を切るのでなく、前の不変な版の desired state へ宣言を戻して反映する。
配備先への反映は、準備の面が処理可能を宣言してから振り分け、全インスタンスの同時離脱を避ける。
反映時の生存と準備の規律は [concerns/lifecycle](../../concerns/lifecycle.md) に従う。
delivery の内部は、反映する配備先の単位に対応させて分ける。
一つの配備先への反映定義を一つの単位にまとめる。
datastore の schema migration は、新しい版のアプリケーションへ切り替える前に適用する。
migration の実施は delivery の反映手順の一部とし、アプリケーションの起動処理へ埋め込まない。
migration が満たす拡張・移行・収縮の段の区切りは [concerns/persistence](../../concerns/persistence.md) に従う。

## provenance

provenance は、成果物の出所の証明と署名を、配備の前に検証できるようにする。
SLSA provenance と SBOM と署名の生成は、release が行う。
配備の前に、provenance と署名を検証し、検証できない成果物を配備しない。
attestation は、署名と内容を検証するまで、安全の証明にならない。

## secrets

secrets は、secret を at-rest 暗号化して保つ。
暗号化の機構の採用は、[tools/platforms](../../tools/platforms.md) に従う。
secret の型・読み込み・回転・失効・監査は、[concerns/configuration](../../concerns/configuration.md) に従う。
