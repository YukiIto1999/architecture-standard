# sqlx

用途は、SQL を型で扱いながら書く永続化アクセス層である。
採用は、Rust は sqlx である。
判断基準は、SQL を隠さず、事実の形がそのまま型に写ることである。フル ORM は SQL を不透明にしたり、変更追跡で確定の時点を暗黙にしたりするため採らない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 型付き SQL

### 要求
永続化は sqlx で書き、`query!`・`query_as!` のコンパイル時検証を使う。
sqlx の `offline` feature を有効化し、リポジトリの検証入口は offline の検証データで検証する。
`sqlx.toml` を使う場合は sqlx 側で `sqlx-toml` feature を明示的に有効化し、migration table 名と migration hash の無視文字は既定から変更しない。

### 根拠
sqlx はコンパイル時に開発の DB へ接続し、SQL を DB 自身に検証させる。
SQL を隠す抽象を入れないので、事実の形がそのまま型に写る。
sqlx の `offline` feature を有効化して offline の検証データをリポジトリの検証入口で照合すれば、スキーマと SQL のずれがビルドで止まる。
sqlx-cli の `sqlx migrate add` は既定で forward-only の migration ファイルを生成し、`sqlx migrate run` が適用済みの履歴を DB 側で追跡する。
`sqlx.toml` の migration table 名と migration hash の無視文字を既定から変えなければ、sqlx と sqlx-cli の設定差で検証対象と適用履歴がずれない。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が sqlx で書かれ、`query!`・`query_as!` のコンパイル時検証が効いている。
sqlx の `offline` feature が有効で、リポジトリの検証入口が offline の検証データで検証している。
`sqlx.toml` を使う場合は sqlx 側で `sqlx-toml` feature が有効で、migration table 名と migration hash の無視文字が既定から変更されていない。
フル ORM を使っていない。
schema の変更が、sqlx-cli の `sqlx migrate` で forward-only の migration として適用されている。

### 禁止事項
フル ORM で、SQL を隠すこと。
SQL の値を、文字列の連結で組み立てること。

### 行動
SQL を `query!`・`query_as!` で書き、sqlx の `offline` feature を有効化して、`cargo sqlx prepare` の検証データをリポジトリの検証入口で照合する。
`sqlx.toml` を使う場合は sqlx 側で `sqlx-toml` feature を明示的に有効化し、migration table 名と migration hash の無視文字を既定から変更しない。
schema の変更は `sqlx migrate add` で migration ファイルを作り、`sqlx migrate run` で適用する。

### 例
SQL を文字列で組み立てると型と schema が検査されず、値の連結は injection を招く。

```rust
let sql = format!("SELECT * FROM user_profiles WHERE user_id = '{user_id}'");
```

`query_as!` なら schema と型をコンパイル時に検証し、値を parameter で渡せる。

```rust
let profile = sqlx::query_as!(
    UserProfileRecord,
    "SELECT user_id, display_name, version FROM user_profiles WHERE user_id = $1",
    user_id,
)
.fetch_one(&pool)
.await?;
```

## 書き込みパス

### 要求
transaction の制御の所有は、[transaction](../../concerns/transaction/application-owned-transactions.md) の「トランザクションの制御を application に置く」に従う。
application が宣言した scope の port を、infrastructure が sqlx の Transaction を内側に持つ型で実装し、use-case が begin、読み、書き込み、commit、abort をその port を通して制御する。
sqlx の Transaction と `sqlx::Error` は、application・domain・composition の型とシグネチャに現さず、scope の実装の内側に閉じる。
scope の操作の失敗は、use-case が分岐に使う分類の閉じた型で表し、`sqlx::Error` の値と文字列を載せない。
sqlx の生の診断情報は、infrastructure が [observability](../../concerns/observability/README.md) の境界の殻で扱う。
store は、scope が持つ Transaction の中で書き、begin・commit・rollback を呼ばない。
scope の `commit` と `abort` は `self` を消費し、確定または中止の後に scope を使えない形にする。
`Connection::transaction` のような closure を受ける API へ use-case の本体を渡し、外側に begin と commit を持たせない。
commit は、`Ok` を返したときだけ確定とする。
commit の失敗は、実装が確定していないと確認できる場合だけ `NotCommitted` に、確認できない場合は `OutcomeUnknown` に写す。
`sqlx::Error::Database` であることだけでは、確定していないと判断しない。
開始済みの commit は、drop で中断せず完了まで await する。
use-case は、commit を始める前に終わるとき、`abort` を await して scope を中止し、元の終わりと `abort` の失敗を別々に返す。
欠陥と取り消しで scope が drop されたときの rollback は sqlx が行うが、その完了は await できないので、協調取消では use-case が `abort` を [tokio-util](./tokio-util.md) の「取り消し」が定める取り消されない後始末として await して完了させる。

