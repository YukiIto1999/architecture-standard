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
