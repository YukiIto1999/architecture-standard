# infrastructure 層

infrastructure 層は、外部の I/O に接続し、port の実装を収める層である。
外部システムへの接続と副作用の実装は、この層だけに置く。
infrastructure は [layout](./layout.md) の単位と依存に従う。

## adapter

adapter は、application の port を実装する。
adapter は、core の側では application の port と domain、および shared と submodule の公開面のみに依存する。
submodule の adapter は、shared を参照せず、下位の submodule の公開面を用いる。
adapter は、use-case を参照しない。
adapter の実装型は、配線する composition のみが参照する。
adapter の名前は、実装の方式を表す語で付ける。
DB driver、HTTP client、ファイルシステム、現在時刻の取得、乱数生成、外部 SDK は、この層でのみ用いる。
キャッシュは、cache-aside の adapter として置く。
キャッシュと一時データの store の採用は [concerns/persistence](../../concerns/persistence.md) に従う。
流入の制限は surface 側の境界に置き、置き場は [skeleton](../skeleton.md) に従う。
core から外部システムへの呼び出しの制限に使うカウンタは、この層で一時データの store に置く。
キャッシュの項目は、期限で失効させる。
期限切れの項目は、古い値を返しながら背後で更新する形で延命できる。
延命の採否は、project が ADR に記録する。
更新は、対象を特定して無効化する。
CDN と edge の cache は、HTTP の配送の cache に限る。
アプリの状態や一時データの store として使わない。
副作用と非同期の境界の規律は [concerns/effect](../../concerns/effect.md) と [concerns/concurrency](../../concerns/concurrency.md) に従う。

## 永続化

永続化は、集約を store を通じて読み書きする。
datastore は、事実の正本である。
datastore の採用と、次の設計は [concerns/persistence](../../concerns/persistence.md) に従う。

- 事実・状態・時間の関係への落とし方
- 追記による現在状態の導出と、区切りによる有界化
- 正規化と制約
- JSON 列の判断

事実の正本はイベントの表の集まりであり、projection は読み取りのための畳み込みである。
projection は1エンティティに1表とし、名前は `<エンティティ>_current` とする。
イベントの表の名前は出来事の名詞とし、情報・データ・履歴・管理・マスタ・記録という語を使わない。
並行更新は projection の version 列への compare-and-set で検出し、確定点と版の衝突の規律は [concerns/transaction](../../concerns/transaction.md) に従う。
store は record 型を定義し、domain と record の写像を持つ。
store は、型付きの SQL を発行する薄い adapter として書く。
イベントの追記・projection の更新・outbox への記録を束ねる書き込みパスの境界の所有は、[composition](./composition.md) が持つ。
outbox は単一の表であり、事実を識別子で参照して本体を複製しない。
読み取りは projection から行う。
計測の後に、性能は、index の整備・N+1 の除去・connection pool の調整の順で改善する。
検索・全文・分析のように、正本のイベントから再構築できる二次の読みモデルは、派生読みモデルとして別の engine に置いてよい。
技術の submodule の索引も、この派生読みモデルである。
派生読みモデルの engine の単一採用は、project が ADR に明記する。
派生読みモデルは projection の表の規律の対象外とし、事実の正本にせず、失っても正本から作り直せる形に保つ。
派生読みモデルの再構築は、正本のイベントを順に port へ流す operation として composition に置く。
起動は operation を呼べる surface の layout に従う。
派生読みモデルの規律は [concerns/persistence](../../concerns/persistence.md) に従う。
スキーマの変更は forward-only の migration で行い、配備の独立した手順で適用する。
消去の義務を負う個人データは、消せるように設計する。
消去は専用の管理操作で対象の列を消し、消去の事実をイベントとして残す。
バックアップには保持の期限を定め、消去の義務を期限で満たす。

## 外部システム

外部システムへの接続は、client と adapter を持つ。
外部システムの wire 型と、domain との写像は、外部システムのファイル内に置く。
認可の判定の adapter は、認可の engine を呼ぶ。
権限のモデルは、役割・関係・属性の宣言的な組み合わせで表す。
認可の engine は OpenFGA である。
判定の cache と engine の datastore の採用は [concerns/persistence](../../concerns/persistence.md) に従う。
認可のモデルと判定の規律は [concerns/authorization](../../concerns/authorization.md) に従う。

## 論理と物理の分離

record 型は、`persistence/` の中だけに置く。
外部システムの wire 型は、外部システムのファイルの中だけに置く。
domain と record の写像は store ファイル内に、domain と wire 型の写像は外部システムのファイル内に置く。
domain、application、composition は、record 型と外部システムの wire 型を参照しない。
論理の型と名前で区別する。

- record の型名には Record を付ける
- wire の型名には Request・Response を付ける
- 写像には Mapper を付ける

型の分離は [concerns/types](../../concerns/types.md) に従う。
