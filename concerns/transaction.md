# transaction

## 概要
transaction は、書き込みパスの一貫性と確定点を全系で統べる規律である。
principles の [data](../principles/data.md) が定める整合性と集約境界、事実の追記と現在状態の導出を、全系の書き込みの扱いとして具象化する。
transaction は書き込みパスの動的な確定を扱い、静止した関係と制約は [persistence](./persistence.md) が扱う。

## 整合性を一つの書き込みパスに閉じる

### 要求
同時に守らなければ不正となる整合性は、一つの書き込みパスに閉じる。
その範囲を一つの集約に一致させ、複数の集約にまたがる整合性はイベントによる結果整合性で保つ。
同じ集約への同時の更新は、版の衝突として検出する。

### 根拠
集約とトランザクション境界の一致の理由は [data](../principles/data.md) に従う。
同じ集約を同時に更新すると、後の書き込みが前の更新を失わせる。
版を確かめて確定すれば、間に変わった更新を検出して失わない。
版の衝突として検出できることは、同時に競合が起きた事実を書き込みパスの外へ露わにする。

### 完了条件
同時に守る整合性が、一つの書き込みパスの内で検証されている。
同じ集約への同時の更新が、版の衝突として検出され、片方の更新を失わない。
版の衝突の検出が、事実を追記する関係への同じ版の重複の追記を一意制約で拒む形で行われている。

### 禁止事項
同時に守る整合性の判断を、複数の書き込みパスへ分けること。
一つの書き込みパスの確定で、複数の集約を同時に変更すること。

### 行動
同時に守る不変条件を洗い出し、一つの集約と一つの書き込みパスに収める。
同じ集約の同時の更新は、次の版を事実として追記し、版の一意制約の違反を衝突として検出する。

### 例

一度の書き込みで複数の集約を変更すると、競合と結合が増える。

```
transaction { order.place(); inventory.reserve(); }
```

一つの集約だけを変更し、`OrderPlaced` を outbox へ記録する。在庫は別集約のトランザクションでイベントを受け、結果整合的に引き当てる。

```
transaction { order.place() }
```

## 一つの確定点を持つ

### 要求
書き込みパスは一つの確定点を持ち、確定より前の状態を成功として外部へ公開しない。

### 根拠
確定点が一つなら、成功と失敗の境目が明確になる。
確定前の状態を公開すると、後で巻き戻したときに外部が誤った前提を持つ。

### 完了条件
書き込みパスに、確定点が一つある。
確定より前の状態が、成功として外部へ公開されていない。

### 禁止事項
確定の前に、外部の効果を直接実行すること。
確定していない状態を、成功として外部へ見せること。

### 行動
書き込みを一つの確定点にまとめる。
外部への効果は確定の後に起こし、巻き戻せない効果や取りこぼせない効果は outbox 経由で確実にする。

### 例

確定前にメールを送ると、その後にロールバックしても送信を取り消せない。

```
send(mail); transaction.commit()
```

外部効果は確定後に起こす。メールの配送要求を状態と同じトランザクションで outbox へ記録し、確定後に配送する。

```
transaction { record(order); outbox.add(MailRequested) }
```

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
domain event と integration event の区別は [messaging](./messaging.md) に従う。

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
配送は [messaging](./messaging.md) に従う。

### 例

状態とイベントを同じトランザクションで記録し、二重書き込みを避ける。

```sql
BEGIN;
  INSERT INTO orders ...;
  INSERT INTO outbox (event_type, payload, occurred_at) VALUES ('OrderPlaced', ...);
COMMIT;
```

別のプロセスが outbox を読み、配送済みの印を付ける。

## 冪等にして再実行できるようにする

### 要求
冪等の key は、operation、actor、tenant で scope する。
operation、actor、tenant、key の組を、データ層の一意制約で記録する。
operation、actor、tenant、key の列は、すべて NOT NULL にする。
認証済みの要求は、検証済みの actor ID を actor scope に使う。
匿名の要求は、session または client ごとの安定した opaque ID を actor scope に使う。
system の要求は、logical actor ごとの安定した ID を actor scope に使う。
multi-tenant operation は、境界で検証した tenant context から構築した `TenantId` を tenant scope に使う。
single-tenant operation は、正準な single-tenant sentinel を tenant scope に使う。
tenant の概念を持たない operation は、正準な no-tenant sentinel を tenant scope に使う。
`TenantId`、single-tenant sentinel、no-tenant sentinel を相互に混同しない。
session または client の scope を持たない匿名の要求は、server が発行した全体で一意な key に限定する。
scope を持たない匿名の要求では、保存した応答を key の発行時に渡した proof を検証した要求者にだけ返す。
初回の要求では、request fingerprint と応答を冪等の鍵と同じ確定点で保存する。
同じ scope と key で同じ意図を再実行したときは、保存した初回の応答を返す。
同じ scope と key で異なる意図を要求したときは、conflict を返す。

