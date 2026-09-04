# 演習の順序

演習は、稼働する系と運用の穴を、攻撃者と障害の視点で定期的に探す。
検証の技法は [structure/tests/methods](../structure/tests/methods.md)、脅威の前提は [concerns/security](../concerns/security/README.md) に従う。

## 順序

1. 自己ペネトレーション: 信頼境界ごとの abuse case を攻撃者の視点で実行し、認証・認可・入力検証・secret の扱いを突く。対象と手順は、project が脅威モデルから導く。
2. 運用ロールプレイ: 障害からの復旧・権限の剥奪・secret の失効・backup の復元のシナリオを演じ、runbook・観測・回復経路の穴を確かめる。
3. 発見を、[audit](./audit.md) の違反と同じ書式で列挙し、是正を [review](./review.md) と決定の記録へ還流する。

## 確認点

演習の頻度と対象が、project の決定の記録に定められている。
発見が、severity と該当箇所を添えて記録されている。
runbook と観測の修正が、演習の発見へ遡れる。
