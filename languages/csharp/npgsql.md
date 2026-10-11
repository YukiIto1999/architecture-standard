# Npgsql

用途は、PostgreSQL へ接続し、transaction の確定と制約違反の判別を担う data provider である。
採用は、C# は Npgsql である。
判断基準は、composition が所有する transaction で確定点を一つにでき、一意制約違反を SqlState と違反した制約の名前で判別できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 書き込みパス

### 要求
composition が所有する UnitOfWork は Npgsql の transaction で実装し、store は受け取った transaction の中で書く。

### 根拠
store が transaction を握ると、業務判断と確定の制御が混ざり、複数の store をまたぐ一つの確定ができない。
composition が transaction を所有し store が受け取った transaction の中で書けば、確定点が一つに定まる。
一つの確定点に集めれば、現在情報の書き込み、必要な業務イベントの追記、公開する integration event の outbox 記録を、同一のパスで確定できる。

### 完了条件
UnitOfWork が、composition の所有する Npgsql の transaction で実装されている。
store が、受け取った transaction の中で書いている。
確定点が、一つである。

### 禁止事項
store が、transaction の begin・commit を所有すること。

### 行動
composition で transaction を begin し、store に渡して書かせ、composition で commit する。

### 例
組立点が transaction を所有し、現在情報の書き込みと、公開する integration event の outbox 記録を同じ経路で書いた後に一度だけ確定する。

```csharp
await using var connection = await _dataSource.OpenConnectionAsync();
await using var transaction = await connection.BeginTransactionAsync();
await orderStore.InsertAsync(connection, transaction, order);
await outbox.AddAsync(connection, transaction, new OrderPlaced(order.Id));
await transaction.CommitAsync();
```

## 冪等な要求の記録

### 要求
冪等な要求は、operation、actor scope、tenant、key を全て NOT NULL の列として持ち、その複合一意制約で競合を検出する。
認証済み要求は検証済み actor ID、匿名要求は session または client ごとの安定した opaque scope、system 要求は logical actor ごとの ID を actor scope に使う。
multi-tenant operation の認証済み要求は、認証境界で検証した tenant claim または membership、もしくは authorization で許可した tenant 選択から構築した `TenantId` を tenant scope に使う。
multi-tenant operation の匿名要求は、検証済みの host または route と、session または client の tenant context から構築した `TenantId` を tenant scope に使う。
multi-tenant operation の system 要求は、logical actor に設定した `TenantId` を tenant scope に使う。
single-tenant operation は、正準な single-tenant sentinel を tenant scope に使う。
tenant の概念を持たない operation は、正準な no-tenant sentinel を tenant scope に使う。
安定した scope のない匿名要求は、server 発行の全体で一意な key と発行時の proof だけを受け付け、proof を検証した要求者にだけ保存済み response を返す。
request fingerprint と初回 response は、冪等 key と業務の書き込みと同じ Npgsql transaction で保存する。
同じ scope と key の再実行は、fingerprint が一致する場合だけ保存済み response を返し、不一致なら conflict を返す。

### 根拠
[transaction](../../concerns/transaction/README.md) が定める複合 scope と同じ確定点を PostgreSQL の制約と Npgsql transaction に写せば、同時要求の競合と部分確定を DB で止められる。
actor scope を検索条件へ含めれば、別の主体へ保存済み response を返さない。
actor の種別ごとに [transaction](../../concerns/transaction/README.md) の scope を写せば、匿名や system を汎用 sentinel へ潰さない。
tenant の出所を認証、認可、host、route、logical actor の検証済み context に限れば、要求者が指定した未検証 tenant へ scope を切り替えられない。

### 完了条件
operation、actor scope、tenant、key の全列が NOT NULL で、複合一意制約を持っている。
認証済み actor、匿名の安定した opaque scope、logical system actor が actor の種別に応じて記録されている。
multi-tenant operation に、認証済み tenant、匿名の検証済み host または route と session/client tenant context、logical system actor の設定済み tenant が `TenantId` として記録されている。
single-tenant operation に、正準な single-tenant sentinel が記録されている。
tenant の概念を持たない operation に、正準な no-tenant sentinel が記録されている。
安定した匿名 scope がない場合に、server 発行の全体で一意な key と proof が使われ、proof のない別 client へ保存済み response が返らないことが漏洩テストで検証されている。
request fingerprint、初回 response、業務の書き込みが、同じ Npgsql transaction で確定している。
同じ scope と key の同時要求が一件だけ業務を書き、異なる fingerprint が conflict になっている。
別の actor scope から保存済み response を取得できないことが、漏洩テストで検証されている。

