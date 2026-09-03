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
application の store port、projection の読み取り port、外部 datastore の adapter は infrastructure に置く。
store は record 型を定義し、domain と record の写像を持つ。
store は、型付きの SQL を発行する薄い adapter として書く。
イベントの追記・projection の更新・outbox への記録を束ねる書き込みパスの境界の所有は、[composition](./composition.md) が持つ。
派生読みモデルの再構築は、正本のイベントを順に port へ流す application workflow として、読みモデルを所有するコンテキストに置く。
起動は workflow を呼べる surface の layout に従う。
schema migration の実装は infrastructure に置き、適用の順序は [process/migration](../../process/migration.md) が定める。
個人データを消去する port の実装と管理操作は infrastructure に置き、消去する情報と期限は [concerns/privacy](../../concerns/privacy/README.md) に従う。
管理操作と消去の証跡は [concerns/audit-trail](../../concerns/audit-trail/README.md) に従う。

## 外部システム

外部システムへの接続は、client と adapter を持つ。
外部システムの wire 型と、domain との写像は、外部システムのファイル内に置く。
認可の判定の adapter は、認可の engine を呼ぶ。
認可の engine の採用は [tools/platforms/openfga](../../tools/platforms/openfga.md) が定める。
判定の cache と engine の datastore の採用は [tools/platforms](../../tools/platforms/README.md) が定める。
認可のモデルと判定の規律は [concerns/authorization](../../concerns/authorization/README.md) に従う。

## 論理と物理の分離

record 型は、`persistence/` の中だけに置く。
外部システムの wire 型は、外部システムのファイルの中だけに置く。
domain と record の写像は store ファイル内に、domain と wire 型の写像は外部システムのファイル内に置く。
domain、application、composition は、record 型と外部システムの wire 型を参照しない。
論理の型と名前で区別する。
型名の接尾辞の規約は [tools](../../tools/) が定める。
型の分離は [concerns/types](../../concerns/types/README.md) に従う。
