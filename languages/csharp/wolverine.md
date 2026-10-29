# Wolverine

用途は、背景処理の durable な queue と、業務のデータが決める時刻の予約の骨格である。
採用は、C# は Wolverine であり、PostgreSQL を backend にした queue に限って使う。
判断基準は、queue と予約を既存の datastore に閉じ、外部の broker を開かないことである。
撤回条件は、判断基準を満たさなくなることであり、backend の対応状況の変化、保守の停止、採用している .NET の版を target しなくなることを再評価のトリガーとする。

## worker

### 要求
worker は Wolverine を、PostgreSQL の queue と、業務のデータが決める時刻の予約に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
予約は、`IMessageBus` の `ScheduleAsync` で PostgreSQL の durable な scheduled message として積み、同じ業務事実から導いた冪等の鍵で二重に積まない。
message store の登録だけでなく、予約先の local queue に `UseDurableInbox()` を設定する。
予約の冪等の鍵は PostgreSQL の一意制約で保護し、予約を要求する記録と業務の更新は同じ transaction の outbox へ記録する。
固定の時刻と間隔による定期実行は、cron 式の scheduler の package で組まず、OS の定時起動から [worker](../../structure/surfaces/worker/layout.md) の「定時起動」の入口が受ける。
handler の依存は、`IMessageBus` を含め constructor で受け取る。
handler で、実行時の IoC 解決を使わない。
handler は CancellationToken を受け取り、token を受ける全ての非同期 API へ渡す。
再配送契約を持つ source の event は durable inbox の容量を予約し、payload の commit 後だけ upstream delivery ack を返す。
inbox processing completion と処理 item の削除は、処理結果と処理済み記録の commit 後だけ行う。
外部効果には、配備上の consumer 名に依存しない安定した effect operation の識別子と event ID から作る冪等キーを渡す。
外部効果が成功した後に処理済み記録を commit し、その後に inbox processing completion を行う。
durable inbox が満杯なら nack または再試行可能な失敗を返し、使用量、上限、backlog、nack を監視へ出す。
queue と予約の message の payload は、[translation](./translation.md) に従い、公開入力と同じ decode と検証を、Wolverine が durable な store から message を受けて handler を起動する実際の受信経路で、業務処理を始める前に通す。
必須項目の欠落、契約が許さない null、既知項目の値の不正、判別子と payload の不一致の message は、既定値を補わず、handler の業務処理を始めず、回復しない失敗として [resilience](../../concerns/resilience/dead-letter-exit.md) の「再試行の出口を持つ」に従い行き止まりへ送る。
既知の契約を満たす message に未知の追加フィールドだけを加えた場合は、translation に従って受容し、既知項目の検証を保つ。
一時的な旧版対応の撤去は、[messaging](../../concerns/messaging/event-contract-versioning.md) の「イベント契約を版で進化させ、寛容に読む」が定める発行と再投入の停止と未完了の旧版の不在の確認に従う。
その確認は、予約した message を含め、messaging が挙げる各経路の未完了の旧版を Wolverine が保持する実際の状態に対して行い、queue が空に見えることを旧版の不在の根拠にしない。

### 根拠
queue と予約を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
予約を durable な scheduled message として PostgreSQL に積めば、停止の後も失われず、再配送の対象になる。
local queue の既定は in-memory なので、message store の登録だけでは予約先が durable にならず、queue の設定も必要である。
予約の鍵の一意性と outbox を同じ transaction に載せれば、再配送で業務の更新だけ、または予約だけが二度確定することを防げる。
固定の時刻と間隔の起動を OS が担えば、worker の内部に cron 式の scheduler を足さずに済み、起動の合図の重複と欠落は定時起動の入口の冪等で吸収できる。
handler の依存を constructor で受ければ、依存がシグネチャに現れる。
`IMessageBus` を method parameter で受けず constructor に揃えると、handler の依存が一箇所に現れる。
CancellationToken を下流へ渡せば、worker の停止と期限切れが非同期処理の末端まで伝わる。
実行時の IoC 解決は、依存をシグネチャから隠し、コンパイル時の誤りを実行時へ遅らせる。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。
payload commit 後だけ upstream delivery ack を返せば、前段の停止で未確定になった event を source から再配送できる。
処理結果と処理済み記録の commit 後だけ inbox processing completion を行えば、後段の停止で item を再処理できる。
外部効果の境界へ安定した冪等キーを渡せば、効果成功後から処理済み記録前の停止でも再配送の結果を一度分にできる。
容量を予約できない event を nack すれば、必要な入力を受領済みとして失わない。
payload の検証を durable な store から受ける実際の受信経路に置けば、再配送や予約の実行で取り出された message も、公開入力と同じ保証を満たす。
handler を直接呼ぶ検査は受信経路の decode と拒否を通らないので、既定値で補われた入力が業務処理へ届く欠陥を見逃す。
予約した message は実行時刻まで store に残るので、queue が空に見えても、予約や再投入の経路に旧版が残りうる。