### 根拠
store が Transaction を握ると、use-case の書き込みが複数の確定点に割れ、複数の store をまたぐ一つの確定ができない。
begin から commit または abort までを use-case が書けば、読み、domain の判断、書き込み、確定か中止かの順が use-case で読め、domain は Transaction を知らない純粋な関数のまま保てる。
Transaction を scope の実装の内側に閉じれば、application と domain が sqlx の型に依存しない。
`sqlx::Error` を業務の失敗へ文字列化すると、分類に必要な型情報が失われ、接続情報などの機微な値が漏れる恐れがある。
`commit` と `rollback` は `self` を消費するので、確定または中止の後の scope の再利用が型検査で止まり、commit が `Ok` を返した後に scope を使う後始末が残らない。
closure を受ける API に use-case の本体を渡すと、外側の呼び出しが全体を包み、読み、判断、書き込み、確定の順と確定しない終わり方が use-case から見えなくなる。
commit も rollback もされずに drop された Transaction は、sqlx が rollback する。
drop は非同期の rollback の完了を待てないので、取り消された後に rollback を済ませる経路では、`abort` を await する。
開始済みの commit を drop すると、確定したかが分からない状態を自ら作る。
commit の `Ok` の応答は確定を示すが、失敗の `sqlx::Error` の種類だけでは確定していないとは限らない。
確定していないと確認できない失敗を未確定へ写せば、確定済みの書き込みを書かれていないものとして扱う恐れがある。
成功にも未確定にも取り消しにも写さなければ、再実行か調査で判定できる。
`abort` の失敗で元の終わりを上書きすると、拒否や競合の理由が呼び出し側から消える。
一つの確定点に集めれば、現在情報の書き込み、必要な業務イベントの追記、公開する integration event の outbox 記録を、同一のパスで確定できる。

### 完了条件
scope の port が application に宣言され、sqlx の Transaction と `sqlx::Error` が infrastructure の scope の実装の内側にだけある。
use-case が、scope の port を通して begin、読み、domain の判断、書き込み、commit または abort を制御している。
domain・application・composition の型とシグネチャに、sqlx の型が現れていない。
scope の操作の失敗が、分類の閉じた型で返り、`sqlx::Error` の値と文字列を含んでいない。
store が、begin・commit・rollback を呼んでいない。
`Connection::transaction` のような closure に use-case の本体を渡す controller が、どの層にもない。
確定点が、一つである。
commit を始める前に終わる拒否、競合、失敗、欠陥、取り消しで、現在情報の更新も業務事実の追記も outbox の記録も確定していない。
`abort` に失敗を注入すると、元の終わりが保たれ、`abort` の失敗が別に返されている。
commit が `Ok` を返したときだけ確定として返り、未確定を確認できない失敗が `OutcomeUnknown` になっている。
commit の応答を受け取る前に接続を切る失敗注入で、`OutcomeUnknown` が成功にも `NotCommitted` にも取り消しにも写されていないことが、結合テストで確認されている。
commit が `Ok` を返した後に使う scope の後始末がなく、確定済みの結果が型で保たれている。
取り消された use-case が、開いた Transaction も `pg_advisory_xact_lock` の鍵も残していないことが、結合テストで確認されている。

### 禁止事項
store が、Transaction の begin・commit・rollback を呼ぶこと。
domain と application が、sqlx の Transaction と `sqlx::Error` を受け取ること、または名指しすること。
composition が、Transaction を begin または commit すること。
closure を受ける API で use-case の本体を包み、外側に begin と commit を持たせること。
`sqlx::Error` の値や文字列を、業務の失敗に載せること。
`sqlx::Error::Database` であることだけを根拠に、commit の失敗を確定していないと判断すること。
commit の応答を受け取れない失敗を、成功、`NotCommitted`、取り消しのいずれかに写すこと。
開始済みの commit を、drop で中断すること。
`abort` の失敗で、元の終わりを上書きすること。

### 行動
use-case ごとに、必要な操作と commit と abort を持つ scope の port と、scope を begin する port を application に宣言する。
scope の操作の失敗は、use-case が分岐に使う分類の enum にし、commit の失敗と abort の失敗は別の型にする。
use-case で、scope を begin し、読み、domain の同期の関数へ値を渡し、判断の結果を書いて commit する。
commit を始める前に終わるときは、`abort` を await して、元の終わりと `abort` の失敗を一緒に返す。
infrastructure で、scope の port を Transaction を持つ型で実装し、store の関数へ scope の Transaction を渡す。
`commit` は `Ok` だけを確定とし、失敗は未確定を確認できる根拠があるときだけ `NotCommitted`、それ以外は `OutcomeUnknown` へ写す。
composition で、scope の port に実装を結び、Transaction を扱わない。
取り消しを受けたら新しい書き込みを始めず、`abort` を取り消されない後始末として await して完了させる。
`abort` の失敗、commit の応答を受け取る前の接続の切断、取り消し直後の Transaction と鍵の残存を、結合テストで確認する。

### 例
use-case の外側が begin と commit を持ち、sqlx の Transaction を store へ渡すと、読み、判断、書き込みの順と確定の制御が use-case から外れ、Transaction の型が application へ流れる。

