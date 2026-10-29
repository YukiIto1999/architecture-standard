# apalis

用途は、背景処理の durable な queue と、業務のデータが決める時刻の予約の骨格である。
採用は、Rust は apalis と apalis-postgres であり、PostgreSQL を backend にした queue に限って使う。
判断基準は、queue と予約を既存の datastore に閉じ、外部の broker を開かず、backend が [sqlx](./sqlx.md) の採用と同じ系の SQL client を要求することである。
撤回条件は、判断基準を満たさなくなることであり、backend の対応状況の変化と apalis の安定版の到達を再評価のトリガーとする。

## worker

### 要求
worker は apalis を、PostgreSQL を backend にした queue と、業務のデータが決める時刻の予約に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
予約は、実行時刻を持つ task として PostgreSQL へ積み、同じ業務事実から導いた冪等の鍵で二重に積まない。
固定の時刻と間隔による定期実行は、apalis-cron を含む cron 式の scheduler で組まず、OS の定時起動から [worker](../../structure/surfaces/worker/layout.md) の「定時起動」の入口が受ける。
handler の依存は `Data` extractor で受け取り、handler の中で直接生成しない。
job の payload は、worker が実際に取り出す経路で、payload が宣言する版の契約に従う [serde](./serde.md) の decode と検証を通してから、handler の業務処理へ渡す。
選択した版の必須項目の欠落、契約が許さない null、既知項目の不正、判別子の不整合を持つ payload は、既定値で補わず、業務処理を始めずに拒否し、既知の契約を満たす payload に未知の追加項目だけを加えた場合は受容する。
拒否は再試行しても回復しない失敗であり、[resilience](../../concerns/resilience/dead-letter-exit.md) の「再試行の出口を持つ」に従って行き止まりへ送る。
一時的な旧版対応の撤去は、[messaging](../../concerns/messaging/event-contract-versioning.md) の「イベント契約を版で進化させ、寛容に読む」に従い、発行と再投入の停止後に、outbox を含む全配送先に未完了の旧版が残らないことを確かめて行う。
処理も契約上の終了も経ていない job を削除して、旧版の残存をなくさない。
履歴の読み出し変換は、この撤去の対象に含めず、[persistence](../../concerns/persistence/read-time-upcasting.md) の「追記した事実の版を読み出しで現在へ変換する」に従い、保持・監査・回復の契約が旧版の解釈を必要とする間は存続させる。
再配送契約を持つ source の event は durable inbox の容量を予約し、payload の commit 後だけ upstream delivery ack を返す。
inbox processing completion と処理 item の削除は、処理結果と処理済み記録の commit 後だけ行う。
外部効果には、配備上の consumer 名に依存しない安定した effect operation の識別子と event ID から作る冪等キーを渡す。
外部効果が成功した後に処理済み記録を commit し、その後に inbox processing completion を行う。
durable inbox が満杯なら nack または再試行可能な失敗を返し、使用量、上限、backlog、nack を監視へ出す。

### 根拠
queue を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
予約を実行時刻を持つ task として PostgreSQL に積めば、予約も同じ backend の durable な queue に閉じ、停止の後も失われず、再配送の対象になる。
固定の時刻と間隔の起動を OS が担えば、worker の内部に cron 式の scheduler を足さずに済み、起動の合図の重複と欠落は定時起動の入口の冪等で吸収できる。
job の処理を queue から受ける形にすれば、副作用が処理の中に集まる。
`Data` extractor で依存を渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。
payload commit 後だけ upstream delivery ack を返せば、前段の停止で未確定になった event を source から再配送できる。
処理結果と処理済み記録の commit 後だけ inbox processing completion を行えば、後段の停止で item を再処理できる。
外部効果の境界へ安定した冪等キーを渡せば、効果成功後から処理済み記録前の停止でも再配送の結果を一度分にできる。
容量を予約できない event を nack すれば、必要な入力を受領済みとして失わない。
queue の job には旧い版の発行元が積んだものや再投入されたものが混ざるので、型付きの enqueue だけに頼らず、保存形式上の欠落や不正な null の拒否を、worker が実際に取り出す経路で確かめる。
契約違反の payload で業務処理を始めなければ、既定値で補われた欠落が外部効果や処理済み記録へ入らない。
queue が一時的に空でも、予約や再投入の経路に旧版が残れば旧版は再び届くので、残存は未完了の全ての状態で確かめる。
処理も契約上の終了も経ていない job を削除すれば、残存の確認は満たされても業務の仕事を失う。
履歴の読み出し変換は、保持・監査・回復の契約が旧版の解釈を必要とする間続くので、queue の配送互換の撤去と別の条件で扱う。