### 完了条件
worker が、Wolverine を PostgreSQL の queue と、業務のデータが決める時刻の予約に限って使っている。
handler の依存が、`IMessageBus` を含め constructor で受け取られている。
handler で、実行時の IoC 解決が使われていない。
CancellationToken が、token を受ける全ての非同期 API へ渡されている。
broker・durable workflow・外部の message bus として、使われていない。
予約した message が、実行時刻の前に処理されず、停止の後も失われず、実行時刻の後に処理されることと、同じ業務事実から二度積んでも一つの message になることが、実行テストで検証されている。
予約先の local queue が durable に設定され、予約の鍵の一意制約と outbox の記録が業務の更新と同じ transaction で確定している。
NuGet 依存に、cron 式の scheduler の package がない。
固定の時刻と間隔の起動が、OS の定時起動と worker の定時起動の入口で行われている。
upstream delivery ack が、payload の durable inbox への commit 後だけ返されている。
inbox processing completion と処理 item の削除が、処理結果と処理済み記録の commit 後だけ行われている。
外部効果に安定した effect operation の識別子と event ID から作った冪等キーが渡され、効果成功後に処理済み記録が確定している。
payload commit と、外部効果成功と、処理済み記録 commit の各前後で停止して再配送しても、結果が一度分になることが実行テストで検証されている。
durable inbox の容量上限で nack または再試行可能な失敗が返され、使用量、上限、backlog、nack が監視されている。
必須項目の欠落、契約が許さない null、既知項目の不正、判別子と payload の不一致の message を実際の受信経路へ渡すと、既定値で補われず、handler の業務処理が始まらず、業務の状態と outbox が変わらず、行き止まりへ送られることが、実行テストで検証されている。
既知の契約を満たす message に未知の追加フィールドだけを加えても同じ経路で受容され、既知項目の欠落や不正の拒否が失われていないことが、実行テストで検証されている。
一時的な旧版対応を撤去した場合は、messaging が挙げる各経路について、Wolverine が保持する実際の状態に未完了の旧版が残らないことの検査結果が対応している。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
固定の時刻と間隔の起動のために、cron 式の scheduler の package を worker の中へ追加すること。
handler で、実行時に IoC から依存を解決すること。
`IMessageBus` を、handler method の parameter で受け取ること。
token を受ける非同期 API への CancellationToken の伝播を途切れさせること。
payload の durable inbox への commit 前に、upstream delivery ack を返すこと。
処理結果と処理済み記録の commit 前に、inbox processing completion または処理 item の削除を行うこと。
外部効果の成功前に、処理済みを記録すること。
配備上の consumer 名を、外部効果の冪等キーに使うこと。
durable inbox が満杯の event を受領済みとして捨てること。
必須項目の欠落や契約が許さない null を持つ message に既定値を補い、handler の業務処理を始めること。
queue が空に見えることだけを根拠に、予約や再投入の経路に旧版の message が残らないとみなすこと。
handler を直接呼ぶ検査だけで、実際の受信経路の拒否と業務処理の非開始を検証済みとみなすこと。

### 行動
永続化を PostgreSQL に限り、`IMessageBus` を含む handler の依存を constructor で受ける。
予約先の local queue に `UseDurableInbox()` を設定し、予約の鍵の一意制約と outbox の記録を業務の更新と同じ transaction に含める。
handler の CancellationToken を、token を受ける全ての非同期 API へ渡す。
業務のデータが決める時刻の予約は、`IMessageBus` の `ScheduleAsync` で積み、同じ業務事実から導いた冪等の鍵を付ける。
固定の時刻と間隔の起動は OS の宣言へ置き、worker には cron 式の scheduler を追加しない。
受領時に durable inbox の容量を予約し、payload を commit してから upstream delivery ack を返す。
処理結果と処理済み記録を retention の同じ transaction で確定してから、inbox processing completion を行う。
外部効果へ安定した effect operation の識別子と event ID の組を冪等キーとして渡し、成功後に処理済み記録を commit する。
payload commit、外部効果成功、処理済み記録 commit の各直前と直後へ停止を注入し、再配送後の結果が一度分であることをテストする。
容量を予約できない場合は nack または再試行可能な失敗を返し、inbox の使用量、上限、backlog、nack を観測する。
payload の decode と検証を handler の業務処理より前に置き、拒否した message は既定値で補わず行き止まりへ送る。
必須項目の欠落、契約が許さない null、既知項目の不正、判別子の不一致の message と、未知の追加フィールドだけを加えた message を、store から受けて handler を起動する実際の受信経路へ別々に渡し、前者の拒否と業務処理の非開始、後者の受容を観測する。
一時的な旧版対応を撤去する前に、旧版の発行と再投入を止め、予約を含む各経路の実際の状態を messaging の確認に従って検査する。

### 例
出荷確定から三日後の確認を予約するとき、受信時刻から三日を足さず、出荷が確定した業務事実の時刻から予約時刻を決める。
出荷確定の event ID と確認という operation から予約の鍵を作り、業務の更新と同じ transaction で、一意制約を持つ予約要求と outbox の記録を確定する。
同じ event が再配送されても、最初に確定した予約の鍵と時刻を使い、別の予約を追加しない。
予約先を durable に設定した queue に対し、予約の確定直後に process を停止して再起動しても、予約時刻の前には処理されず、時刻の後に確認の結果が一度分だけ確定することを検証する。