### 禁止事項
冪等 key の競合を、Dapper の事前 SELECT だけで判定すること。
request fingerprint または初回 response を、業務の書き込みと別に commit すること。
actor scope を照合せずに、保存済み response を返すこと。
匿名または system の異なる主体を、汎用の actor sentinel へまとめること。
未検証の tenant claim、host、route、session、client 入力から `TenantId` を構築すること。
multi-tenant operation に single-tenant sentinel または no-tenant sentinel を使うこと。
single-tenant operation に `TenantId` または no-tenant sentinel を使うこと。
tenant の概念を持たない operation に `TenantId` または single-tenant sentinel を使うこと。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せず、安定した scope のない匿名要求の保存済み response を返すこと。

### 行動
`applied_requests` に複合一意制約を置き、Npgsql の同じ transaction で業務の書き込み、fingerprint、response を保存する。
認証済み actor ID、匿名の安定した opaque scope、logical system actor ID を種別ごとに記録する。
multi-tenant operation の認証済み要求は検証済み tenant claim、membership、または authorization 済み選択から `TenantId` を構築する。
multi-tenant operation の匿名要求は検証済み host または route と session/client tenant context から、system 要求は logical actor の設定から `TenantId` を構築する。
single-tenant operation に正準な single-tenant sentinel を使う。
tenant の概念を持たない operation に正準な no-tenant sentinel を使う。
安定した匿名 scope がなければ、server 発行の全体で一意な key と proof を発行し、proof を応答取得時に検証する。
同じ scope と key を並行に送る競合テストと、全 actor/tenant 種別の scope 分離、未検証 tenant の拒否、multi-tenant の `TenantId`、single-tenant sentinel、no-tenant sentinel の相互混同拒否、proof のない別 client からの response 取得拒否を確かめる漏洩テストを実行する。

## durable inbox

### 要求
受領した event は、consumer contract または subscription scope と event ID の複合一意制約を持つ durable inbox に記録する。
payload を durable inbox へ commit した後だけ、source へ upstream delivery ack を返す。
処理結果と inbox の処理済み記録は、同じ Npgsql transaction で確定する。
処理 item の inbox processing completion と削除は、transaction の commit が成功した後だけ行う。
inbox が容量上限に達した場合は、受領せず nack または再試行可能な失敗を返す。
inbox の使用量、上限、backlog、nack を監視へ出す。

### 根拠
payload の commit 前に upstream delivery ack を返さず、満杯を nack すれば、前段の停止で event を source から失わない。
処理結果と処理済み記録の commit 前に inbox processing completion を行わなければ、後段の停止で item を再処理できる。

### 完了条件
durable inbox が scope と event ID の複合一意制約を持っている。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
処理結果と処理済み記録が、同じ Npgsql transaction で確定している。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
payload commit の前後と処理結果 commit の前後で停止し、前段は source から再配送され、後段は inbox item が再処理され、結果が一度分になることが結合テストで検証されている。
容量上限で nack または再試行可能な失敗になることが結合テストで検証されている。
inbox の使用量、上限、backlog、nack が監視されている。

### 禁止事項
payload の durable inbox への commit より前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit より前に、inbox processing completion または処理 item の削除を行うこと。
容量上限を超えた event を受領済みとして捨てること。

### 行動
payload を durable inbox へ commit してから、upstream delivery ack を返す。
処理結果と処理済み記録を同じ Npgsql transaction で書き、commit 成功後に inbox processing completion を確定して処理 item を完了または削除する。
容量を予約できない場合は nack または再試行可能な失敗を返し、使用量、backlog、nack を記録する。
payload commit と処理結果 commit の各直前・直後の停止、および容量上限を再現する結合テストを実行する。