### 根拠
冪等そのものの理由は [resilience](./resilience.md) に従う。
書き込みパスで適用済みの鍵をデータ層の一意制約に記録すれば、同時に届いた重複要求も確実に一方だけが本体の書き込みへ進む。
operation、actor、tenant を scope に含めれば、別の操作や主体で同じ key が偶然一致しても衝突しない。
複合一意制約の列に NULL があると、データ層によっては同じ組を重複として扱わず、冪等性が抜ける。
認証済みの actor ID と匿名の session または client の opaque ID を分ければ、異なる利用者が同じ scope を共有しない。
匿名の要求を一つの汎用 sentinel ID へまとめると、異なる利用者の key が衝突し、保存した応答を別の利用者へ返す危険がある。
scope を持たない匿名の要求を server 発行の全体で一意な key に限れば、利用者同士の key は衝突しない。
保存した応答の取得に発行時の proof を要求すれば、key を知った別の利用者へ応答を返さない。
system の logical actor ごとに ID を分ければ、異なる主体として動く処理の key が衝突しない。
multi-tenant operation の tenant scope を検証済みの tenant context から構築した `TenantId` に限れば、要求者が未検証の tenant を指定して冪等 scope を切り替えることを防げる。
single-tenant sentinel と no-tenant sentinel を分ければ、一つの tenant を持つ operation と tenant の概念を持たない operation を同じ意味として記録せずに NOT NULL 制約を満たせる。
三つの tenant scope 表現を相互に混同しなければ、異なる tenant 意味の要求が同じ冪等 scope を共有しない。
request fingerprint を比べれば、同じ key を異なる意図へ再利用した要求を重複実行と区別できる。
初回の応答を保存すれば、同じ意図の再実行へ初回と同じ結果を返せる。

### 完了条件
operation、actor、tenant、key の組が、データ層の一意制約で記録されている。
operation、actor、tenant、key の列が、すべて NOT NULL になっている。
認証済みの要求の actor scope が、検証済みの actor ID になっている。
匿名の要求の actor scope が、session または client ごとの安定した opaque ID になっている。
system の要求の actor scope が、logical actor ごとの安定した ID になっている。
multi-tenant operation の tenant scope が、境界で検証した tenant context から構築した `TenantId` になっている。
single-tenant operation の tenant scope が、正準な single-tenant sentinel になっている。
tenant の概念を持たない operation の tenant scope が、正準な no-tenant sentinel になっている。
未検証の tenant と三つの tenant scope 表現の相互混同が、拒否されている。
scope を持たない匿名の要求が、server 発行の全体で一意な key だけを使っている。
scope を持たない匿名の要求の保存応答が、発行時の proof を検証した要求者にだけ返されている。
request fingerprint と初回の応答が、冪等の鍵と同じ確定点で保存されている。
同じ意図の再実行が初回の応答を返し、異なる意図の再利用が conflict を返している。

### 禁止事項
冪等の鍵の重複検出を、データ層の一意制約なしにアプリケーションの判定だけへ委ねること。
operation、actor、tenant、key の列に、NULL を許すこと。
異なる匿名の利用者を、一つの汎用 sentinel ID で actor scope にまとめること。
異なる system の logical actor を、一つの汎用 sentinel ID で actor scope にまとめること。
未検証の tenant を、multi-tenant operation の `TenantId` として使うこと。
multi-tenant operation に、single-tenant sentinel または no-tenant sentinel を使うこと。
single-tenant operation に、`TenantId` または no-tenant sentinel を使うこと。
tenant の概念を持たない operation に、`TenantId` または single-tenant sentinel を使うこと。
scope を持たない匿名の要求で、client が指定した key を受け付けること。
scope を持たない匿名の要求の保存応答を、発行時の proof を検証せずに返すこと。
同じ scope と key の request fingerprint が異なる要求を、初回と同じ意図として扱うこと。
同じ意図の再実行で、本体の書き込みを繰り返すこと。

