# messaging

## 概要
messaging は、イベントによる連携を全系で統べる規律である。
principles の [data](../principles/data.md) が定める複数集約の結果整合性と、[separation](../principles/separation.md) が定める契約の独立を、全系のイベント連携として具象化する。
手順の所有と補償の正本は [workflow](./workflow.md) であり、messaging は event の契約と配送・消費を書く。

## domain event と integration event を分ける

### 要求
コンテキストの内で起きた事実を表す domain event と、コンテキストの外へ公開する integration event を分け、同じ型として扱わない。
イベントは、過去に起きた事実を表す。

### 根拠
domain event は内部の語彙と詳細を含み、そのまま外へ出すと内部都合が漏れて結合する。
integration event を別の型にし、公開する分だけに絞れば、内部の変更が外部へ波及しない。
イベントは過去の事実なので、未来への命令でなく、起きたことを表す名前にする。

### 完了条件
domain event と integration event が、別の型である。
外部へ公開されるのが、integration event だけである。
イベント名が、過去の事実を表している。

### 禁止事項
domain event を、そのまま外部へ公開すること。
イベントを、未来への命令として表すこと。

### 行動
公開するイベントを integration event として定義し、domain event から必要な分だけ写す。
イベント名を、起きた事実を表す過去の形にする。

### 例

内部の domain event をそのまま公開すると、外部契約へ内部都合が漏れる。

```
publish(order.domainEvents)
```

公開用の integration event へ変換し、過去の事実を表す情報だけを公開する。

```
publish(OrderPlaced.from(order))
```

## 同期で済む連携はイベントにしない

### 要求
同期で完結できる連携はイベントにせず同期で扱い、非同期の連携が必要な場合に限りイベントを用いる。

### 根拠
イベントは、結果整合性・配送・順序・重複という複雑さを連れてくる。
同期で足りる連携をイベントにすると、その複雑さを不要に負う。
即時の整合や応答が要るなら同期、疎結合や時間的な分離が要るならイベントにする。

### 完了条件
即時の整合や応答が要る連携が、同期で扱われている。
イベントが、非同期の連携に限って使われている。

### 禁止事項
同期で足りる連携を、イベントにすること。

### 行動
連携ごとに、即時の整合や応答が要るかを問う。
要れば同期、要らなければイベントにする。

## outbox から配送する

### 要求
integration event の記録は [transaction](./transaction.md) の outbox に従い、配送は outbox から読み出して行う。
記録と配送を分け、配送は少なくとも一度として扱う。

### 根拠
記録と配送を同じ経路で行うと、配送の失敗が記録の確定を巻き込む。
記録を transaction の outbox に確定させ、配送を別に行えば、確実な記録と再試行できる配送に分けられる。
配送は分散した経路を通るので、少なくとも一度として扱い、重複は消費側の冪等で吸収する。

### 完了条件
integration event の記録が、transaction の outbox に従っている。
配送が、outbox から読み出して行われ、記録と分かれている。

### 禁止事項
記録と配送を同じ経路に混ぜ、配送の失敗で記録の確定を巻き込むこと。

### 行動
記録は transaction の outbox に委ね、配送は outbox を読み出して行う。

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
冪等そのものの理由は [resilience](./resilience.md) に従う。
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

## 順序・再試行・行き止まりを扱う

### 要求
順序は同じ集約の中の版の並びとしてのみ保証し、全体の順序を約束しない。
新しいイベントが完全な現在状態を含む snapshot 型の現在状態 projection は、集約の版を比べて古い snapshot を捨ててよい。
正本から再構築できる現在状態 projection は、再構築を確実に起動する場合に限り、古い版を捨ててよい。
差分イベントを適用する projection は、版の欠落を検出し、順序待ち、replay、rebuild のいずれかで回復する。
差分イベントを、古い版または欠落した版であることだけを理由に黙って捨てない。
事実を蓄積する consumer は、イベントの識別子で重複排除し、到着した版が現在より古いことだけを理由に事実を捨てない。
事実の保持と消去は、[privacy](./privacy.md) などの別の保持・消去規律に従う。
snapshot event を監査または集計の事実として扱う consumer にも、同じ版と保持・消去の規則を適用する。
失敗したイベントの再試行と行き止まりは [resilience](./resilience.md) に従い、行き止まりへ送ったイベントで後続の消費を止めない。