## 並行更新の表面

### 要求
同じ集約への同時の更新は [transaction](../../concerns/transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従って制御し、版で衝突を検出する集約、共有の鍵か鍵なしで更新する可変属性の行、一回だけ起きる業務事実を追記する集約では競合の Result に写す。
集約の鍵は、composition が所有する Npgsql transaction の中で、検証より前に、排他なら `pg_advisory_xact_lock(bigint)`、共有なら `pg_advisory_xact_lock_shared(bigint)` で取る。
集約の鍵の bigint は、集約の種類と集約の識別子から、種類の違う集約の鍵が衝突しないように一意に導き、その導出をコードの一か所に定義する。
一つの書き込みが複数の鍵を取る場合は、全ての書き込み経路で bigint の値の昇順に取る。
多数の鍵は、昇順に並べた bigint の配列を `unnest` で展開する一つの `SELECT` で取り、その文の中で並べ替えない。
鍵を取った後の検証の読み取りは、READ COMMITTED の transaction で行う。
datastore が付ける業務事実の活動の時刻の列は、既定値を `clock_timestamp()` にし、`CURRENT_TIMESTAMP`、`now()`、`statement_timestamp()` を既定値に使わない。
予定の始まりや終わりの到来と保持期限の経過を判定するビューは、判定の時点に `statement_timestamp()` を使い、`CURRENT_TIMESTAMP`、`now()`、`clock_timestamp()` を使わず、そのビューを読む文は鍵を取る文と別の命令で送る。
識別子を datastore が採番する列だけを持つ関係へは、識別子を指定せず `DEFAULT VALUES` で追記し、`OVERRIDING SYSTEM VALUE` を使わない。
datastore が付ける活動の時刻から規則で決まる業務事実の値(変更を適用する始まりの日など)は、その時刻の列から求める `GENERATED ALWAYS AS (...) STORED` の列に持ち、規則の改定では、改定より前の行が同じ値になる式へ移行の `ALTER COLUMN ... SET EXPRESSION` で置き換える。
版で衝突を検出し、正本が可変属性の行である集約では、`UPDATE` の `WHERE` で期待する version を比較して同じ文で version を進め、影響行数が 0 のときを競合とする。
共有の鍵か鍵なしで更新する可変属性の行は、同じ行への同時の更新を、`UPDATE` の `WHERE` で期待する version を比較して同じ文で version を進めて検出し、影響行数が 0 のときを競合とする。
版で衝突を検出し、正本が追記する事実の関係である集約では、名前を付けた `(集約の識別子, version)` の一意制約の違反だけを競合とし、他の制約違反は競合に写さない。
一回だけ起きる業務事実を追記する集約では、一回だけであることを守る主キーに名前を付け、その名前付きの主キーの違反だけを競合とし、他の制約違反は競合に写さない。
版で競合を検出する集約へ書く全ての書き込み経路は、正本に応じた同じ検出を通す。
必要な業務事実は、現在情報の書き込みと同じ Npgsql transaction で追記する。
業務事実を必要としない現在情報の更新は、集約に定めた競合制御を通し、業務事実を追記せず `UPDATE` で書いてよい。
競合または失敗のとき、composition は transaction を commit せず、現在情報の更新、業務事実の追記、outbox の記録のどれも残さない。
公開する integration event は、業務事実の追記と別に、現在情報の書き込みと同じ transaction で outbox へ記録する。

### 根拠
同時の更新を検出しなければ、後の書き込みが前の更新を黙って失わせる。
version を `WHERE` で比較して同じ文で進める楽観的ロックなら、同じ version を期待する二つの更新のうち片方だけが行を更新し、他方は影響行数 0 になる。
Dapper の `ExecuteAsync` は影響行数を返すので、0 を競合と判別できる。
共有の鍵は同じ行への同時の更新を直列にしないので、共有の鍵か鍵なしで更新する可変属性の行は、version の比較で片方だけが行を更新し、他方は影響行数 0 になる。
正本が追記する事実の関係なら、`(集約の識別子, version)` に一意制約を課すと、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
一回だけ起きる業務事実の関係は、[persistence](../../concerns/persistence/fact-state-time-relations.md) の「事実・状態・時間を別の関係に落とす」に従って対象のキーを主キーにするので、二度目の追記は主キーの違反になる。
一意制約違反は冪等 key や重複を許さない値の制約でも起きるので、違反の種類だけで競合と判定すると、version や一回だけであることを守る主キー以外の違反を競合へ誤って写す。
Npgsql は制約違反を `PostgresException` で送出し、`SqlState` が `PostgresErrorCodes.UniqueViolation` のとき一意制約違反と判別できる。
`PostgresException.ConstraintName` は違反した制約の名前を返すので、version の制約や主キーに付けた名前と照合すれば競合だけを識別できる。
どちらで検出するかは正本が何かで決まるので、書き込みごとに選ばない。
`pg_advisory_xact_lock(bigint)` と `pg_advisory_xact_lock_shared(bigint)` は、表の行でなく bigint の値に鍵を掛けるので、書き込み経路が更新してはならない事実の行への更新権限なしに集約の鍵を取れる。
`SELECT ... FOR UPDATE` などの行ロック句は対象の行への `UPDATE` 権限を要するので、事実の行に使うと、鍵のために書き込み経路へ事実の行の更新権限を与えることになる。
`pg_advisory_xact_lock` 系の鍵は transaction の終了で自動的に解放されるので、composition の commit または破棄が解放点になり、store は解放を持たない。
READ COMMITTED は文ごとに直前の確定を読むので、鍵を待った後の検証の文は、先に鍵を持っていた書き込みの確定を読める。
REPEATABLE READ 以上は最初の文の snapshot を使い続けるので、鍵を待つ間に確定した書き込みを検証で読めない。
鍵を bigint の値の昇順に取れば、鍵どうしの待ちが循環せず、デッドロックが起きない。
種類の違う集約の鍵の値が衝突すると、無関係な集約が同じ鍵を取って互いを待たせるので、鍵の値は種類と識別子から一意に導く。
識別子の範囲を下位の bit に収まる範囲に限れば、識別子が種類の bit へ溢れて別の種類の鍵と重ならない。
導出を一か所に定義すれば、全ての書き込み経路が同じ集約に同じ値の鍵を取り、昇順の全順序も一つの値の空間で定まる。
業務事実の時刻を datastore の既定値で付ける理由は、[persistence](../../concerns/persistence/append-only-facts.md) の「業務事実を保持期間の間は追記で残す」に従う。
`CURRENT_TIMESTAMP` と `now()` は transaction の開始時刻に固定されるので、集約の鍵を待った transaction は、待つ間に確定した業務事実より前の時刻を付ける。
`clock_timestamp()` は評価した時点の時刻を返すので、鍵の後に追記した行の時刻が、先に確定した行の時刻以後になる。
`statement_timestamp()` は client から最後の命令を受け取った時刻を返すので、鍵を取る文と同じ一つの命令で送った文では、鍵を待つ前の時刻を付ける。
書き込み経路は datastore が付ける時刻を知らず、時刻の列への書き込み権限も持たないので、その時刻から決まる値は datastore が同じ行の中で求める。
`clock_timestamp()` は volatile なので、それを出力に持つビューは結合の中で展開されず、結合の条件で索引を使えないため、判定が相手の関係を全件読む。
`statement_timestamp()` は一つの文の中で同じ値を返し、鍵を取る文と別の命令で送った文では、鍵を待った後の時刻になる。
識別子を datastore が採番する列だけを持つ関係に追記するには識別子の列への `INSERT` 権限が要り、その権限は `OVERRIDING SYSTEM VALUE` による識別子の指定を拒まないので、指定しないことを書き込み経路が守る。
業務事実が必要かどうかは [data](../../principles/data/preserve-facts-and-current-state.md) の「業務事実と現在情報を分けて保持する」に従う。
プロフィールの表示名や企業名のような可変属性は、業務事実を必要としない限り、`UPDATE` で更新してよい。
現在情報の更新と必要な業務事実の追記を同じ transaction で確定すれば、片方だけが確定して現在情報と事実が食い違うことがない。
競合や失敗で commit しなければ、競合した更新の書き込みは現在情報にも業務事実にも outbox にも残らない。
業務事実は集約の内側で起きた事実であり、コンテキストの外へ公開する integration event の outbox 記録とは別なので、一方を他方の代わりにしない。
domain event と integration event の区別は [messaging](../../concerns/messaging/domain-integration-events.md) に従う。
影響行数 0 と制約違反を競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
版で衝突を検出し、正本が可変属性の行である集約で、同じ version を期待する並行更新の片方だけが確定し、他方が競合の Result で返されている。
共有の鍵か鍵なしで更新する可変属性の行で、同じ version を期待する同じ行への並行更新の片方だけが確定し、他方が競合の Result で返されている。
版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行で、条件付き `UPDATE` の影響行数 0 が、競合の Result に写されている。
版で衝突を検出し、正本が追記する事実の関係である集約で、同じ version の重複追記が、名前を付けた `(集約の識別子, version)` の一意制約の違反として検出され、競合の Result で返されている。
一回だけ起きる業務事実の二度目の追記が、名前を付けた主キーの違反として検出され、競合の Result で返されている。
version の制約と一回だけであることを守る主キー以外の制約違反が、競合の Result に写されていない。
版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行の全ての書き込み経路で、古い version を期待した更新が競合になり、現在情報が変わっていない。
集約の鍵を取る全ての書き込みが、composition が所有する Npgsql transaction の中で、検証より前に、排他は `pg_advisory_xact_lock(bigint)`、共有は `pg_advisory_xact_lock_shared(bigint)` で鍵を取っている。
複数の鍵を取る書き込みが、全ての書き込み経路で bigint の値の昇順に鍵を取っている。
集約の鍵の bigint が、集約の種類と識別子から一意に導かれ、種類の違う集約の鍵が衝突せず、識別子が下位の bit の範囲に収まらないとき導出が鍵を作らず、導出がコードの一か所にだけ定義されている。
鍵を取った後の検証が READ COMMITTED で行われ、鍵を待つ間に確定した書き込みを読んでいる。
書き込み経路の role が、事実の行への `UPDATE` と `DELETE` の権限を持たないまま集約の鍵を取り、事実の行に `SELECT ... FOR UPDATE` を使っていない。
datastore が付ける業務事実の時刻の列の既定値が `clock_timestamp()` であり、鍵を待った書き込みが付けた時刻が、待つ間に確定した業務事実の時刻以後である。
予定の到来と保持期限の経過を判定するビューが `statement_timestamp()` を使い、そのビューを読む文が鍵を取る文と別の命令で送られている。
識別子を datastore が採番する列だけを持つ関係への追記が、識別子を指定していない。
必要な業務事実を伴う更新で、現在情報の更新と業務事実の追記が、同じ Npgsql transaction で確定している。
競合または失敗した更新が、現在情報の更新も業務事実の追記も outbox の記録も残していない。
業務事実を必要としない現在情報の更新が、集約に定めた競合制御を通し、業務事実の追記なしで `UPDATE` により書かれている。
公開する integration event の outbox への記録が、業務事実の追記と別に、現在情報の書き込みと同じ transaction で行われている。

### 禁止事項
集約に定めた競合制御を通さず、同時の更新を上書きすること。
版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行で、条件付き `UPDATE` の影響行数 0 を、競合として扱わず成功にすること。
共有の鍵か鍵なしで更新する可変属性の行を、version の比較なしで更新すること。
必要な業務事実を、事実を追記しない現在情報の `UPDATE` だけで表すこと。
事実の行から導ける今の状態を状態の列として持ち `UPDATE` で書く禁止は、[data](../../principles/data/derive-state-from-facts.md) の「今の状態を事実の行から導く」に従う。
現在情報の更新と必要な業務事実の追記を、別々の transaction で確定すること。
競合または失敗した更新の、現在情報の更新、業務事実の追記、outbox の記録の一部だけを commit すること。
version の制約と一回だけであることを守る主キー以外の制約違反を、競合の Result に写すこと。
outbox への integration event の記録を、必要な業務事実の追記の代わりにすること。
集約の鍵を、事実の行への `SELECT ... FOR UPDATE` などの行ロックで取ること。
鍵を取るためだけに、事実の行への更新権限を書き込み経路の role に与えること。
複数の鍵を、bigint の値の昇順以外の順序で取ること。
集約の鍵の bigint を、集約の種類を含めずに識別子だけから導くこと。
集約の鍵の導出を、書き込み経路ごとに書き写すこと。
集約の鍵で競合制御する集約で、鍵を取る前に読んだ状態や、REPEATABLE READ 以上の snapshot を根拠に、検証して確定すること。
datastore が付ける業務事実の時刻の列の既定値に、`CURRENT_TIMESTAMP`、`now()`、`statement_timestamp()` を使うこと。

### 行動
上位の書き込みパスに従って集約の競合制御を確認し、版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行に、正本に応じた version の比較を実装する。
集約の鍵を取る書き込みは、composition が所有する Npgsql transaction の中で、検証より前に、排他なら `SELECT pg_advisory_xact_lock(@AggregateKey)`、共有なら `SELECT pg_advisory_xact_lock_shared(@AggregateKey)` を `ExecuteAsync` で実行する。
複数の鍵を取る書き込みは、bigint の値の昇順に並べてから取る。
集約の鍵の bigint は、固定の上位の bit に種類を、範囲を限った下位の bit に識別子を置いて導き、その導出を一つの関数に定義して全ての書き込み経路から呼ぶ。
集約の鍵で競合制御する集約では、鍵を取った後に、READ COMMITTED の文で今の状態を検証してから書く。
事実の行に `SELECT ... FOR UPDATE` を使わず、書き込み経路の role に事実の行への `UPDATE` と `DELETE` の権限を与えない。
版で衝突を検出する集約の可変属性の行と、共有の鍵か鍵なしで更新する可変属性の行は、`SET` で `version = version + 1` に進め、`WHERE` に `version = @ExpectedVersion` を含む `UPDATE` で書き、`ExecuteAsync` の戻り値が 0 なら `WriteError.Conflict` を返す。
版で衝突を検出する事実の関係は、`(集約の識別子, version)` に名前を付けた一意制約を置き、`PostgresException` の `SqlState` が `PostgresErrorCodes.UniqueViolation` で `ConstraintName` がその名前と一致するときだけ `WriteError.Conflict` を返し、他の制約違反は競合に写さない。
一回だけ起きる業務事実の関係は、対象のキーを主キーにして主キーに名前を付け、`PostgresException` の `SqlState` が `PostgresErrorCodes.UniqueViolation` で `ConstraintName` がその名前と一致するときだけ `WriteError.Conflict` を返し、他の制約違反は競合に写さない。
datastore が付ける業務事実の時刻の列は `DEFAULT clock_timestamp()` で定義し、鍵を待った書き込みの時刻が待つ間に確定した業務事実の時刻以後になることを結合テストで確認する。
更新ごとに必要な業務事実を確かめ、必要なら同じ transaction の中で業務事実の関係へ INSERT する。
競合または失敗では、composition が transaction を commit せず破棄する。
版で衝突を検出する集約では、同じ version の並行更新、古い version の各経路からの更新、version 以外の一意制約違反を結合テストで再現する。
集約の鍵を排他で取る集約では、全経路での直列化と鍵の後の検証、書き込み経路の role が事実の行へ `UPDATE` も `DELETE` もできないこと、複数の鍵を一つの順序で取ること、種類の違う集約の鍵が衝突しないこと、一回だけ起きる業務事実の二度目の追記で名前付きの主キーの違反だけが競合に写ることを結合テストで確認し、排他の鍵の下で更新する判定の対象の行への version の追加は要求しない。
共有の鍵か鍵なしで更新する可変属性の行では、同じ行への同時の更新を結合テストで再現し、片方だけが確定して他方が競合になることを確認する。
現在情報の更新と業務事実の追記の間の失敗は、どちらの集約でも再現する。

### 例
競合は、閉じた型付き失敗で表す。

```csharp
public abstract record WriteError
{
    private WriteError() { }

    public sealed record Conflict : WriteError;
}
```

プロフィールの表示名は `user_profiles(user_id, display_name, version)` に置く可変属性である。
プロフィールの更新は利用者の集約の鍵を共有で取り、同じ行への同時の更新をその行の version で検出する。
次の断片は、`WHERE` で期待する version を比較して同じ文で version を進め、影響行数 0 を競合へ写す。

```csharp
var updated = await connection.ExecuteAsync(
    "UPDATE user_profiles SET display_name = @DisplayName, version = version + 1 WHERE user_id = @UserId AND version = @ExpectedVersion",
    new { DisplayName = displayName, UserId = id, ExpectedVersion = expectedVersion },
    transaction
);
return updated == 0
    ? Result.Failure<UserProfile, WriteError>(new WriteError.Conflict())
    : Result.Success<UserProfile, WriteError>(profile);
```

取消の時刻と理由を残す義務があるとき、`orders` の `status` 列を `UPDATE` して取消を表すと、取消の事実が欠落し、取消済みかを事実の行と別の列で二重に持つ。

```csharp
await connection.ExecuteAsync(
    "UPDATE orders SET status = 'cancelled' WHERE id = @OrderId",
    new { OrderId = id },
    transaction
);
return Result.Success<Order, WriteError>(order);
```

状態の列を置かず、取消を `order_cancellations(order_id PRIMARY KEY, reason_code)` への追記で表す。
取消は注文を参照する一回だけ起きる業務事実であり、注文の集約の他の書き込みと直列に確定させるので、注文の集約の鍵を `pg_advisory_xact_lock` で排他に取ってから追記する。
`occurred_at` は `DEFAULT clock_timestamp()` の列の既定値で付き、書き込み経路は渡さない。
二度目の取消は名前を付けた主キー `order_cancellations_pkey` の違反になり、違反した制約の名前が一致するときだけ競合へ写す。
競合の Result を受けた composition は commit せず transaction を破棄するので、取消は残らず、鍵も transaction の終了で解放される。

```csharp
const string OrderCancellationConstraint = "order_cancellations_pkey";

await connection.ExecuteAsync(
    "SELECT pg_advisory_xact_lock(@AggregateKey)",
    new { AggregateKey = orderKey },
    transaction
);
try
{
    await connection.ExecuteAsync(
        "INSERT INTO order_cancellations (order_id, reason_code) VALUES (@OrderId, @ReasonCode)",
        new { OrderId = id, ReasonCode = reasonCode },
        transaction
    );
    return Result.Success<Order, WriteError>(order);
}
catch (PostgresException exception)
    when (exception.SqlState == PostgresErrorCodes.UniqueViolation
        && exception.ConstraintName == OrderCancellationConstraint)
{
    return Result.Failure<Order, WriteError>(new WriteError.Conflict());
}
```

正本が追記する事実の関係で、一意制約違反をすべて競合へ写すと、`(account_id, version)` 以外の一意制約の違反まで競合として返される。

```csharp
try
{
    await connection.ExecuteAsync(
        "INSERT INTO ledger_entries (account_id, version, amount) VALUES (@AccountId, @Version, @Amount)",
        new { AccountId = id, Version = expectedVersion + 1, Amount = amount },
        transaction
    );
    return Result.Success<Account, WriteError>(account);
}
catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
{
    return Result.Failure<Account, WriteError>(new WriteError.Conflict());
}
```

名前を付けた `(account_id, version)` の一意制約と、違反した制約の名前が一致するときだけ競合へ写し、他の制約違反は `when` で捕捉せず競合に写さない。

```csharp
const string LedgerVersionConstraint = "ledger_entries_account_id_version_key";

try
{
    await connection.ExecuteAsync(
        "INSERT INTO ledger_entries (account_id, version, amount) VALUES (@AccountId, @Version, @Amount)",
        new { AccountId = id, Version = expectedVersion + 1, Amount = amount },
        transaction
    );
    return Result.Success<Account, WriteError>(account);
}
catch (PostgresException exception)
    when (exception.SqlState == PostgresErrorCodes.UniqueViolation
        && exception.ConstraintName == LedgerVersionConstraint)
{
    return Result.Failure<Account, WriteError>(new WriteError.Conflict());
}
```
