# apalis

用途は、背景処理と定期実行の daemon の骨格である。
採用は、Rust は apalis であり、PostgreSQL を backend にした queue に限って使う。
判断基準は、queue と scheduler を既存の datastore に閉じ、外部の broker を開かないことである。
撤回条件は、判断基準を満たさなくなることであり、backend の対応状況の変化と apalis の 1.0 リリースを再評価のトリガーとする。

## worker

### 要求
worker は apalis を、PostgreSQL を backend にした queue と scheduler に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
handler の依存は `Data` extractor で受け取り、handler の中で直接生成しない。
再配送契約を持つ source の event は durable inbox の容量を予約し、payload の commit 後だけ upstream delivery ack を返す。
inbox processing completion と処理 item の削除は、処理結果と処理済み記録の commit 後だけ行う。
外部効果には、配備上の consumer 名に依存しない安定した effect operation の識別子と event ID から作る冪等キーを渡す。
外部効果が成功した後に処理済み記録を commit し、その後に inbox processing completion を行う。
durable inbox が満杯なら nack または再試行可能な失敗を返し、使用量、上限、backlog、nack を監視へ出す。

### 根拠
queue を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
apalis の cron 機構を scheduler に使えば、定期実行も同じ PostgreSQL backend の queue に閉じる。
job の処理を queue から受ける形にすれば、副作用が処理の中に集まる。
`Data` extractor で依存を渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。
payload commit 後だけ upstream delivery ack を返せば、前段の停止で未確定になった event を source から再配送できる。
処理結果と処理済み記録の commit 後だけ inbox processing completion を行えば、後段の停止で item を再処理できる。
外部効果の境界へ安定した冪等キーを渡せば、効果成功後から処理済み記録前の停止でも再配送の結果を一度分にできる。
容量を予約できない event を nack すれば、必要な入力を受領済みとして失わない。

### 完了条件
worker が、apalis を PostgreSQL を backend にした queue と scheduler に限って使っている。
broker・durable workflow・外部の message bus として、使われていない。
handler の依存が、`Data` extractor で受け取られ、handler の中で直接生成されていない。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
外部効果に安定した effect operation の識別子と event ID から作った冪等キーが渡され、効果成功後に処理済み記録が確定している。
payload commit と、外部効果成功と、処理済み記録 commit の各前後で停止して再配送しても、結果が一度分になることが実行テストで検証されている。
durable inbox の容量上限で nack または再試行可能な失敗が返され、使用量、上限、backlog、nack が監視されている。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
handler の中で、依存を直接生成すること。
payload の durable inbox への commit 前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit 前に、inbox processing completion または処理 item の削除を行うこと。
外部効果の成功前に、処理済みを記録すること。
配備上の consumer 名を、外部効果の冪等キーに使うこと。
durable inbox が満杯の event を受領済みとして捨てること。

### 行動
queue を PostgreSQL の backend に限り、apalis で enqueue と worker を組む。
定期実行は apalis の cron 機構で scheduler として組む。
worker の起動は WorkerBuilder で組み、apalis の Monitor で走らせる。
handler の依存は `Data` extractor で渡す。
受領時に durable inbox の容量を予約し、payload を commit してから upstream delivery ack を返す。
処理結果と処理済み記録を retention の同じ Transaction で確定してから、inbox processing completion を行う。
外部効果へ安定した effect operation の識別子と event ID の組を冪等キーとして渡し、成功後に処理済み記録を commit する。
payload commit、外部効果成功、処理済み記録 commit の各直前と直後へ停止を注入し、再配送後の結果が一度分であることをテストする。
容量を予約できない場合は nack または再試行可能な失敗を返し、inbox の使用量、上限、backlog、nack を観測する。

### 例
queue は PostgreSQL backend に閉じる。`PostgresStorage::push` は可変参照を要求するため、storage を可変束縛にする。worker の起動は `WorkerBuilder` と apalis の `Monitor` で組むが、版によって変わる具体の呼び出し形はここでは固定しない。

```rust
let mut storage = PostgresStorage::new(&pool);
storage.push(SendEmail { to }).await?;
let permit = inbox.try_reserve().ok_or(ReceiveError::Retryable)?;
let item = inbox.commit_payload(permit, event).await?;
source.delivery_ack(item.event_id()).await?;
let key = EffectKey::new("capture-payment", item.event_id());
payment.capture(item.amount(), key).await?;
record_processed_in_transaction(item.id()).await?;
inbox.complete(item.id()).await?;
```
