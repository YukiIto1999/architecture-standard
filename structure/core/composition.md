# composition 単位

composition 単位は、独立したコンテキストを組み立て、外部への入口を公開する。
配線、コンテキストをまたぐ流れ、canonical の写像、トランザクション境界を担う。
composition は [layout](./layout.md) の単位と依存に従う。

## build_core

build_core は、core の組立点である。
build_core は、コンテキストと shared を配線し、組み立て済みの API を返す。
build_core は、core の唯一の外部入口である。
build_core は起動しない。
プロセスの起動は、core を埋め込む surface または host が担う。

## 配線

composition は、port に adapter を結びつける。
コンテキストの adapter を配線し、それぞれの port を結ぶ。
コンテキストどうしは、composition が port を介して結ぶ。
コンテキストの domain event を libs の機構の port へ駆動する経路も、composition が持つ。
整合の即時性を要さない派生読みモデルへは、outbox を経て非同期で駆動する。
composition は、業務判断を持たない。
composition が行うのは、配線、写像、コンテキストをまたぐ流れの調整である。
依存注入の規律は [concerns/dependency](../../concerns/dependency.md) に従う。

## operations

operations は、canonical operation ごとに置く。
operations は、canonical とコンテキストの入出力を写像する。
operations は、複数の集約・複数の use-case・複数のコンテキストにまたがる流れを担う。
派生読みモデルへの問い合わせは、単一コンテキスト内なら当該コンテキストの application、複数コンテキストにまたがるなら operations に置く。
operations は、domain イベントを integration event へ写像する。
canonical の写像は、composition のみが持つ。
canonical の定義は [contracts](../contracts/layout.md) で規定する。
イベントの配送は [concerns/messaging](../../concerns/messaging.md) に従う。

## トランザクションと冪等性

composition は、UnitOfWork を所有する。
UnitOfWork が包む書き込みパスの内容は [concerns/transaction](../../concerns/transaction.md) に従う。
use-case は、UnitOfWork のハンドルを受け取らない。
composition は、request context または canonical から冪等キーを取り出し、use-case または port の入力へ写像する。
冪等性の規律は [concerns/resilience](../../concerns/resilience.md) に従う。

## 観測

observability の仕込みは、composition と infrastructure の境界の殻で行う。
domain と application は、その機構を直接使わず、事実を event で表す。
観測の規律は [concerns/observability](../../concerns/observability.md) に従う。

## 設定

config は、型付きの設定を起動時に読み込む。
実行時に切り替える flag は設定と分離する。
機構は、採る project が単一採用を ADR に明記する。
設定の規律は [concerns/configuration](../../concerns/configuration.md) に従う。

## actor

composition は、request context から principal を actor へ写像する。
actor は、use-case へ引数として渡す。
actor の写像の規律は [concerns/authorization](../../concerns/authorization.md) に従う。
