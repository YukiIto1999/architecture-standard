# infrastructure 層

infrastructure 層は、外部の I/O に接続し、port の実装を収める層である。
外部システムへの接続と副作用の実装は、この層だけに置く。
infrastructure は [layout](./layout.md) の単位と依存に従う。

## adapter

adapter は、application の port を実装する。
adapter は、core の側では application の port と domain、および shared のみに依存する。
adapter は、use-case を参照しない。
adapter の実装型は、配線する composition のみが参照する。
adapter の名前は、実装の方式を表す語で付ける。
DB driver、HTTP client、ファイルシステム、現在時刻の取得、乱数生成、外部 SDK は、この層でのみ用いる。
キャッシュは、cache-aside の adapter として置く。
キャッシュと一時データの store の採用は [tools/platforms/valkey](../../tools/platforms/valkey.md) が定める。
キャッシュの失効、無効化、配送 cache の範囲は [concerns/caching](../../concerns/caching/cache-aside.md) の「cache を正本の控えに保つ」に従う。
流入の制限は surface 側の境界に置き、置き場は各 surface の layout が定める。
core から外部システムへの呼び出しの制限に使うカウンタは、この層で一時データの store に置く。
副作用と非同期の境界の規律は [concerns/effect](../../concerns/effect/README.md) と [concerns/concurrency](../../concerns/concurrency/README.md) に従う。

## 永続化

datastore の採用は [tools/platforms/postgresql](../../tools/platforms/postgresql.md) が定める。
事実、状態、projection、派生読みモデルの性質は [concerns/persistence](../../concerns/persistence/README.md) に従い、確定点と outbox の性質は [concerns/transaction](../../concerns/transaction/README.md) に従う。
store と projection の読み取り port は application が宣言し、その実装と外部 datastore の adapter を infrastructure に置く。
store は record 型を定義し、domain と record の写像を持つ。
業務の区分と定義の識別子の写像は store が持ち、定義の行との対応の保証は [concerns/persistence](../../concerns/persistence/fact-state-time-relations.md) の「事実・状態・時間を別の関係に落とす」に従う。
store は、型付きの SQL を発行する薄い adapter として書く。
現在情報の変更、必要な業務イベント、projection、outbox を束ねる書き込みパスの制御は [application](./application.md) が所有する。
infrastructure は、application が要求する具体的な接続、取得、保存、確定と中止の操作を実装し、driver の型と資源を内部に閉じる。
個々の store が独立して確定したり、use-case 全体を受け取って transaction で包んだりしない。
派生読みモデルの再構築は、正本の現在情報または業務イベントを port から読み出す application workflow として、読みモデルを所有するコンテキストに置く。
起動は workflow を呼べる surface の layout に従う。
schema migration の実装は infrastructure に置き、適用の順序は [process/migration](../../process/migration.md) が定める。
個人データの消去や鍵の入れ替えなど、コンテキストの状態を扱う管理操作は application の use-case または workflow が制御し、この層には port の I/O 実装を置く。
消去する情報と期限は [concerns/privacy](../../concerns/privacy/README.md) に従う。
管理操作と消去の証跡は [concerns/audit-trail](../../concerns/audit-trail/README.md) に従う。

## 外部システム

外部システムへの接続は、client と adapter を持つ。
外部システムの wire 型と、domain との写像は、外部システムのファイル内に置く。

## 論理と物理の分離

record 型は、`persistence/` の中だけに置く。
外部システムの wire 型は、外部システムのファイルの中だけに置く。
domain と record の写像は store ファイル内に、domain と wire 型の写像は外部システムのファイル内に置く。
domain、application、composition は、record 型と外部システムの wire 型を参照しない。
論理の型と名前で区別する。
型名の接尾辞の規約は [languages](../../languages/) が定める。
型の分離は [concerns/types](../../concerns/types/README.md) に従う。
