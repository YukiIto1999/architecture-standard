# composition 単位

composition 単位は、独立したコンテキストと外部依存の adapter を配線し、core の公開 API を構築する。
公開契約の写像、業務判断、トランザクションの制御は持たない。
composition は [layout](./layout.md) の単位と依存に従う。

## build_core

build_core は、core の組立点である。
build_core は、コンテキストと shared を配線し、組み立て済みの API を返す。
build_core は、core の唯一の構築入口である。
build_core は起動しない。
build_core は module factory であり、プロセス全体の composition root ではない。
起動側が解釈済みの型付き設定と生成済みの外部依存を受け取り、設定源を読み込まない。
プロセスの起動は、core を埋め込む surface または host が担う。

## 配線

composition は、port に adapter を結びつける。
コンテキストの adapter を配線し、それぞれの port を結ぶ。
異なるコンテキストの状態変更を、同期呼び出しで結ばない。
複数コンテキストの情報を即時に読む operation は、その query を所有するコンテキストの読みモデルへ写像する。
application が公開した integration event を libs の配送 port へ渡す経路を、composition が配線する。
整合の即時性を要さない派生読みモデルへは、outbox を経て非同期で駆動する。
integration event の消費は、composition が受信側コンテキストの公開 application 入口へ配線する。
公開 event から受信側の入力への翻訳は [contracts/adapters](../contracts/adapters.md) が所有し、composition は翻訳済みの受信入口を配線する。
コンテキスト間の関係と翻訳の所有の記録は [principles/separation](../../principles/separation/README.md) に従う。
composition は、業務判断を持たない。
composition が行うのは、公開された構築用 API を使った配線である。
依存注入の規律は [concerns/dependency](../../concerns/dependency/README.md) に従う。

## 公開 API

組み立て済みの API は、各コンテキストの公開 application 入口と、その入力構築、result と outcome の Interface を公開する。
use-case の順序、結果による分岐、再開、補償は、コンテキストの application workflow が持つ。
派生読みモデルへの問い合わせも、読みモデルを所有するコンテキストの application に置く。
composition は、コンテキストが公開した入力構築をそのまま利用できるように配線し、業務型の constructor を外へ公開しない。
外部の canonical operation と core API の接続、生成 DTO との写像は [contracts/adapters](../contracts/adapters.md) が所有する。
core は、公開契約の schema、生成 DTO、通信 client と stub を参照しない。
canonical との対応は外部へ業務契約として公開する operation を対象とし、構築用 API、port、内部の application 入口を同数の operation として追加しない。
コンテキストの管理操作も application の公開する実行契約へ配線し、composition 自身に処理の順序や実行本体を置かない。
イベントの公開と配送は [application](./application.md) と [concerns/messaging](../../concerns/messaging/README.md) に従う。

## トランザクションの能力の配線

トランザクションの制御は [concerns/transaction](../../concerns/transaction/application-owned-transactions.md) の「トランザクションの制御を application に置く」に従う。
composition は、application が必要とする確定の能力と、同じ書き込み範囲で使う store、outbox、冪等性の能力を配線する。
開始、読む順序、書く順序、確定、中止を決める処理や、use-case 全体を包む実行ラッパーを置かない。
具体的な DB driver の transaction 型を application の Interface へ渡さない。
outbox への記録経路と、確定済み outbox を読む配送経路を別々に配線する。
状態、業務事実、outbox、workflow の step と冪等性の必要な同時確定は、application が制御する書き込みパスへ閉じる。
冪等性の規律は [concerns/resilience](../../concerns/resilience/README.md) に従う。

## 観測

observability の仕込みは、composition と infrastructure の境界の殻で行う。
domain と application は、その機構を直接使わず、事実を event で表す。
観測の規律は [concerns/observability](../../concerns/observability/README.md) に従う。

## 業務入力と実行文脈

core の公開 API は、コンテキストが意味と保証を所有する業務入力を受け取る。
principal、token、claim、認証方式の型を受け取らず、全ての use-case に共通の actor を要求しない。
当事者が業務事実や遷移条件に必要な操作だけ、そのコンテキストの業務主体を入力に含める。
公開入口と対象取得の保護の適用点は、application が公開する実行契約に従って配線する。
認証認可の宣言の接続は [contracts/adapters](../contracts/adapters.md) が所有する。
実行の期限、取消、相関の文脈は [concerns/context-propagation](../../concerns/context-propagation/README.md) に従い、業務入力やドメイン型へ混ぜない。
