# translation

## 概要
translation は、TypeScript で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信を、TypeScript の機構で満たす。

## unknown で受けて一度だけ parse する

### 要求
外部入力は `unknown` で受け、境界の parse は valibot で書く。
`safeParse` の失敗は Result の err へ変換する。
HTTP の応答と postMessage の受信は、どちらもこの parse を通す。
業務の値の schema は formation が定義し、境界の schema はそれを組み込んで一つの真実源にする。

### 根拠
TypeScript の静的な型は、外部から来る値を保証しない。
`unknown` で受けて parse すれば、検証を通った値だけが型を名乗る。
valibot の schema は Standard Schema V1 に適合し、`~standard.validate` を通じてベンダー非依存に検証できるので、境界の parse を valibot に一本化しても他の Standard Schema 対応ツールとの相互運用を失わない。
業務の値の schema を formation の定義に一本化すれば、型と検証が別々に定義されてずれることも、同じ brand 名を複数箇所で宣言して機構が割れることもない。
境界の HTTP も postMessage も同じ parse に通せば、検証の漏れる経路がない。

### 完了条件
外部入力が、`unknown` で受けられている。
parse が valibot の schema を通し、失敗が Result の err になっている。
型が、schema から導出されている。
HTTP の応答と postMessage の受信が、同じ parse を通っている。

### 禁止事項
外部入力を、型アサーションで信頼すること。
型と検証を、別々に定義すること。

### 行動
外部入力を `unknown` で受け、valibot の schema で `safeParse` し、失敗を Result の err にする。
型は schema から導出し、境界の到達点を formation の branded type にする。

### 例
型アサーションでは、検証していない外部入力がそのまま内側へ入る。

```typescript
const user = (await response.json()) as User;
```

`unknown` で受け、formation が定義した `EmailSchema` を再利用して `safeParse` する。検証成功時の `email` は `Email` になる。

```typescript
const UserSchema = v.object({ email: EmailSchema });
type User = v.InferOutput<typeof UserSchema>;
const raw: unknown = await response.json();
const result = v.safeParse(UserSchema, raw);
if (!result.success) return err(result.issues);
const user = result.output;
```

## 受け取ったエラーを parse し、想定された失敗と欠陥を分ける

### 要求
client は problem+json を schema で `safeParse` する。
HTTP status は、契約が定める公開表現として扱う。
operation の契約に宣言された失敗は、Result で返す。
契約に無い応答と problem+json の parse 失敗は、契約違反の欠陥として上位へ投げる。
実装の throw は、想定された失敗へ変換せず欠陥として上位へ投げる。

### 根拠
公開エラーを生の形で扱うと、失敗の種別が型に現れない。
problem+json を schema で `safeParse` すれば、失敗が型で扱え、「unknown で受けて一度だけ parse する」の境界の parse を `safeParse` に一本化する規律とも揃う。
HTTP status は wire 上の表現なので、数値の範囲だけでは業務が扱う失敗か契約違反かを判定できない。
operation の契約が宣言した失敗だけを Result にすれば、呼び出し側が扱うべき場合が型に現れる。
契約に無い status と body の組や parse できない problem+json は、公開契約を満たさないので契約違反の欠陥になる。
実装の throw を Result に落とさなければ、宣言された失敗と実装欠陥を取り違えない。

### 完了条件
problem+json が、`safeParse` で parse されている。
HTTP status が、契約の公開表現として扱われている。
operation の契約に宣言された失敗だけが、Result で返されている。
契約に無い応答と parse 失敗が、契約違反の欠陥として上位へ投げられている。
実装の throw が、欠陥として上位へ投げられている。

### 禁止事項
HTTP status の範囲だけで、想定された失敗と欠陥を分類すること。
problem+json を、検証せずに信頼すること。
契約に無い応答や実装の throw を、想定された失敗の Result に変換すること。

### 行動
problem+json を `safeParse` し、parse に失敗したら欠陥として投げる。
status と problem+json の組を operation の契約 schema で parse する。
契約 schema が宣言する failure variant だけを Result の err にする。
契約に無い応答と実装の throw は、欠陥として投げる。

### 例
応答 status の範囲だけで分類すると、契約に無い応答まで想定された失敗に変わる。

```typescript
if (response.status >= 400 && response.status < 500) return err(await response.json());
```

status と body の組を operation 契約で検証し、宣言された failure だけを返す。

```typescript
const raw: unknown = { status: response.status, body: await response.json() };
const result = v.safeParse(PlaceOrderErrorResponseSchema, raw);
if (!result.success) throw new ContractViolation(result.issues);
return err(placeOrderFailureMapper(result.output));
```

## 契約の型を生成する

### 要求
contracts/generated の TypeScript の型は、TypeSpec から `@typespec/openapi3` で出力した OpenAPI を、openapi-typescript で型だけに生成する。

### 根拠
openapi-typescript は型定義だけを出力し runtime のコードを持たないので、生成型を型としてのみ使い runtime の依存を持ち込まない規律とかみ合う。
契約から型を生成すれば、UI が参照する型が契約に従う。

### 完了条件
型が、TypeSpec から `@typespec/openapi3` を経て openapi-typescript で生成されている。

### 禁止事項
契約の型を、runtime のコードを含む生成器で作ること。

### 行動
TypeSpec から `@typespec/openapi3` で OpenAPI を出力し、openapi-typescript で型を生成する。

## 生成型を型としてのみ使い、通信を port に通す

### 要求
contracts/generated の型は型としてだけ import し、契約の package へ runtime の依存を持ち込まない。
通信は ui port を通して行う。

### 根拠
生成型を runtime の値として使うと、契約の package が実行時の依存になり、UI が契約の実装に縛られる。
型としてだけ使えば、契約は型の境界に留まる。
通信を port に通せば、UI は通信の実装から切り離される。

### 完了条件
生成型が、型としてのみ import されている。
契約の package に、runtime の依存がない。
通信が、ui port を通っている。

### 禁止事項
生成型を、runtime の値として使うこと。
契約の package へ、runtime の依存を持ち込むこと。

### 行動
生成型を `import type` で取り込み、通信は ui port を通す。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md) に従う。
