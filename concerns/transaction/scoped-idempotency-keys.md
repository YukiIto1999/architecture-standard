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
冪等そのものの理由は [resilience](../resilience/README.md) に従う。
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
