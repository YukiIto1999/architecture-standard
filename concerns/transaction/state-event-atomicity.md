## 状態とイベントを同一パスで記録する

### 要求
現在情報の変更または消去、保持が必要な業務事実の追記、公開する integration event の outbox への記録を、同一の書き込みパスの一つの transaction にまとめる。
保持が必要な業務事実は、保持期間を定めた業務事実の関係へ追記し、outbox を業務事実の保存先にしない。
integration event は outbox に記録し、配送は別途行う。
業務事実を持たない変更に業務事実の追記を足さず、公開する integration event を持たない変更に outbox の行を足さない。
異なる datastore への移行では、現在の正本への write と migration event の outbox への記録を、現在の正本と同じ transaction で確定する。

### 根拠
現在情報を変更する経路と業務事実を追記する経路が別々だと、片方だけ成功して食い違い、退会の事実だけが残って現在関係が消えていない、または現在関係だけが消えて退会の事実がない状態になる。
業務事実は保持の契約を負う正本の一部であり、outbox は配送のための記録であって、配送済みの印の更新と配送後の削除を伴う。
一つの行で兼ねると、配送の都合で業務事実が書き換わるか消えるか、業務事実の不変性のために配送の記録が溜まり続ける。
同一トランザクションで現在情報と outbox に記録すれば、現在情報と公開するイベントは必ず一致する。
異なる datastore へ同期に dual write せず、現在の正本と outbox だけを同じ transaction で確定すれば、destination の停止を再配送で回復できる。
配送を記録の後に別途行えば、確実な記録と配送の責務を分けられる。
domain event と integration event の区別は [messaging](../messaging/domain-integration-events.md) に従う。

### 完了条件
現在情報の変更または消去と、保持が必要な業務事実の追記が、同一の書き込みパスの一つの transaction にあり、二つの間に失敗を注入すると、両方が確定するか両方が確定しない。
現在情報の変更・参照の更新と、公開する integration event の outbox への記録が、同一の書き込みパスにある。
業務事実の関係と outbox が別の関係であり、outbox の配送済みの更新と削除が業務事実の行に及ばない。
異なる datastore への migration event が、現在の正本への write と同じ transaction で outbox に記録されている。

### 禁止事項
現在情報と業務事実を別々の確定点で確定する禁止は、[data](../../principles/data/preserve-facts-and-current-state.md) の禁止事項に従う。
状態の変更と outbox への記録を、別々の書き込みパスへ分けること。
outbox の記録を経ずに、イベントを配送すること。
outbox の行を業務事実として保持し、配送済みの印の更新や配送後の削除で業務事実の保持を左右すること。
異なる datastore の新旧へ、調整なしに同期 dual write すること。

### 行動
現在情報の変更または消去、保持が必要な業務事実の追記、公開する integration event の outbox への記録を、一つのトランザクションにまとめる。
変更ごとに、契約が保持を求める業務事実があるか、公開する integration event があるかを確かめ、ある分だけを同じトランザクションへ置く。
消去を伴う変更では、消す現在情報の削除件数を確かめ、想定した件数でなければ業務事実の追記を含めて確定しない。
異なる datastore への移行では、現在の正本への write と migration event の outbox 記録だけを同じ transaction へ置き、destination へ冪等に再配送する。
配送は [messaging](../messaging/outbox-delivery.md) に従う。

### 例

現在関係の削除と退会の業務事実の追記を別々に確定すると、二つの間で停止したときに、現在関係が消えたのに退会の事実がなく、再実行でも判定できない。

```sql
DELETE FROM active_users WHERE user_id = :user_id;
COMMIT;
INSERT INTO user_withdrawals (user_id, withdrawn_at) VALUES (:user_id, CURRENT_TIMESTAMP);
COMMIT;
```

現在関係の削除、退会の業務事実の追記、公開する integration event の outbox への記録を、同じトランザクションで確定する。
削除した行が0件なら、確定せずに失敗させる。
業務事実は `user_withdrawals` に保持し、outbox の行は配送済みの印を付けた後に消えても業務事実に影響しない。

```sql
BEGIN;
  SELECT id FROM users WHERE id = :user_id FOR UPDATE;
  DELETE FROM active_users WHERE user_id = :user_id;
  INSERT INTO user_withdrawals (user_id, withdrawn_at) VALUES (:user_id, CURRENT_TIMESTAMP);
  INSERT INTO outbox (event_type, payload, occurred_at) VALUES ('UserWithdrawn', :payload, CURRENT_TIMESTAMP);
COMMIT;
```

別のプロセスが outbox を読み、配送済みの印を付ける。
