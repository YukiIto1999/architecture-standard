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
effect の規律は [concerns/effect](../../concerns/effect/README.md) に従う。

## use-case

use-case は、単一の業務動作である。
use-case は、port と domain、shared、および libs の公開技術 API のみに依存する。
use-case は、別の use-case を参照しない。
use-case の強整合な書き込みは、一つの集約に閉じる。
use-case は、一つの use-case を一つのフォルダに置く。
port への到達に共有の wrapper 層(capability accessor)を挟まず、use-case は port の抽象を直接受ける。
use-case の名前は、単一の動作を表す動詞と名詞の組とする。
use-case は、モデリング上のアクターの目的と変更理由、開始の契機、成功と拒否、確定する業務事実から分ける。
アクターの人数、認証 role、table、entity の数だけで use-case を分割しない。
分割の判断は [principles/separation](../../principles/separation/split-by-change-reason.md) の「変更理由で分ける」に従う。
命名は [principles/naming](../../principles/naming/README.md) に従う。
表記の規約は [languages](../../languages/) が定める。

## workflow

workflow は、同じコンテキストの複数の use-case を一つの業務の流れとして束ねる。
workflow は、use-case の公開入口を呼び、順序、結果に基づく分岐、再開点、打ち消しの開始を担う。
workflow の順序・分岐・再開・補償の規律は [concerns/workflow](../../concerns/workflow/README.md) に従う。
個々の不変条件と状態遷移は domain に、単一の業務動作は use-case に置き、workflow に重複させない。
分岐の意味を決める業務規則は domain の policy に置き、workflow は型付きの outcome に従って次の入口を選ぶ。
workflow は、adapter の実装型を参照せず、直接 I/O を行わない。
workflow は、別のコンテキストの use-case または workflow を参照しない。
workflow は、別の workflow を呼ばない。
workflow は、application 自身がトランザクションを制御する use-case の公開入口を受け取り、その実装や driver を構築しない。
一つの workflow は、一つの業務目的と一つの再実行単位に閉じる。
コンテキストをまたぐ状態変更は、integration event を outbox に確定し、受信側の application から新しい処理として開始する。

## 入力構築と保護の適用点

use-case と workflow は、コンテキストが所有する型付きの command を公開入口で受け取る。
command の公開入力構築は、[contracts/adapters](../contracts/adapters.md) が渡す field を内部の domain の検証付き constructor へ通し、コンテキスト固有の不変条件を型に残す。
公開契約の DTO を application や domain へ import せず、業務型を外から直接構築できるように公開しない。
型の構築時に保証する性質、現在状態に対する遷移条件、競合下での確定条件を分ける。
検証を一点に集める規律は [concerns/types](../../concerns/types/README.md) に従う。
公開入口の Interface は、操作の保護と、対象を取り出した後の保護を適用する位置を持つ。
認可の宣言は [contracts/adapters](../contracts/adapters.md) がその Interface へ接続し、業務本体は認可 engine や許可・拒否の結果を受け取らない。
当事者を必要とする操作だけ、コンテキスト固有の業務主体を入力へ含め、認証主体や共通の actor 型を全操作へ要求しない。
workflow は application が定める型の保護された子 use-case の入口を組立点から受け取り、契約 adapter の実装を参照しない。
子 use-case の呼び出しも保護と対象取得の契約を通し、workflow 自体の許可を子操作の許可へ流用しない。
認可の保証は [concerns/authorization](../../concerns/authorization/README.md) に従う。
実行文脈の由来と寿命は [concerns/context-propagation](../../concerns/context-propagation/README.md) に従い、domain の純粋な関数へ渡さない。

## 結果と副作用

use-case は、結果を公開 outcome として返す。
domain event はコンテキストの内部に閉じる。
外部へ公開する事実は、その event を公開する application の入口が domain event から integration event へ写像し、公開 outcome に含める。
外部副作用は、port または libs の公開技術能力の抽象を通じてのみ行う。
use-case は、直接の I/O、現在時刻の取得、乱数生成、ログを行わない。
use-case は、判断を domain の純粋関数に閉じる。
読む・判断する・書くの順と純粋核と効果の殻の分離は [concerns/effect](../../concerns/effect/README.md) に従う。

## トランザクション

use-case は、同時に確定する変更と事実、判断に必要な読み取り、確定条件を所有し、開始から確定または中止までを制御する。
制御は、port または libs の公開技術能力の抽象を通して、言語が定める遅延した効果として組む。
domain の純粋な判断は、状態と入力から新しい状態、事実、拒否を返し、transaction の境界を受け取らない。
application が定める開始と transaction scope の抽象と、具体的な DB driver の transaction handle を区別し、後者を application の Interface へ流さない。
冪等性が必要な use-case は、idempotency の store を port として宣言する。
状態の変更、必要な業務事実、公開する integration event の outbox 記録を同じ確定に含める。
workflow の step の確定は、workflow と step の組の一意性、状態の変更、outbox 記録、step の完了記録を同じ範囲へ含める。
競合、確定前の拒否、失敗、取消では中止を制御し、確定の結果が不明なときは成功や確実な未確定へ丸めない。
制御の所有は [concerns/transaction](../../concerns/transaction/application-owned-transactions.md) の「トランザクションの制御を application に置く」に従う。
workflow は複数の use-case を一つのトランザクションで包まず、各 use-case の確定点と公開 outcome を用いて進行する。
途中からの再開が必要な流れは、integration event までを永続する区切りとし、受信側の新しい workflow として再開する。
同じ workflow を再実行する場合は、workflow の識別子と進行済みの確定点を永続し、完了した use-case を重ねて実行しない。
workflow は、子 use-case の呼び出しに workflow の識別子と step の識別子を渡す。
トランザクションの規律は [concerns/transaction](../../concerns/transaction/README.md) に、冪等性の規律は [concerns/resilience](../../concerns/resilience/README.md) に従う。
