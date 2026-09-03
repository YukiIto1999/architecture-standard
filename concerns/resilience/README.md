# resilience

## 概要
resilience は、障害への耐性を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める事実の追記と、[separation](../../principles/separation/README.md) が定める副作用の境界隔離を、全系の障害耐性として具象化する。
冪等・再試行・行き止まりの正本は resilience であり、[transaction](../transaction/README.md) は書き込みパスへの適用を、[messaging](../messaging/README.md) はイベント消費への適用を書く。

## 規律

- [信頼性を観測可能な目標として定める](./reliability-targets.md)
- [再実行のある操作を冪等にする](./idempotent-operations.md)
- [外部依存の呼び出しを制御する層に置く](./dependency-call-control.md)
- [失敗を区画に閉じる](./bulkhead-isolation.md)
- [障害を別経路で覆い隠さない](./no-untested-fallback.md)
- [過負荷を抑える](./overload-mitigation.md)
- [流入を制限する](./admission-control.md)
- [再試行の出口を持つ](./dead-letter-exit.md)

## 参照
port の構造は [structure/core/application](../../structure/core/application.md)、言語別の機構は [tools](../tools/) が定める。
時間上限の合成と期限の伝播は [concurrency](../concurrency/README.md)、過負荷の中での健全性の応答の優先は [lifecycle](../lifecycle/README.md) に従う。
