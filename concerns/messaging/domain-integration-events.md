## domain event と integration event を分ける

### 要求
コンテキストの内で起きた事実を表す domain event と、コンテキストの外へ公開する integration event を分け、同じ型として扱わない。
イベントは、過去に起きた事実を表す。
イベントの型を置くことは、業務事実としての保持、outbox への記録、外部への配送、イベント列からの状態の復元のいずれも約束せず、それぞれを別の契約で決める。
保持は [data](../../principles/data/preserve-facts-and-current-state.md) の「業務事実と現在情報を分けて保持する」に、outbox への記録は [transaction](../transaction/state-event-atomicity.md) の「状態とイベントを同一パスで記録する」に、配送は [outbox-delivery](./outbox-delivery.md) の「outbox から配送する」に従う。

### 根拠
domain event は内部の語彙と詳細を含み、そのまま外へ出すと内部都合が漏れて結合する。
integration event を別の型にし、公開する分だけに絞れば、内部の変更が外部へ波及しない。
イベントは過去の事実なので、未来への命令でなく、起きたことを表す名前にする。
イベントの型があることを保持や配送の保証と読むと、保持の契約のない出来事が履歴に残り、保持の契約のある事実が outbox の削除で失われ、配送が不要な連携に非同期の複雑さを持ち込む。

### 完了条件
domain event と integration event が、別の型である。
外部へ公開されるのが、integration event だけである。
イベント名が、過去の事実を表している。
イベントの型の有無と、業務事実の保持、outbox への記録、配送、状態の正本とするかの採否が、別々に決められている。

### 禁止事項
domain event を、そのまま外部へ公開すること。
イベントを、未来への命令として表すこと。
イベントの型があることだけを理由に、業務事実として保持し、outbox へ記録し、外部へ配送し、またはイベント列を状態の正本にすること。

### 行動
公開するイベントを integration event として定義し、domain event から必要な分だけ写す。
イベント名を、起きた事実を表す過去の形にする。
イベントごとに、保持の契約、公開の有無、配送の要否、状態の正本とするかを別々に確かめる。

### 例

内部の domain event をそのまま公開すると、外部契約へ内部都合が漏れる。

```
publish(order.domainEvents)
```

公開用の integration event へ変換し、過去の事実を表す情報だけを公開する。

```
publish(OrderPlaced.from(order))
```
