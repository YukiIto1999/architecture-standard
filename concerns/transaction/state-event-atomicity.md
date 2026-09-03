## 状態とイベントを同一パスで記録する

### 要求
状態の変更と、その結果として公開する integration event の記録を、同一の書き込みパスにまとめる。
integration event は outbox に記録し、配送は別途行う。
異なる datastore への移行では、現在の正本への write と migration event の outbox への記録を、現在の正本と同じ transaction で確定する。

### 根拠
状態の保存とイベントの発行を別々の経路で行うと、片方だけ成功して食い違う。
同一トランザクションで状態と outbox に記録すれば、状態とイベントは必ず一致する。
異なる datastore へ同期に dual write せず、現在の正本と outbox だけを同じ transaction で確定すれば、destination の停止を再配送で回復できる。
配送を記録の後に別途行えば、確実な記録と配送の責務を分けられる。
domain event と integration event の区別は [messaging](../messaging/domain-integration-events.md) に従う。

### 完了条件
状態の変更・参照の更新と、公開する integration event の outbox への記録が、同一の書き込みパスにある。
異なる datastore への migration event が、現在の正本への write と同じ transaction で outbox に記録されている。

### 禁止事項
状態の変更とイベントの記録を、別々の書き込みパスへ分けること。
outbox の記録を経ずに、イベントを配送すること。
異なる datastore の新旧へ、調整なしに同期 dual write すること。

### 行動
状態の変更と outbox への記録を、一つのトランザクションにまとめる。
異なる datastore への移行では、現在の正本への write と migration event の outbox 記録だけを同じ transaction へ置き、destination へ冪等に再配送する。
配送は [messaging](../messaging/outbox-delivery.md) に従う。

### 例

状態とイベントを同じトランザクションで記録し、二重書き込みを避ける。

```sql
BEGIN;
  INSERT INTO orders ...;
  INSERT INTO outbox (event_type, payload, occurred_at) VALUES ('OrderPlaced', ...);
COMMIT;
```

別のプロセスが outbox を読み、配送済みの印を付ける。
