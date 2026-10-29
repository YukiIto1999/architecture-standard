# sqlx-cli

用途は、schema を変更する forward-only の SQL script を、履歴順に一度だけ、アプリの配備から独立して適用する道具である。
採用は、Rust は sqlx-cli である。
判断基準は、migration を言語の class に包まず SQL script のまま扱い、適用済みの one-time script を再実行せず、独立した CLI から非対話で実行できることである。
Cargo.lock を追跡しない sqlx の構成と整合し、`cargo install --locked sqlx-cli` に依存しないことを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、PostgreSQL 対応の終了、one-time script の実行規則の変化を再評価のトリガーとする。

## migration の適用

### 要求
schema migration の artifact の所有と forward-only の適用は [structure/core/infrastructure](../../structure/core/infrastructure.md) の「永続化」に従う。
コンテキストと採用依存の独立した集合ごとに source、対象 DB、適用履歴表、設定を対応づけ、同じ DB に置く別の集合の履歴表を分離する。
履歴表を別の集合と共有しなければ、既定の表を使ってよい。
同じ集合の適用に CLI と library または `migrate!` の両方を使う場合は、source、履歴表、作成する schema と設定を揃え、採用版がその設定を反映することを確かめる。
`sqlx.toml` の library 側の有効化は [sqlx](./sqlx.md) の「型付き SQL」に従い、migration hash の無視文字は既定から変更しない。
適用は sqlx-cli または採用依存が公開する migration API を配備の task から実行し、起動から分離する順序は [process/release](../../process/release.md) に従う。
CLI を使う経路では source と設定も配備 artifact として届け、稼働先の Cargo cache を暗黙の入力にしない。
既存の履歴表や集合の所属の移設は [process/migration](../../process/migration.md) に従い、空の履歴からの再実行に置き換えない。

### 根拠
sqlx の migrator は適用済みの版と checksum を自分の source に照合し、版が source に欠ける場合と、同じ版の checksum が異なる場合を拒否する。
履歴表だけを空の表へ変更すると、適用済みの SQL が未適用として再実行される。
履歴を集合ごとに分け、CLI と library の設定を揃えれば、集合ごとの適用済み記録と source を対応づけたまま検証できる。
既存の migration があると、既定の `migrate add` はその型に従うため、forward-only の artifact の生成には `--simple` を明示する。
履歴表の分離は、migration の SQL が触れる DB object と必要な権限の分離を意味しない。

### 完了条件
同じ DB の独立した集合を適用しても履歴が混ざらず、同じ source と設定の再適用で既存の schema と data が変わらないことを実行テストで確かめている。
同じ集合に CLI と library または `migrate!` を使う場合に、両方の経路が同じ履歴表へ収束することを実 DB で確かめている。
適用済みの SQL の checksum の不一致と、自分の集合に欠けた適用済みの版が、履歴を分離した後も拒否される。
履歴を移設した場合に、元の適用済み記録と既存の schema、data が保存され、適用済みの SQL が再実行されていない。

### 禁止事項
同じ DB にあるという理由だけで、独立した集合へ同じ履歴表を割り当てること。
集合の不一致を隠すために、`ignore_missing` を有効化したり、checksum の照合を弱めたりすること。
衝突を避けるために、依存が所有する migration の原本を改番し、アプリケーションの集合へ混ぜること。
履歴の移設を、新しい空の履歴表への切り替えで済ませること。
集合の衝突を消すために、適用済みの版や checksum を書き換えること。

### 行動
各集合の source、DB、履歴表と設定を配備の入力として宣言し、複数の集合を同じ DB へ適用する場合は履歴表を分ける。
CLI には集合の directory を `--source` で渡し、設定 file を使う場合はその file を `--config` で明示する。
アプリケーションの変更は、所有するコンテキストの artifact として `sqlx migrate add --simple` で作り、`sqlx migrate run` で適用する。
依存の公開 migration API を使う場合も、元の集合と設定を維持して配備の task から呼び、アプリケーションの起動経路からは呼ばない。
同じ集合を CLI と library の両方で適用する構成では、一方で適用して他方で再適用し、履歴と既存の data が変わらないことを確かめる。
履歴表や集合の所属を変える前に、元の版と checksum の対応を保存し、移設後の実 DB で適用済みの SQL が再実行されないことを確かめる。

