# Wolverine

用途は、背景処理と定期実行の daemon の骨格である。
採用は、C# は Wolverine であり、PostgreSQL を backend にした queue に限って使う。
判断基準は、queue と scheduler を既存の datastore に閉じ、外部の broker を開かないことである。
撤回条件は、判断基準を満たさなくなることであり、backend の対応状況の変化と apalis の 1.0 リリースを再評価のトリガーとする。

## worker

### 要求
worker は Wolverine を、PostgreSQL の queue と scheduler に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
handler の依存は、`IMessageBus` を含め constructor で受け取る。
handler で、実行時の IoC 解決を使わない。
handler は CancellationToken を受け取り、token を受ける全ての非同期 API へ渡す。
再配送契約を持つ source の event は durable inbox の容量を予約し、payload の commit 後だけ upstream delivery ack を返す。
inbox processing completion と処理 item の削除は、処理結果と処理済み記録の commit 後だけ行う。
外部効果には、配備上の consumer 名に依存しない安定した effect operation の識別子と event ID から作る冪等キーを渡す。
外部効果が成功した後に処理済み記録を commit し、その後に inbox processing completion を行う。
durable inbox が満杯なら nack または再試行可能な失敗を返し、使用量、上限、backlog、nack を監視へ出す。

### 根拠
queue と scheduler を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
handler の依存を constructor で受ければ、依存がシグネチャに現れる。
`IMessageBus` を method parameter で受けず constructor に揃えると、handler の依存が一箇所に現れる。
CancellationToken を下流へ渡せば、worker の停止と期限切れが非同期処理の末端まで伝わる。
実行時の IoC 解決は、依存をシグネチャから隠し、コンパイル時の誤りを実行時へ遅らせる。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。
payload commit 後だけ upstream delivery ack を返せば、前段の停止で未確定になった event を source から再配送できる。
処理結果と処理済み記録の commit 後だけ inbox processing completion を行えば、後段の停止で item を再処理できる。
外部効果の境界へ安定した冪等キーを渡せば、効果成功後から処理済み記録前の停止でも再配送の結果を一度分にできる。
容量を予約できない event を nack すれば、必要な入力を受領済みとして失わない。

### 完了条件
worker が、Wolverine を PostgreSQL の queue と scheduler に限って使っている。
handler の依存が、`IMessageBus` を含め constructor で受け取られている。
handler で、実行時の IoC 解決が使われていない。
CancellationToken が、token を受ける全ての非同期 API へ渡されている。
broker・durable workflow・外部の message bus として、使われていない。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
外部効果に安定した effect operation の識別子と event ID から作った冪等キーが渡され、効果成功後に処理済み記録が確定している。
payload commit と、外部効果成功と、処理済み記録 commit の各前後で停止して再配送しても、結果が一度分になることが実行テストで検証されている。
durable inbox の容量上限で nack または再試行可能な失敗が返され、使用量、上限、backlog、nack が監視されている。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
handler で、実行時に IoC から依存を解決すること。
`IMessageBus` を、handler method の parameter で受け取ること。
token を受ける非同期 API への CancellationToken の伝播を途切れさせること。
payload の durable inbox への commit 前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit 前に、inbox processing completion または処理 item の削除を行うこと。
外部効果の成功前に、処理済みを記録すること。
配備上の consumer 名を、外部効果の冪等キーに使うこと。
durable inbox が満杯の event を受領済みとして捨てること。

### 行動
永続化を PostgreSQL に限り、`IMessageBus` を含む handler の依存を constructor で受ける。
handler の CancellationToken を、token を受ける全ての非同期 API へ渡す。
予約は durable な scheduler で行う。
受領時に durable inbox の容量を予約し、payload を commit してから upstream delivery ack を返す。
処理結果と処理済み記録を retention の同じ transaction で確定してから、inbox processing completion を行う。
外部効果へ安定した effect operation の識別子と event ID の組を冪等キーとして渡し、成功後に処理済み記録を commit する。
payload commit、外部効果成功、処理済み記録 commit の各直前と直後へ停止を注入し、再配送後の結果が一度分であることをテストする。
容量を予約できない場合は nack または再試行可能な失敗を返し、inbox の使用量、上限、backlog、nack を観測する。

### 例
永続化は PostgreSQL に閉じ、`IMessageBus` を含む依存は constructor で受ける。token を受けない API の直前で取り消しを確認する。inbox は payload の durable commit、delivery ack、外部効果、処理済み記録、完了の順に進める。

```csharp
builder.UseWolverine(options => options.PersistMessagesWithPostgresql(connectionString));
public sealed class ShipOrderHandler(IOrderRepository repository, IMessageBus bus)
{
    public async Task HandleAsync(ShipOrder message, CancellationToken cancellationToken)
    {
        await repository.MarkShippedAsync(message.OrderId, cancellationToken);
        cancellationToken.ThrowIfCancellationRequested();
        await bus.ScheduleAsync(new ConfirmDelivery(message.OrderId), 3.Days());
    }
}

public sealed class ProjectionHandler(IDurableInbox inbox, IEventSource source, IPaymentPort payment)
{
    public async Task HandleAsync(ProjectOrder message, CancellationToken cancellationToken)
    {
        var permit = await inbox.TryReserveAsync(cancellationToken) ?? throw new RetryableReceiveException();
        var item = await inbox.CommitPayloadAsync(permit, message, cancellationToken);
        await source.DeliveryAckAsync(message.Id, cancellationToken);
        var effectKey = EffectKey.Create("capture-payment", message.Id);
        await payment.CaptureAsync(message.Amount, effectKey, cancellationToken);
        await inbox.RecordProcessedAsync(item, cancellationToken);
        await inbox.CompleteAsync(item, cancellationToken);
    }
}
```
