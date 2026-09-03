# application 層

application 層は、単一の業務動作と、同じコンテキスト内の業務の流れを組み立てる層である。
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
use-case の名前は、単一の動作を表す動詞と名詞の組とする。
命名は [principles/naming](../../principles/naming.md) に従う。
表記の規約は [languages](../../languages/) が定める。

## workflow

workflow は、同じコンテキストの複数の use-case を一つの業務の流れとして束ねる。
workflow は、use-case の公開入口を呼び、順序、結果に基づく分岐、再開点、打ち消しの開始を担う。
workflow の順序・分岐・再開・補償の規律は [concerns/workflow](../../concerns/workflow.md) に従う。
個々の不変条件と状態遷移は domain に、単一の業務動作は use-case に置き、workflow に重複させない。
分岐の意味を決める業務規則は domain の policy に置き、workflow は型付きの outcome に従って次の入口を選ぶ。
workflow は、adapter の実装型を参照せず、直接 I/O を行わない。
workflow は、別のコンテキストの use-case または workflow を参照しない。
workflow は、別の workflow を呼ばない。
workflow は use-case の実装を直接構築せず、composition がトランザクション境界を適用した呼び出し口を受け取る。
一つの workflow は、一つの業務目的と一つの再実行単位に閉じる。
コンテキストをまたぐ状態変更は、integration event を outbox に確定し、受信側の application から新しい処理として開始する。

## 入口での検証と認可

use-case と workflow は、公開入口で入力を parse し、型付きの command として受け取る。
parse の規律は [concerns/types](../../concerns/types.md) に従う。
workflow は全体の入力検証と認可を最初の確定前に行い、各 use-case も自身の操作に対する認可を入口で評価する。
認可の判定の port は目的で宣言し、engine への写像は adapter が担う。
認可の規律は [concerns/authorization](../../concerns/authorization.md) に従う。

## 結果と副作用

use-case は、結果を公開 outcome として返す。
domain event はコンテキストの内部に閉じる。
外部へ公開する事実は、その event を公開する application の入口が domain event から integration event へ写像し、公開 outcome に含める。
副作用は、port を通じてのみ行う。
use-case は、直接の I/O、現在時刻の取得、乱数生成、ログを行わない。
use-case は、判断を domain の純粋関数に閉じる。
読む・判断する・書くの順と純粋核と効果の殻の分離は [concerns/effect](../../concerns/effect.md) に従う。

## トランザクション

use-case は、原子性の要求を宣言する。
冪等性が必要な use-case は、idempotency の store を port として宣言する。
トランザクション境界の適用は [composition](./composition.md) の実行ラッパーが担う。
use-case は UnitOfWork のハンドルを受け取らない。
workflow は複数の use-case を一つのトランザクションで包まず、各 use-case の確定点と公開 outcome を用いて進行する。
途中からの再開が必要な流れは、integration event までを永続する区切りとし、受信側の新しい workflow として再開する。
同じ workflow を再実行する場合は、workflow の識別子と進行済みの確定点を永続し、完了した use-case を重ねて実行しない。
workflow は、子 use-case の呼び出しに workflow の識別子と step の識別子を渡す。
トランザクションの規律は [concerns/transaction](../../concerns/transaction.md) に、冪等性の規律は [concerns/resilience](../../concerns/resilience.md) に従う。
