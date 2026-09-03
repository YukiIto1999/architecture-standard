# lifecycle

## 概要
lifecycle は、プロセスの起動・健全性の宣言・終了を全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) と [data](../../principles/data/README.md) が定める境界と追記の永続化を、全系のプロセスの寿命の扱いとして具象化する。

## 規律

- [速く起動し、検証に失敗したら止める](./fast-validated-startup.md)
- [生存と準備を分けて公開する](./liveness-vs-readiness.md)
- [合図を受けたら受付をやめ、期限内で終える](./graceful-shutdown.md)
- [突然死に耐える](./crash-tolerance.md)

## 参照
起動時の検証は [configuration](../configuration/README.md)、取り消しの協調は [concurrency](../concurrency/README.md) に従う。
確定点は [transaction](../transaction/README.md)、冪等性と再実行・過負荷の抑制は [resilience](../resilience/README.md)、再配送は [messaging](../messaging/README.md) に従う。
面の構造は [structure](../structure/)、言語別の機構は [tools](../tools/) が定める。
