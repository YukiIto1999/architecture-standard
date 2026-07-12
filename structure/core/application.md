# application 層

application 層は、業務動作を組み立てる層である。
domain を呼び出し、副作用は port を通じて行う。
application は [layout](./layout.md) の単位と依存に従う。

## port

port は、業務能力を宣言する interface である。
port は業務能力の単位で分割し、技術名で分割しない。
port の名前は、能力を表す語で付ける。
port のメソッドは、副作用を effect 型で返す。
port の実装は infrastructure が持つ。
application は port の抽象のみに依存し、adapter の実装型を参照しない。
effect の規律は [concerns/effect](../../concerns/effect.md) に従う。

## use-case

use-case は、単一の業務動作である。
use-case は、port と domain、および shared のみに依存する。
use-case は、別の use-case を参照しない。
use-case の強整合な書き込みは、一つの集約に閉じる。
複数の集約、または複数の use-case にまたがる流れは [composition](./composition.md) が担う。
use-case の名前は、単一の動作を表す動詞と名詞の組とする。
命名は [principles/naming](../../principles/naming.md) に、表記の規約は [languages](../../languages/) に従う。

## 入口での検証と認可

use-case は、入口で入力を parse し、型付きの command として受け取る。
parse の規律は [concerns/types](../../concerns/types.md) に従う。
認可は、use-case の入口で評価する。
認可の判定の port は目的で宣言し、engine への写像は adapter が担う。
認可の規律は [concerns/authorization](../../concerns/authorization.md) に従う。

## 結果と副作用

use-case は、結果を公開 outcome として返す。
domain イベントは、公開 outcome として返す。
副作用は、port を通じてのみ行う。
use-case は、直接の I/O、現在時刻の取得、乱数生成、ログを行わない。
use-case は、判断を domain の純粋関数に閉じる。
読む・判断する・書くの順と純粋核と効果の殻の分離は [concerns/effect](../../concerns/effect.md) に従う。

## トランザクション

use-case は、原子性の要求を宣言する。
冪等性が必要な use-case は、idempotency の store を port として宣言する。
トランザクション境界の適用は [composition](./composition.md) が担う。
use-case は UnitOfWork のハンドルを受け取らない。
トランザクションの規律は [concerns/transaction](../../concerns/transaction.md) に、冪等性の規律は [concerns/resilience](../../concerns/resilience.md) に従う。