### 根拠
全体の順序を保証すると、並行性と規模を失う。
順序が要るのは同じ集約の中だけなので、その範囲で保証する。
完全な現在状態を含む snapshot は古い版を無視しても、新しい版だけで現在状態が決まる。
正本から再構築できる projection は、古い版を捨てても rebuild で正しい状態へ戻せる。
差分イベントは前の版を前提にするため、欠落した版を捨てると projection が正しい状態へ到達できない。
事実を蓄積する consumer は到着した各事実を意味として持つため、現在より古い版を捨てると履歴が欠ける。
版の順序を扱う規則と保持期間を扱う規則を分ければ、古い版を捨てずに扱う要求が privacy に基づく期限消去を妨げない。
snapshot event でも監査または集計の入力にする場合は、現在状態 projection の上書き規則を適用すると必要な事実を失う。
イベントの消費は列を共有するので、一つのイベントの滞留が後続の消費を塞ぐ。
行き止まりへ退ければ、後続が流れ続ける。

### 完了条件
順序の保証が、同じ集約の中の版の並びに限られている。
古い版を捨てる現在状態 projection が、完全な現在状態を含む snapshot 型か、正本から再構築できる形に限られている。
再構築できる現在状態 projection が古い版を捨てた場合、rebuild が起動している。
差分イベントを適用する projection が、版の欠落を検出して順序待ち、replay、rebuild のいずれかで回復している。
事実を蓄積する consumer が、到着した版が現在より古いことだけを理由に事実を捨てていない。
事実を蓄積する consumer の保持と消去が、privacy などの別の規律に従っている。
snapshot event を監査または集計する consumer にも、同じ版と保持・消去の規則が適用されている。
行き止まりへ送られたイベントの後続が、消費され続けている。

### 禁止事項
全体の順序を、約束すること。
完全な現在状態を持たず再構築もできない projection で、古い版を捨てること。
差分イベントの欠落を検出せず、または検出後に黙って捨てること。
事実を蓄積する consumer で、到着した版が現在より古いことだけを理由に事実を捨てること。
snapshot event を監査または集計する consumer に、現在状態 projection の古い版を捨てる規則を適用すること。
privacy などの保持・消去規律に反して、事実を保持し続けること。
処理できないイベントで、後続の消費を止め続けること。

### 行動
順序が要る範囲を、同じ集約に限る。
consumer が現在状態 projection か、事実を蓄積する consumer かを分類する。
現在状態 projection が完全な現在状態を含む snapshot 型か、正本から再構築できるかを判定する。
現在状態 projection がどちらかを満たす場合だけ、古い版を捨てる。
差分イベントの版が欠落したら、順序待ち、replay、rebuild から回復方法を選ぶ。
事実を蓄積する consumer は、イベントの識別子で重複排除し、到着した版が現在より古いことだけでは捨てない。
事実を蓄積する consumer の保持期間と消去方法を、privacy などの別の規律から定める。
snapshot event を監査または集計する場合にも、同じ版と保持・消去の規則を使う。
再試行の上限と行き止まりの手順は [resilience](./resilience.md) に従い、行き止まりへ送って後続を流す。

### 例

privacy が定める保存期限を過ぎた event は破棄する。現在より古い version であることだけを理由には破棄しない。

```
onAccumulatedFact(event) {
  if (seen(event.id)) return
  if (privacyRetention.expired(event)) return
  appendFact(event)
}
```

## イベント契約を版で進化させ、寛容に読む

### 要求
イベントの契約は版で進化させ、消費側は使う項目だけを読み、未知の項目を無視する。
振り分けの分岐は、発行の側に置く。

### 根拠
契約を一斉に変えると、全ての消費側が壊れる。
契約の版を併存させ、消費側が使う分だけ読み未知を無視すれば、生産側と消費側が独立に進化できる。
振り分けの分岐は発行の側に寄せ、消費側は自分宛ての意味だけを扱う単純さを保つ。

### 完了条件
イベント契約が版で進化し、新旧が一時併存できる。
消費側が、使う項目だけを読み、未知の項目を無視している。
振り分けの分岐が、発行の側に置かれている。

### 禁止事項
契約を、消費側を壊す形で一斉に変えること。
消費側が、使わない項目にまで結合すること。
振り分けの分岐を、消費側に持たせること。

### 行動
契約に版を持たせ、消費側を寛容な読み手にする。

## 参照
outbox の書き込みは [transaction](./transaction.md)、冪等・再試行・行き止まりの正本は [resilience](./resilience.md)、契約の独立は [separation](../principles/separation.md) に従う。
手順の所有と補償の正本は [workflow](./workflow.md) であり、messaging は event の契約と配送・消費を書く。
言語別の実現は [tools](../tools/) が定める。
