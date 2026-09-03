## 少なくとも一度の配送を前提に冪等に消費する

### 要求
配送経路は少なくとも一度の配送として扱い、消費側は同じイベントの再配送で重複した結果を生まないようにする。
durable receipt は、payload を durable inbox へ commit してから upstream delivery ack を返すまでの受領段階とする。
consumer は、durable receipt を終えてから処理を始める。
durable receipt と、処理結果および処理済み記録の確定は、別の段階として扱う。
同じ datastore に書く結果は、consumer contract または subscription の scope とイベントの識別子の組で処理権を取得する。
consumer contract または subscription の scope は、配備上の consumer の改名、再作成、移行で変えない。
処理権は、共有 inbox の複合一意制約か、scope ごとの inbox にあるイベント識別子の一意制約で排他する。
処理権の取得に成功した場合だけ結果を書き、処理済み記録と同じ transaction で確定する。
外部効果には、安定した effect operation の識別子とイベントの識別子から作る冪等キーを渡す。
effect operation の識別子は、配備上の consumer の名前を含めず、改名、再作成、移行で変えない。
外部効果の成功後に、consumer contract または subscription の scope へ処理済みを記録する。

### 根拠
一度きりの配送は、分散した経路では保証できない。
配送そのものを一度きりにはできないが、消費を冪等にすれば結果は一度分になる。
durable receipt を処理の確定から分ければ、前段の停止は source の再配送で、後段の停止は inbox item の再処理で回復できる。
冪等そのものの理由は [resilience](../resilience/idempotent-operations.md) に従う。
consumer contract または subscription の scope を含めれば、同じイベントに独立して反応する別の契約を重複として扱わずに済む。
consumer contract または subscription の scope とイベントの識別子の組を一意にすれば、同じ契約への再配送だけを排除できる。
scope ごとに inbox を分ける場合は、その inbox の中でイベントの識別子を一意にすれば同じ排他になる。
配備上の名前と処理権の scope を分ければ、consumer の置き換えで同じイベントを未処理と誤認しない。
処理権の取得、同じ datastore の結果、処理済み記録を一つの transaction で確定すれば、結果だけ、または記録だけが残る停止点を作らない。
外部効果と処理済み記録は一つの transaction にできないため、効果境界が effect operation の識別子とイベントの識別子から作った冪等キーで重複を吸収する。
effect operation の識別子を配備上の名前から分離すれば、consumer の置き換え後も効果境界へ同じ冪等キーを渡せる。
外部効果の成功後に停止しても、再配送時の効果境界が同じ結果を返し、その後に処理済みを記録できる。

### 完了条件
消費が、再配送を前提にしている。
payload の durable inbox への commit 後に upstream delivery ack が返され、その後に consumer が処理を始めている。
durable receipt と、処理結果および処理済み記録の確定が、別の段階になっている。
consumer contract または subscription の scope とイベントの識別子の組が、inbox の冪等キーとして使われている。
consumer contract または subscription の scope が、配備上の consumer の改名、再作成、移行で変わっていない。
同じ datastore では、共有 inbox の複合一意制約か scope ごとの inbox の一意制約で処理権を取得した消費だけが結果を書いている。
処理権の取得、結果、処理済み記録が、一つの transaction で確定している。
外部効果に、安定した effect operation の識別子とイベントの識別子から作った冪等キーが渡されている。
effect operation の識別子が、配備上の consumer の改名、再作成、移行で変わっていない。
外部効果の成功後に、consumer contract または subscription の scope へ処理済みが記録されている。
各確定点で停止して再配送しても、結果が一度分である。

### 禁止事項
一度きりの配送を、約束すること。
broker の一度きりの表示を理由に、外部への副作用の冪等な消費を省くこと。
再配送で重複した結果を生む消費を書くこと。
payload の durable inbox への commit 前に upstream delivery ack を返すこと。
durable receipt の前に consumer の処理を始めること。
upstream delivery ack を、処理結果と処理済み記録の確定として扱うこと。
同じ datastore の結果と処理済み記録を、別の transaction で確定すること。
処理済み記録の参照だけで判定し、consumer contract または subscription の scope とイベントの識別子による処理権の排他を持たないこと。
共有 inbox で、イベントの識別子だけを一意にすること。
配備上の consumer の名前を、inbox の scope または外部効果の冪等キーに使うこと。
外部効果へ effect operation の識別子とイベントの識別子から作った冪等キーを渡さず、効果境界の外だけで重複を排除すること。
外部効果の成功前に、処理済みを記録すること。

### 行動
consumer contract または subscription に、配備上の consumer の改名、再作成、移行で変わらない scope を定める。
payload を durable inbox へ commit し、upstream delivery ack を返してから consumer の処理を始める。
同じ datastore に書く結果は、共有 inbox の scope とイベントの識別子に複合一意制約を置くか、scope ごとの inbox でイベントの識別子を一意にする。
一意な処理済み記録の挿入で処理権を取得し、取得に成功した場合だけ結果を書いて、一つの transaction で確定する。
外部効果ごとに、配備上の consumer の名前から独立した effect operation の識別子を定める。
外部効果には effect operation の識別子とイベントの識別子から作る冪等キーを渡し、成功を確認してから scope へ処理済みを記録する。
payload commit と upstream delivery ack の各直前と直後、同じ datastore の transaction commit、外部効果の成功、成功後の処理済み記録の各直前と直後で処理を停止し、前段では source から、後段では inbox item から再配送して結果が一度分であることをテストする。

### 例

共有 inbox は、consumer contract または subscription の安定した scope と event ID の組を一意にする。

```
processed_events(consumer_scope, event_id, UNIQUE(consumer_scope, event_id))
onProjected(event) {
  transaction {
    if (!tryInsertProcessed(consumerScope, event.id)) return
    updateProjection(event)
  }
}
```

外部効果は、配備名ではなく安定した operation と event ID の組で冪等化する。

```
onPaid(event) {
  if (isProcessed(consumerScope, event.id)) return
  charge(event.amount, idempotencyKey: [effectOperation("capture-payment"), event.id])
  recordProcessed(consumerScope, event.id)
}
```