### 完了条件
worker が、apalis を PostgreSQL を backend にした queue と、業務のデータが決める時刻の予約に限って使っている。
broker・durable workflow・外部の message bus として、使われていない。
予約した task が、実行時刻の前に実行されず、停止の後も失われず、実行時刻の後に実行されることと、同じ業務事実から二度積んでも一つの task になることが、実行テストで検証されている。
Cargo 依存に、apalis-cron を含む cron 式の scheduler の crate がない。
固定の時刻と間隔の起動が、OS の定時起動と worker の定時起動の入口で行われている。
handler の依存が、`Data` extractor で受け取られ、handler の中で直接生成されていない。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
外部効果に安定した effect operation の識別子と event ID から作った冪等キーが渡され、効果成功後に処理済み記録が確定している。
payload commit と、外部効果成功と、処理済み記録 commit の各前後で停止して再配送しても、結果が一度分になることが実行テストで検証されている。
durable inbox の容量上限で nack または再試行可能な失敗が返され、使用量、上限、backlog、nack が監視されている。
payload が宣言する版ごとに、未知の追加項目を加えた入力の受容と、必須項目の欠落・不正な null・既知項目の不正・判別子の不整合を加えた入力の拒否が、worker が実際に取り出す経路への投入で別々に実行テストにより検証され、拒否した入力で業務処理が始まっていない。
拒否した payload が、記録を残して行き止まりへ送られ、無期限に再試行されず、黙って捨てられていない。
一時的な旧版対応を撤去した変更で、発行と再投入の停止後に、outbox を含む messaging が挙げる全配送先に未完了の旧版が残らないことが、実際の状態を使う実行検査で確かめられている。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
固定の時刻と間隔の起動のために、apalis-cron などの cron 式の scheduler を worker の中へ追加すること。
handler の中で、依存を直接生成すること。
payload の durable inbox への commit 前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit 前に、inbox processing completion または処理 item の削除を行うこと。
外部効果の成功前に、処理済みを記録すること。
配備上の consumer 名を、外部効果の冪等キーに使うこと。
durable inbox が満杯の event を受領済みとして捨てること。
検証を経ていない payload や、既定値で欠落を補った payload で、handler の業務処理を始めること。
queue が空であることだけを根拠に、一時的な旧版対応を撤去すること。
旧版の残存をなくすために、処理も契約上の終了も経ていない job を削除すること。

### 行動
queue を PostgreSQL の backend に限り、apalis で enqueue と worker を組む。
固定の時刻と間隔の起動は OS の宣言へ置き、worker には cron 式の scheduler を追加しない。
業務のデータが決める時刻の予約は、実行時刻を持つ task として積み、同じ業務事実から導いた冪等の鍵を付ける。
worker の起動は WorkerBuilder で組み、apalis の Monitor で走らせる。
handler の依存は `Data` extractor で渡す。
受領時に durable inbox の容量を予約し、payload を commit してから upstream delivery ack を返す。
処理結果と処理済み記録を retention の同じ Transaction で確定してから、inbox processing completion を行う。
外部効果へ安定した effect operation の識別子と event ID の組を冪等キーとして渡し、成功後に処理済み記録を commit する。
payload commit、外部効果成功、処理済み記録 commit の各直前と直後へ停止を注入し、再配送後の結果が一度分であることをテストする。
容量を予約できない場合は nack または再試行可能な失敗を返し、inbox の使用量、上限、backlog、nack を観測する。
handler の業務処理の前に、payload が宣言する版の生成 DTO で decode と検証を通し、拒否した payload は業務処理を始めず行き止まりへ送る。
decode の失敗が採用版の apalis でどの状態へ遷移するかはこの標準で固定せず、契約違反の payload を実際の queue へ投入して、業務処理が始まらず、黙って捨てられず、無期限に再試行されないことを観測する。
型付きの enqueue では作れない欠落や不正な null は、採用版の backend が保持する形式の生の payload として投入する。
一時的な旧版対応を撤去するときは、発行と再投入を止めてから、outbox を含む messaging が挙げる全配送先の実際の状態を確かめ、未完了の旧版が残る間は撤去しない。

### 例
queue は PostgreSQL backend に閉じる。
`PostgresStorage::push` は可変参照を要求するため、storage を可変束縛にする。
worker の起動は `WorkerBuilder` と apalis の `Monitor` で組むが、版によって変わる具体の呼び出し形はここでは固定しない。

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
