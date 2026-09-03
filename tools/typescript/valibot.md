# valibot

用途は、外部入力を schema で検証し、検証済みの値だけに型を名乗らせる機構である。
採用は、TypeScript は valibot である。
判断基準は、schema から型を導出でき、Standard Schema V1 に適合し他のツールとの相互運用を保てることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 業務の値を型に封じる

### 要求
業務の値は valibot の schema を `v.brand` で名指しした branded type で表す。
schema は業務概念ごとに一度だけ定義し、型は `v.InferOutput` で導出する。
構築は schema の `safeParse` を通す factory に一点化し、検証を経ない値に brand を与えない。
factory は不変条件の違反を throw でなく Result の err で返す。
直列化の境界を越えて入った値は、必ず同じ schema を通して再構築する。

### 根拠
TypeScript は構造的な型付けなので、同じ構造の値は別の意味でも代入できてしまう。
valibot の `v.brand` は schema の出力型に名前を持たせ、構造が同じでも別の名前を持つ型にして取り違えを型検査で防ぐ。
schema を業務概念ごとに一つだけ定義すれば、同じ brand 名を複数箇所で手作業で宣言して機構が割れることがない。
factory を schema の `safeParse` に一本化すれば、検証を経ない値が brand を名乗れない。
想定された失敗を throw で表すと呼び出し側が捕捉を強制されないので、Result で返して失敗を型に現す。

### 完了条件
業務の値が、valibot の `v.brand` で名指しされた branded type で表されている。
型が、schema から `v.InferOutput` で導出されている。
構築が schema の `safeParse` を通す factory に限られ、検証を経ない値に brand が与えられていない。
factory の失敗が、throw でなく Result の err で返されている。
直列化の境界を越えて入った値が、同じ schema を通して再構築されている。

### 禁止事項
brand の付与を、schema の `safeParse` を経ずに行うこと。
直列化の境界を越えて入った値を、検証を経ずに branded type として扱うこと。
factory の失敗を、throw で表すこと。

### 行動
業務概念ごとに `v.brand` で名指しした schema を一度だけ定義し、型は schema から `v.InferOutput` で導出する。
factory は schema の `safeParse` を呼び、失敗を Result の err、成功を Result の ok で返す。

### 例
検証しない裸の cast では、任意の文字列が `Email` を名乗れる。

```typescript
const email = request.body.email as Email;
```

schema を真実源にし、factory が `safeParse` の結果を `Result` へ変換する。

```typescript
const EmailSchema = v.pipe(v.string(), v.email(), v.brand("Email"));
type Email = v.InferOutput<typeof EmailSchema>;
type EmailError = { kind: "invalidEmail" };
function toEmail(value: string): Result<Email, EmailError> {
  const result = v.safeParse(EmailSchema, value);
  return result.success ? ok(result.output) : err({ kind: "invalidEmail" });
}
```

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
