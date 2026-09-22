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

## 配備の単位

配備は、1 顧客 1 配備を既定とする。
顧客ごとに専有の実行環境を用意し、その中にシステムと datastore を立てる。
複数の顧客が一つの実行環境を共有するマルチテナントの基盤を、前提にしない。

## 配備先の共有

一つの配備先へ複数の配備を載せる場合も、配備ごとに専有の実行環境を保つ。
hardware、機の利用者、接続経路、共有する listener、機の鍵、OS の世代の固定は、どの配備にも属さない配備先そのものの事実である。
配備先そのものの事実の正本は、その配備先を所有する一つの project の infrastructure に置く。
どの project が配備先を所有するかを、その配備先へ載せる全ての project の決定の記録に明記する。
所有しない project は、配備先そのものの事実を参照し、再定義も上書きもしない。
配備先に載っている配備の一覧は、各配備の宣言を正本とする。
配備先の上の一覧は、[principles/data](../../principles/data/append-facts-derive-state.md) の「事実は追記し、現在状態は導出する」に従う控えとして扱う。
反映は、一覧へ自らの項を冪等に加除し、他の配備の項を変えず、更新した一覧を配備先へ書き戻す。
共有する配備先の再現は、配備先そのものの事実と、一覧が指す各配備の宣言から行い、running な実行環境から数え上げない。
反映の確認は、その配備の生存と準備の面で行い、配備先全体の集約状態で判定しない。

## 配備対象と配備先

deploy は、surface と runtime が作る成果物を配備対象として受け取る。
他の領域は、deploy を参照しない。
deploy は、特定の配備先に縛られない。
配備先ごとの違いは、infrastructure と delivery の定義に閉じ込める。
具体の platform と tool は標準に固定せず、project が単一の採用を決定の記録に明記する。
利用者の端末で動く成果物(desktop・extension・console など)を store や marketplace で配布する経路は、deploy の配備先に含めない。
配布は、配布 channel を使う場合、release の成果物を提出手順へ渡す形で行い、更新も配布機構に任せる。
配布機構が更新を提供しない成果物は、署名を検証する自動更新の配布先を project が運用し、その配備先の宣言を infrastructure に置く。
配布機構が更新を提供する成果物に対して、自前の更新機構を作らない。
release する成果物の供給網の保証は [concerns/security](../../concerns/security/README.md) に従う。

## infrastructure

infrastructure は、配備先を宣言的に定義する。
手で変えた snowflake な構成を作らない。
同じ定義から、同じ配備先を再現する。
secret を含む state の暗号化は、[concerns/secrets](../../concerns/secrets/README.md) の規律に従う。
infrastructure の内部は、配備先の単位ごとに分ける。
一つの配備先の宣言を一つの単位にまとめ、複数の配備先の定義を一つの単位に混ぜない。

## delivery

delivery は、immutable な成果物を配備先へ反映する。
成果物の標準の形は、container artifact とする。
成果物の semantic versioning による版づけと不変性は [concerns/security](../../concerns/security/README.md) に、generated の drift 検査は [contracts/generated](../contracts/generated.md) に従う。
配備先の desired state を、宣言として版で管理する。
running な配備先を、手続きで直接書き換えない。
反映の振り分け、回帰の戻し方、migration を適用する時点は、[process/release](../../process/release.md) が定める。
反映時の生存と準備の規律は [concerns/lifecycle](../../concerns/lifecycle/README.md) に従う。
delivery の内部は、反映する配備先の単位に対応させて分ける。
一つの配備先への反映定義を一つの単位にまとめる。
delivery には、その project の配備への反映定義だけを置く。
配備先の種別に共通する反映の機構は、project の中に実装せず、独立した機構リポジトリを正本とする tool として扱う。
migration が満たす拡張・移行・収縮の段の区切りは [concerns/migration](../../concerns/migration/README.md) に従う。

## provenance

provenance は、成果物の出所の証明と署名を、配備の前に検証できるようにする。
SLSA provenance と SBOM と署名の生成は、release が行う。
配備の前の provenance と署名の検証は、[process/release](../../process/release.md) が定める。
attestation は、署名と内容を検証するまで、安全の証明にならない。

## secrets

secrets は、secret を at-rest 暗号化して保つ。
暗号化の機構の採用は、[tools/platforms/sops](../../tools/platforms/sops.md) が定める。
secret の型・読み込み・回転・失効・監査は、[concerns/secrets](../../concerns/secrets/README.md) に従う。