```rust
let mut transaction = pool.begin().await?;
order_store.insert(&mut transaction, &order).await?;
outbox.add(&mut transaction, OrderPlaced::from(&order)).await?;
transaction.commit().await?;
```

次の断片は context の application と infrastructure の内側の実装であり、可視性の宣言を省く。
`Customer`・`Order`・scope の port はドメイン型を扱うので、context の外へ公開しない。
公開入口は command を受けて公開の outcome を返し、ドメイン型を返さない。

domain の判断は、Transaction も scope も受け取らない同期の関数である。

```rust
struct Customer {
    id: CustomerId,
    active: bool,
}

struct Order {
    customer_id: CustomerId,
}

enum PlaceRejected {
    CustomerInactive,
}

impl Order {
    fn place(customer: &Customer) -> Result<Order, PlaceRejected> {
        if customer.active {
            Ok(Order { customer_id: customer.id })
        } else {
            Err(PlaceRejected::CustomerInactive)
        }
    }
}
```

application は scope の port と use-case を持つ。
scope の操作の失敗、commit の失敗、abort の失敗を別の型で表し、use-case の終わりは元の失敗と `abort` の失敗を別の field に持つ。
commit を始める前に終わる経路は、すべて `abort` を await して返る。

```rust
enum ScopeFailure {
    NotFound,
    Unavailable,
}

enum CommitFailure {
    NotCommitted,
    OutcomeUnknown,
}

struct AbortFailure;

trait PlaceOrderScopes {
    type Scope: PlaceOrderScope;
    async fn begin(&self) -> Result<Self::Scope, ScopeFailure>;
}

trait PlaceOrderScope {
    async fn find_customer(&mut self, id: CustomerId) -> Result<Customer, ScopeFailure>;
    async fn insert_order(&mut self, order: &Order) -> Result<(), ScopeFailure>;
    async fn commit(self) -> Result<(), CommitFailure>;
    async fn abort(self) -> Result<(), AbortFailure>;
}

enum PlaceOrderFailure {
    Rejected(PlaceRejected),
    Scope(ScopeFailure),
    Commit(CommitFailure),
}

struct PlaceOrderEnd {
    failure: PlaceOrderFailure,
    abort_failure: Option<AbortFailure>,
}

struct PlacedOrder {
    customer_id: CustomerId,
}

async fn place_order<S: PlaceOrderScopes>(
    scopes: &S,
    command: PlaceOrderCommand,
) -> Result<PlacedOrder, PlaceOrderEnd> {
    let mut scope = scopes.begin().await.map_err(|failure| PlaceOrderEnd {
        failure: PlaceOrderFailure::Scope(failure),
        abort_failure: None,
    })?;
    let customer = match scope.find_customer(command.customer_id).await {
        Ok(customer) => customer,
        Err(failure) => return Err(abort(scope, PlaceOrderFailure::Scope(failure)).await),
    };
    let order = match Order::place(&customer) {
        Ok(order) => order,
        Err(rejected) => return Err(abort(scope, PlaceOrderFailure::Rejected(rejected)).await),
    };
    if let Err(failure) = scope.insert_order(&order).await {
        return Err(abort(scope, PlaceOrderFailure::Scope(failure)).await);
    }
    match scope.commit().await {
        Ok(()) => Ok(PlacedOrder { customer_id: order.customer_id }),
        Err(failure) => Err(PlaceOrderEnd {
            failure: PlaceOrderFailure::Commit(failure),
            abort_failure: None,
        }),
    }
}

async fn abort<S: PlaceOrderScope>(scope: S, failure: PlaceOrderFailure) -> PlaceOrderEnd {
    PlaceOrderEnd {
        failure,
        abort_failure: scope.abort().await.err(),
    }
}
```


infrastructure はこの port を、sqlx の Transaction を内側に持つ scope と、その transaction を借りて読み書きする store で実装する。
driver のエラーは port の失敗へ分類し、commit で未確定を確認できない失敗は `OutcomeUnknown` へ写す。

この断片は取り消しと期限の引数と欠陥の経路を含まない。
それらの扱いは [tokio-util](./tokio-util.md) の「取り消し」に従い、この断片で取り消しと欠陥の後始末を確かめたとは扱わない。
同じ確定に含める outbox と冪等の記録は、scope の操作として足し、commit の前に同じ Transaction へ書く。

## 冪等な要求の記録

### 要求
冪等な要求は、operation、actor scope、tenant、key を全て NOT NULL の列として持ち、その複合一意制約で競合を検出する。
認証済み要求は認証主体の ID、匿名要求は session または client ごとの安定した opaque scope、system 要求は logical actor ごとの ID を actor scope に使う。
actor scope は要求者の種別を分ける技術的な namespace であり、業務の当事者の識別子で置き換えない。
multi-tenant operation の認証済み要求は、認証境界で検証した tenant claim または membership、もしくは authorization で許可した tenant 選択から構築した `TenantId` を tenant scope に使う。
multi-tenant operation の匿名要求は、検証済みの host または route と、session または client の tenant context から構築した `TenantId` を tenant scope に使う。
multi-tenant operation の system 要求は、logical actor に設定した `TenantId` を tenant scope に使う。
single-tenant operation は、正準な single-tenant sentinel を tenant scope に使う。
tenant の概念を持たない operation は、正準な no-tenant sentinel を tenant scope に使う。
安定した scope のない匿名要求は、server 発行の全体で一意な key と発行時の proof だけを受け付け、proof を検証した要求者にだけ保存済み response を返す。
request fingerprint と初回 response は、冪等 key と業務の書き込みと同じ sqlx の Transaction で保存する。
同じ scope と key の再実行は、fingerprint が一致する場合だけ保存済み response を返し、不一致なら conflict を返す。

