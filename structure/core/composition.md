# composition 単位

composition 単位は、独立したコンテキストを組み立て、外部への入口を公開する。
配線、canonical の写像、トランザクション境界の適用を担う。
composition は [layout](./layout.md) の単位と依存に従う。

## build_core

build_core は、core の組立点である。
build_core は、コンテキストと shared を配線し、組み立て済みの API を返す。
build_core は、core の唯一の外部入口である。
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
integration event から受信側の入力への翻訳は、受信側を配線する composition が下流の側の翻訳として所有し、上流の event 型を受信側の domain へ持ち込まない。
コンテキスト間の関係と翻訳の所有の記録は [principles/separation](../../principles/separation/README.md) に従う。
composition は、業務判断を持たない。
composition が行うのは、配線と境界の写像である。
依存注入の規律は [concerns/dependency](../../concerns/dependency/README.md) に従う。

## operations

operations は、core が外へ公開する operation ごとに置く。
contract で公開する operation は canonical operation と一対一に対応する。
operations は、外部の operation を、一つのコンテキストの公開 application 入口へ写像する。
公開 application 入口は use-case または workflow である。
operations は、use-case の順序、結果による分岐、補償、コンテキストをまたぐ同期呼び出しを持たない。
派生読みモデルへの問い合わせは、読みモデルを所有するコンテキストの application に置く。
canonical の写像は、composition のみが持つ。
canonical の定義は [contracts](../contracts/layout.md) で規定する。
イベントの公開と配送は [application](./application.md) と [concerns/messaging](../../concerns/messaging/README.md) に従う。

## トランザクションと冪等性

composition は、UnitOfWork を所有する。
UnitOfWork が包む書き込みパスの内容は [concerns/transaction](../../concerns/transaction/README.md) に従う。
use-case は、UnitOfWork のハンドルを受け取らない。
composition の実行ラッパーは、use-case ごとに宣言された原子性を適用する。
composition は、各 use-case の実行ラッパーを組み立て、その呼び出し口を operation と workflow へ渡す。
workflow 全体を一つの UnitOfWork で包まない。
composition は、request context または canonical から冪等キーを取り出し、公開 application 入口の入力へ写像する。
実行ラッパーは、状態変更と公開 outcome に含まれる integration event の outbox 記録を同じ UnitOfWork で確定する。
workflow から呼ぶ実行ラッパーは、workflow と step の識別子を受け取り、その組の一意性、状態変更、outbox 記録、step の完了記録を同じ UnitOfWork で確定する。
composition は、outbox への記録経路と、確定済み outbox を読む配送経路を別々に配線する。
冪等性の規律は [concerns/resilience](../../concerns/resilience/README.md) に従う。

## 観測

observability の仕込みは、composition と infrastructure の境界の殻で行う。
domain と application は、その機構を直接使わず、事実を event で表す。
観測の規律は [concerns/observability](../../concerns/observability/README.md) に従う。

## actor

composition は、surface の認証境界が構築した actor だけを受け取る。
composition と core の公開 API は、principal、token、claim を受け取らない。
actor は、use-case または workflow へ引数として渡す。
actor の認可規律は [concerns/authorization](../../concerns/authorization/README.md) に従う。