### 行動
operation、actor、tenant、key の組へ一意制約を置く。
operation、actor、tenant、key の列を NOT NULL にする。
認証済みの要求では、検証済みの actor ID を actor scope に置く。
匿名の要求では、session または client ごとの安定した opaque ID を actor scope に置く。
system の要求では、logical actor ごとの安定した ID を actor scope に置く。
multi-tenant operation では、境界で検証した tenant context から `TenantId` を構築する。
single-tenant operation では、正準な single-tenant sentinel を使う。
tenant の概念を持たない operation では、正準な no-tenant sentinel を使う。
未検証の tenant と三つの tenant scope 表現の相互混同を拒否する。
scope を持たない匿名の要求には、server が全体で一意な key と応答を取得する proof を発行する。
scope を持たない匿名の要求の actor scope は、server 発行の key に対応する要求固有の opaque ID で埋める。
scope を持たない匿名の要求の保存応答は、発行時の proof を検証してから返す。
初回は request fingerprint と応答を本体の書き込みと同じ確定点で保存する。
同じ scope と key を受けたら、request fingerprint を保存値と比べる。
一致すれば初回の応答を返し、不一致なら conflict を返す。

### 例

`scope` に使う列はすべて `NOT NULL` とする。同じ fingerprint なら初回の応答を返し、異なる fingerprint なら conflict を返す。

```sql
applied_requests(operation NOT NULL, actor_scope NOT NULL,
                 tenant_id NOT NULL, idempotency_key NOT NULL,
                 request_fingerprint, response_payload,
                 UNIQUE(operation, actor_scope, tenant_id, idempotency_key))
```

actor と tenant の検証済みの値から、安定した scope を構築する。

```
authenticated.actorScope = verifiedActor.id
anonymous.actorScope = stableOpaqueScope(sessionOrClient)
system.actorScope = logicalActor.id
multiTenant.tenantId = TenantId.fromVerified(verifiedTenant)
singleTenant.tenantId = "tenant:single"
tenantless.tenantId = "tenant:none"
rejectUnverifiedTenant()
rejectTenantScopeConfusion(multiTenant.tenantId, singleTenant.tenantId, tenantless.tenantId)
```

安定した匿名 scope がなければ、server が発行した key と proof を使う。保存済みの応答は、proof を検証した要求者にだけ返す。

```
{ key, responseProof } = issueGloballyUniqueIdempotencyKey()
anonymous.actorScope = opaqueRequestScope(key)
retry(key, responseProof)
```

## 部分確定を不可視にする

### 要求
確定より前の状態を成功として公開しない定めは、「一つの確定点を持つ」に従う。
失敗の後に外部から見える状態は、再実行または調査で判定できるようにする。

### 根拠
部分確定を成功とみなすと、不完全な状態の上に処理が進む。
失敗後の状態が判定できれば、再実行で回復するか調査するかを決められる。

### 完了条件
失敗の後に外部から見える状態が、再実行または調査で判定できる。

### 禁止事項
失敗の後の外部から見える状態を、再実行でも調査でも判定できない形に放置すること。

### 行動
失敗時は確定点までで止め、外部への効果は確定後か outbox 経由にする。
失敗後の状態を観測できるようにし、再実行か調査の判断に使う。

### 例

複数の書き込みを個別に実行し、二つ目の失敗を無視すると、不完全な状態を成功として返す。

```
write(a)
ignoreFailure(write(b))
return ok
```

一つの確定点までで止め、失敗時はどちらの書き込みも公開しない。未確定のままなら再実行で回復できる。

```
transaction { write(a); write(b) }
```

## 書き込みパスの所有を組立点に置く

### 要求
トランザクションの開始と確定の所有は組立点が持ち、業務の処理は書き込みパスの境界を受け取らない。

### 根拠
業務の処理がトランザクションの境界を握ると、業務判断と確定の制御が混ざる。
境界の所有を組立点に置けば、業務の処理は純粋な判断に保てる。

### 完了条件
トランザクションの開始と確定が、組立点で制御されている。
業務の処理が、トランザクションの境界を受け取っていない。

### 禁止事項
業務の処理に、トランザクションの境界の制御を持ち込むこと。

### 行動
トランザクションの境界を組立点に置く。
業務の処理には、確定済みの値か、確定する意図を表す結果を渡す。

### 例

業務処理がトランザクションを直接操作すると、判断と確定が混ざる。

```
function place(order) { transaction.begin(); ...; transaction.commit(); }
```

業務処理は純粋な判断を返し、組立点がトランザクション境界を所有する。

```
function place(order): Result<Events, E> { ... }
transaction { const events = place(order); record(events) }
```

## 参照
整合性と集約は [data](../principles/data.md)、効果とエラーは [effect](./effect.md) に従う。
配送は [messaging](./messaging.md)、冪等と再試行は [resilience](./resilience.md) に従う。
書き込みパスの所有を実現する構造は [structure/core/composition](../structure/core/composition.md)、言語別の実現は [tools](../tools/) が定める。