### 根拠
[transaction](../../concerns/transaction/README.md) が定める複合 scope と同じ確定点を PostgreSQL の制約と sqlx の Transaction に写せば、同時要求の競合と部分確定を DB で止められる。
actor scope を検索条件へ含めれば、別の要求者へ保存済み response を返さない。
要求者の種別ごとに [transaction](../../concerns/transaction/README.md) の scope を写せば、匿名や system を汎用 sentinel へ潰さない。
tenant の出所を認証、認可、host、route、logical actor の検証済み context に限れば、要求者が指定した未検証 tenant へ scope を切り替えられない。

### 完了条件
operation、actor scope、tenant、key の全列が NOT NULL で、複合一意制約を持っている。
認証主体の ID、匿名の安定した opaque scope、logical system actor の ID が、要求者の種別に応じて記録されている。
multi-tenant operation に、認証済み tenant、匿名の検証済み host または route と session/client tenant context、logical system actor の設定済み tenant が `TenantId` として記録されている。
single-tenant operation に、正準な single-tenant sentinel が記録されている。
tenant の概念を持たない operation に、正準な no-tenant sentinel が記録されている。
安定した匿名 scope がない場合に、server 発行の全体で一意な key と proof が使われ、proof のない別 client へ保存済み response が返らないことが漏洩テストで検証されている。
request fingerprint、初回 response、業務の書き込みが、同じ sqlx の Transaction で確定している。
同じ scope と key の同時要求が一件だけ業務を書き、異なる fingerprint が conflict になっている。
別の actor scope から保存済み response を取得できないことが、漏洩テストで検証されている。

### 禁止事項
冪等 key の競合を、sqlx の事前 SELECT だけで判定すること。
request fingerprint または初回 response を、業務の書き込みと別に commit すること。
actor scope を照合せずに、保存済み response を返すこと。
匿名または system の異なる要求者を、汎用の actor sentinel へまとめること。
actor scope を、業務の当事者の識別子へ置き換えること。
未検証の tenant claim、host、route、session、client 入力から `TenantId` を構築すること。
multi-tenant operation に single-tenant sentinel または no-tenant sentinel を使うこと。
single-tenant operation に `TenantId` または no-tenant sentinel を使うこと。
tenant の概念を持たない operation に `TenantId` または single-tenant sentinel を使うこと。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せず、安定した scope のない匿名要求の保存済み response を返すこと。

### 行動
`applied_requests` に複合一意制約を置き、sqlx の同じ Transaction で業務の書き込み、fingerprint、response を保存する。
認証主体の ID、匿名の安定した opaque scope、logical system actor の ID を種別ごとに記録する。
multi-tenant operation の認証済み要求は検証済み tenant claim、membership、または authorization 済み選択から `TenantId` を構築する。
multi-tenant operation の匿名要求は検証済み host または route と session/client tenant context から、system 要求は logical actor の設定から `TenantId` を構築する。
single-tenant operation に正準な single-tenant sentinel を使う。
tenant の概念を持たない operation に正準な no-tenant sentinel を使う。
安定した匿名 scope がなければ、server 発行の全体で一意な key と proof を発行し、proof を応答取得時に検証する。
同じ scope と key を並行に送る競合テストと、全要求者種別と tenant 種別の scope 分離、未検証 tenant の拒否、multi-tenant の `TenantId`、single-tenant sentinel、no-tenant sentinel の相互混同拒否、proof のない別 client からの response 取得拒否を確かめる漏洩テストを実行する。

## durable inbox

### 要求
受領した event は、consumer contract または subscription scope と event ID の複合一意制約を持つ durable inbox に記録する。
payload を durable inbox へ commit した後だけ、source へ upstream delivery ack を返す。
処理結果と inbox の処理済み記録は、同じ sqlx の Transaction で確定する。
処理 item の inbox processing completion と削除は、Transaction の commit が成功した後だけ行う。
inbox が容量上限に達した場合は、受領せず nack または再試行可能な失敗を返す。
inbox の使用量、上限、backlog、nack を監視へ出す。

### 根拠
payload の commit 前に upstream delivery ack を返さず、満杯を nack すれば、前段の停止で event を source から失わない。
処理結果と処理済み記録の commit 前に inbox processing completion を行わなければ、後段の停止で item を再処理できる。

### 完了条件
durable inbox が scope と event ID の複合一意制約を持っている。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
処理結果と処理済み記録が、同じ sqlx の Transaction で確定している。
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
処理結果と処理済み記録を同じ sqlx の Transaction で書き、commit 成功後に inbox processing completion を確定して処理 item を完了または削除する。
容量を予約できない場合は nack または再試行可能な失敗を返し、使用量、backlog、nack を記録する。
payload commit と処理結果 commit の各直前・直後の停止、および容量上限を再現する結合テストを実行する。

## 並行更新の表面

### 要求
同じ集約への同時の更新は [transaction](../../concerns/transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従って制御し、版で衝突を検出する集約、共有の鍵か鍵なしで更新する可変属性の行、一回だけ起きる業務事実を追記する集約では競合の Result に写す。
集約の鍵は、scope の sqlx の Transaction の中で、検証より前に、排他なら `pg_advisory_xact_lock(bigint)`、共有なら `pg_advisory_xact_lock_shared(bigint)` で取る。
集約の鍵の bigint は、集約の種類と集約の識別子から、種類の違う集約の鍵が衝突しないように一意に導き、その導出をコードの一か所に定義する。
一つの書き込みが複数の鍵を取る場合は、全ての書き込み経路で bigint の値の昇順に取る。
多数の鍵は、昇順に並べた bigint の配列を `unnest` で展開する一つの `SELECT` で取り、その文の中で並べ替えない。
鍵を取った後の検証の読み取りは、READ COMMITTED の Transaction で行う。
datastore が付ける業務事実の活動の時刻の列は、既定値を `clock_timestamp()` にし、`CURRENT_TIMESTAMP`、`now()`、`statement_timestamp()` を既定値に使わない。
予定の始まりや終わりの到来と保持期限の経過を判定するビューは、判定の時点に `statement_timestamp()` を使い、`CURRENT_TIMESTAMP`、`now()`、`clock_timestamp()` を使わず、そのビューを読む文は鍵を取る文と別の命令で送る。
識別子を datastore が採番する列だけを持つ関係へは、識別子を指定せず `DEFAULT VALUES` で追記し、`OVERRIDING SYSTEM VALUE` を使わない。
datastore が付ける活動の時刻から規則で決まる業務事実の値(変更を適用する始まりの日など)は、その時刻の列から求める `GENERATED ALWAYS AS (...) STORED` の列に持ち、規則の改定では、改定より前の行が同じ値になる式へ移行の `ALTER COLUMN ... SET EXPRESSION` で置き換える。
版で衝突を検出し、正本が可変属性の行である集約では、`UPDATE` の `WHERE` で期待する version を比較して同じ文で version を進め、影響行数が 0 のときを競合とする。
共有の鍵か鍵なしで更新する可変属性の行は、同じ行への同時の更新を、`UPDATE` の `WHERE` で期待する version を比較して同じ文で version を進めて検出し、影響行数が 0 のときを競合とする。
版で衝突を検出し、正本が追記する事実の関係である集約では、名前を付けた `(集約の識別子, version)` の UNIQUE 制約の違反だけを競合とし、他の制約違反は競合に写さない。
一回だけ起きる業務事実を追記する集約では、一回だけであることを守る主キーに名前を付け、その名前付きの主キーの違反だけを競合とし、他の制約違反は競合に写さない。
版で競合を検出する集約へ書く全ての書き込み経路は、正本に応じた同じ検出を通す。
必要な業務事実は、現在情報の書き込みと同じ sqlx の Transaction で追記する。
業務事実を必要としない現在情報の更新は、集約に定めた競合制御を通し、業務事実を追記せず `UPDATE` で書いてよい。
競合または失敗のとき、use-case は commit せず scope を abort し、現在情報の更新、業務事実の追記、outbox の記録のどれも残さない。
公開する integration event は、業務事実の追記と別に、現在情報の書き込みと同じ Transaction で outbox へ記録する。

### 根拠
同時の更新を検出しなければ、後の書き込みが前の更新を黙って失わせる。
version を `WHERE` で比較して同じ文で進める楽観的ロックなら、同じ version を期待する二つの更新のうち片方だけが行を更新し、他方は影響行数 0 になる。
共有の鍵は同じ行への同時の更新を直列にしないので、共有の鍵か鍵なしで更新する可変属性の行は、version の比較で片方だけが行を更新し、他方は影響行数 0 になる。
正本が追記する事実の関係なら、`(集約の識別子, version)` に UNIQUE 制約を課すと、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
一回だけ起きる業務事実の関係は、[persistence](../../concerns/persistence/fact-state-time-relations.md) の「事実・状態・時間を別の関係に落とす」に従って対象のキーを主キーにするので、二度目の追記は主キーの違反になる。
一意制約違反は冪等 key や重複を許さない値の制約でも起きるので、違反の種類だけで競合と判定すると、version や一回だけであることを守る主キー以外の違反を競合へ誤って写す。
sqlx の `DatabaseError::constraint()` は、PostgreSQL の driver が違反した制約の名前を返すので、version の制約や主キーに付けた名前と照合すれば競合だけを識別できる。
どちらで検出するかは正本が何かで決まるので、書き込みごとに選ばない。
`pg_advisory_xact_lock(bigint)` と `pg_advisory_xact_lock_shared(bigint)` は、表の行でなく bigint の値に鍵を掛けるので、書き込み経路が更新してはならない事実の行への更新権限なしに集約の鍵を取れる。
`SELECT ... FOR UPDATE` などの行ロック句は対象の行への `UPDATE` 権限を要するので、事実の行に使うと、鍵のために書き込み経路へ事実の行の更新権限を与えることになる。
`pg_advisory_xact_lock` 系の鍵は Transaction の終了で自動的に解放されるので、scope の commit または abort(drop による rollback を含む)が解放点になり、store は解放を持たない。
READ COMMITTED は文ごとに直前の確定を読むので、鍵を待った後の検証の文は、先に鍵を持っていた書き込みの確定を読める。
REPEATABLE READ 以上は最初の文の snapshot を使い続けるので、鍵を待つ間に確定した書き込みを検証で読めない。
鍵を bigint の値の昇順に取れば、鍵どうしの待ちが循環せず、デッドロックが起きない。
種類の違う集約の鍵の値が衝突すると、無関係な集約が同じ鍵を取って互いを待たせるので、鍵の値は種類と識別子から一意に導く。
識別子の範囲を下位の bit に収まる範囲に限れば、識別子が種類の bit へ溢れて別の種類の鍵と重ならない。
導出を一か所に定義すれば、全ての書き込み経路が同じ集約に同じ値の鍵を取り、昇順の全順序も一つの値の空間で定まる。
業務事実の時刻を datastore の既定値で付ける理由は、[persistence](../../concerns/persistence/append-only-facts.md) の「業務事実を保持期間の間は追記で残す」に従う。
`CURRENT_TIMESTAMP` と `now()` は Transaction の開始時刻に固定されるので、集約の鍵を待った Transaction は、待つ間に確定した業務事実より前の時刻を付ける。
`clock_timestamp()` は評価した時点の時刻を返すので、鍵の後に追記した行の時刻が、先に確定した行の時刻以後になる。
`statement_timestamp()` は client から最後の命令を受け取った時刻を返すので、鍵を取る文と同じ一つの命令で送った文では、鍵を待つ前の時刻を付ける。
書き込み経路は datastore が付ける時刻を知らず、時刻の列への書き込み権限も持たないので、その時刻から決まる値は datastore が同じ行の中で求める。
`clock_timestamp()` は volatile なので、それを出力に持つビューは結合の中で展開されず、結合の条件で索引を使えないため、判定が相手の関係を全件読む。
`statement_timestamp()` は一つの文の中で同じ値を返し、鍵を取る文と別の命令で送った文では、鍵を待った後の時刻になる。
識別子を datastore が採番する列だけを持つ関係に追記するには識別子の列への `INSERT` 権限が要り、その権限は `OVERRIDING SYSTEM VALUE` による識別子の指定を拒まないので、指定しないことを書き込み経路が守る。
業務事実が必要かどうかは [data](../../principles/data/preserve-facts-and-current-state.md) の「業務事実と現在情報を分けて保持する」に従う。
プロフィールの表示名や企業名のような可変属性は、業務事実を必要としない限り、`UPDATE` で更新してよい。
現在情報の更新と必要な業務事実の追記を同じ Transaction で確定すれば、片方だけが確定して現在情報と事実が食い違うことがない。
競合や失敗で commit しなければ、競合した更新の書き込みは現在情報にも業務事実にも outbox にも残らない。
業務事実は集約の内側で起きた事実であり、コンテキストの外へ公開する integration event の outbox 記録とは別なので、一方を他方の代わりにしない。
domain event と integration event の区別は [messaging](../../concerns/messaging/domain-integration-events.md) に従う。
影響行数 0 と制約違反を競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
版で衝突を検出し、正本が可変属性の行である集約で、同じ version を期待する並行更新の片方だけが確定し、他方が競合の Result で返されている。
共有の鍵か鍵なしで更新する可変属性の行で、同じ version を期待する同じ行への並行更新の片方だけが確定し、他方が競合の Result で返されている。
版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行で、条件付き `UPDATE` の影響行数 0 が、競合の Result に写されている。
版で衝突を検出し、正本が追記する事実の関係である集約で、同じ version の重複追記が、名前を付けた `(集約の識別子, version)` の UNIQUE 制約の違反として検出され、競合の Result で返されている。
一回だけ起きる業務事実の二度目の追記が、名前を付けた主キーの違反として検出され、競合の Result で返されている。
version の制約と一回だけであることを守る主キー以外の制約違反が、競合の Result に写されていない。
版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行の全ての書き込み経路で、古い version を期待した更新が競合になり、現在情報が変わっていない。
集約の鍵を取る全ての書き込みが、scope の sqlx の Transaction の中で、use-case が検証より前に呼ぶ操作により、排他は `pg_advisory_xact_lock(bigint)`、共有は `pg_advisory_xact_lock_shared(bigint)` で鍵を取っている。
複数の鍵を取る書き込みが、全ての書き込み経路で bigint の値の昇順に鍵を取っている。
集約の鍵の bigint が、集約の種類と識別子から一意に導かれ、種類の違う集約の鍵が衝突せず、識別子が下位の bit の範囲に収まらないとき導出が鍵を作らず、導出がコードの一か所にだけ定義されている。
鍵を取った後の検証が READ COMMITTED で行われ、鍵を待つ間に確定した書き込みを読んでいる。
書き込み経路の role が、事実の行への `UPDATE` と `DELETE` の権限を持たないまま集約の鍵を取り、事実の行に `SELECT ... FOR UPDATE` を使っていない。
datastore が付ける業務事実の時刻の列の既定値が `clock_timestamp()` であり、鍵を待った書き込みが付けた時刻が、待つ間に確定した業務事実の時刻以後である。
予定の到来と保持期限の経過を判定するビューが `statement_timestamp()` を使い、そのビューを読む文が鍵を取る文と別の命令で送られている。
識別子を datastore が採番する列だけを持つ関係への追記が、識別子を指定していない。
必要な業務事実を伴う更新で、現在情報の更新と業務事実の追記が、同じ sqlx の Transaction で確定している。
競合または失敗した更新が、現在情報の更新も業務事実の追記も outbox の記録も残していない。
業務事実を必要としない現在情報の更新が、集約に定めた競合制御を通し、業務事実の追記なしで `UPDATE` により書かれている。
公開する integration event の outbox への記録が、業務事実の追記と別に、現在情報の書き込みと同じ Transaction で行われている。

### 禁止事項
集約に定めた競合制御を通さず、同時の更新を上書きすること。
版で衝突を検出する集約と、共有の鍵か鍵なしで更新する可変属性の行で、条件付き `UPDATE` の影響行数 0 を、競合として扱わず成功にすること。
共有の鍵か鍵なしで更新する可変属性の行を、version の比較なしで更新すること。
必要な業務事実を、事実を追記しない現在情報の `UPDATE` だけで表すこと。
事実の行から導ける今の状態を状態の列として持ち `UPDATE` で書く禁止は、[data](../../principles/data/derive-state-from-facts.md) の「今の状態を事実の行から導く」に従う。
現在情報の更新と必要な業務事実の追記を、別々の Transaction で確定すること。
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
集約の鍵を取る書き込みは、use-case が検証より前に scope の鍵の操作を呼び、その実装が scope の sqlx の Transaction の中で、排他なら `sqlx::query!("SELECT pg_advisory_xact_lock($1)", aggregate_key)`、共有なら `sqlx::query!("SELECT pg_advisory_xact_lock_shared($1)", aggregate_key)` を `execute` で実行する。
複数の鍵を取る書き込みは、bigint の値の昇順に並べてから取る。
集約の鍵の bigint は、固定の上位の bit に種類を、範囲を限った下位の bit に識別子を置いて導き、その導出を一つの関数に定義して全ての書き込み経路から呼ぶ。
集約の鍵で競合制御する集約では、鍵を取った後に、READ COMMITTED の文で今の状態を検証してから書く。
事実の行に `SELECT ... FOR UPDATE` を使わず、書き込み経路の role に事実の行への `UPDATE` と `DELETE` の権限を与えない。
版で衝突を検出する集約の可変属性の行と、共有の鍵か鍵なしで更新する可変属性の行は、`SET` で `version = version + 1` に進め、`WHERE` に `version = $2` を含む `UPDATE` で書き、`rows_affected()` が 0 なら `WriteError::Conflict` を返す。
版で衝突を検出する事実の関係は、`(集約の識別子, version)` に名前を付けた UNIQUE 制約を置き、`sqlx::Error::Database` の `is_unique_violation()` が真で `constraint()` がその名前と一致するときだけ `WriteError::Conflict` に写し、他の制約違反は `WriteError::Database` で返す。
一回だけ起きる業務事実の関係は、対象のキーを主キーにして主キーに名前を付け、`sqlx::Error::Database` の `is_unique_violation()` が真で `constraint()` がその名前と一致するときだけ `WriteError::Conflict` に写し、他の制約違反は `WriteError::Database` で返す。
datastore が付ける業務事実の時刻の列は `DEFAULT clock_timestamp()` で定義し、鍵を待った書き込みの時刻が待つ間に確定した業務事実の時刻以後になることを結合テストで確認する。
更新ごとに必要な業務事実を確かめ、必要なら同じ Transaction の中で業務事実の関係へ INSERT する。
競合または失敗では、use-case が commit せず scope を abort する。
版で衝突を検出する集約では、同じ version の並行更新、古い version の各経路からの更新、version 以外の一意制約違反を結合テストで再現する。
集約の鍵を排他で取る集約では、全経路での直列化と鍵の後の検証、書き込み経路の role が事実の行へ `UPDATE` も `DELETE` もできないこと、複数の鍵を一つの順序で取ること、種類の違う集約の鍵が衝突しないこと、一回だけ起きる業務事実の二度目の追記で名前付きの主キーの違反だけが競合に写ることを結合テストで確認し、排他の鍵の下で更新する判定の対象の行への version の追加は要求しない。
共有の鍵か鍵なしで更新する可変属性の行では、同じ行への同時の更新を結合テストで再現し、片方だけが確定して他方が競合になることを確認する。
現在情報の更新と業務事実の追記の間の失敗は、どちらの集約でも再現する。

### 例
競合と失敗は、infrastructure の store が返す閉じた型付きの失敗で表す。
scope の実装は、`WriteError::Conflict` を use-case が分岐に使う scope の失敗の分類へ競合として写し、`sqlx::Error` を application へ出さない。

```rust
#[derive(thiserror::Error, Debug)]
pub enum WriteError {
    #[error("conflict")]
    Conflict,
    #[error("database")]
    Database(#[from] sqlx::Error),
}
```

プロフィールの表示名は `user_profiles(user_id, display_name, version)` に置く可変属性である。
プロフィールの更新は利用者の集約の鍵を共有で取り、同じ行への同時の更新をその行の version で検出する。
次の断片は、`WHERE` で期待する version を比較して同じ文で version を進め、影響行数 0 を競合へ写す。

```rust
let updated = sqlx::query!(
    "UPDATE user_profiles SET display_name = $3, version = version + 1 WHERE user_id = $1 AND version = $2",
    user_id,
    expected_version,
    display_name,
)
.execute(&mut **transaction)
.await?;
if updated.rows_affected() == 0 {
    return Err(WriteError::Conflict);
}
Ok(())
```

取消の時刻と理由を残す義務があるとき、`orders` の `status` 列を `UPDATE` して取消を表すと、取消の事実が欠落し、取消済みかを事実の行と別の列で二重に持つ。

```rust
sqlx::query!("UPDATE orders SET status = 'cancelled' WHERE id = $1", order_id)
    .execute(&mut **transaction)
    .await?;
Ok(())
```

状態の列を置かず、取消を `order_cancellations(order_id PRIMARY KEY, reason_code)` への追記で表す。
取消は注文を参照する一回だけ起きる業務事実であり、注文の集約の他の書き込みと直列に確定させるので、注文の集約の鍵を `pg_advisory_xact_lock` で排他に取ってから追記する。
`occurred_at` は `DEFAULT clock_timestamp()` の列の既定値で付き、書き込み経路は渡さない。
二度目の取消は名前を付けた主キー `order_cancellations_pkey` の違反になり、違反した制約の名前が一致するときだけ競合へ写す。
競合の Err を受けた use-case は commit せず scope を abort するので、取消は残らず、鍵も Transaction の終了で解放される。

```rust
const ORDER_CANCELLATION_CONSTRAINT: &str = "order_cancellations_pkey";

sqlx::query!("SELECT pg_advisory_xact_lock($1)", order_key)
    .execute(&mut **transaction)
    .await?;
let result = sqlx::query!(
    "INSERT INTO order_cancellations (order_id, reason_code) VALUES ($1, $2)",
    order_id,
    reason_code,
)
.execute(&mut **transaction)
.await;
match result {
    Ok(_) => Ok(()),
    Err(sqlx::Error::Database(database_error))
        if database_error.is_unique_violation()
            && database_error.constraint() == Some(ORDER_CANCELLATION_CONSTRAINT) =>
    {
        Err(WriteError::Conflict)
    }
    Err(error) => Err(error.into()),
}
```

正本が追記する事実の関係で、一意制約違反をすべて競合へ写すと、`(account_id, version)` 以外の一意制約の違反まで競合として返される。

```rust
let result = sqlx::query!(
    "INSERT INTO ledger_entries (account_id, version, amount) VALUES ($1, $2, $3)",
    account_id,
    expected_version + 1,
    amount,
)
.execute(&mut **transaction)
.await;
match result {
    Ok(_) => Ok(()),
    Err(sqlx::Error::Database(database_error)) if database_error.is_unique_violation() => {
        Err(WriteError::Conflict)
    }
    Err(error) => Err(error.into()),
}
```

名前を付けた `(account_id, version)` の UNIQUE 制約と、違反した制約の名前が一致するときだけ競合へ写し、他の制約違反は `WriteError::Database` で返す。

```rust
const LEDGER_VERSION_CONSTRAINT: &str = "ledger_entries_account_id_version_key";

let result = sqlx::query!(
    "INSERT INTO ledger_entries (account_id, version, amount) VALUES ($1, $2, $3)",
    account_id,
    expected_version + 1,
    amount,
)
.execute(&mut **transaction)
.await;
match result {
    Ok(_) => Ok(()),
    Err(sqlx::Error::Database(database_error))
        if database_error.is_unique_violation()
            && database_error.constraint() == Some(LEDGER_VERSION_CONSTRAINT) =>
    {
        Err(WriteError::Conflict)
    }
    Err(error) => Err(error.into()),
}
```
