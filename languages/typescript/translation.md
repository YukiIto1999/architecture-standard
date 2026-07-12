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
```typescript
// 型アサーションで外部入力を信じる。検証なしで内側へ
const user = (await response.json()) as User;

// unknown で受け、formation で定義した schema を真実源に safeParse する
const UserSchema = v.object({ email: EmailSchema }); // EmailSchema は formation の定義を再利用する
type User = v.InferOutput<typeof UserSchema>;         // 到達点は branded type。email は Email
const raw: unknown = await response.json();
const result = v.safeParse(UserSchema, raw);
if (!result.success) return err(result.issues);   // 失敗は Result の err
const user = result.output;                       // 検証済み型
```

## 受け取ったエラーを parse し、想定された失敗と欠陥を分ける

### 要求
client は problem+json を schema で `safeParse` する。
4xx は想定された失敗として Result で返し、5xx と problem+json 自体の parse 失敗は欠陥として上位へ投げる。

### 根拠
公開エラーを生の形で扱うと、失敗の種別が型に現れない。
problem+json を schema で `safeParse` すれば、失敗が型で扱え、「unknown で受けて一度だけ parse する」の境界の parse を `safeParse` に一本化する規律とも揃う。
4xx の想定された失敗と 5xx の欠陥を分ければ、回復できる失敗と回復できない欠陥を取り違えない。
status の範囲を 4xx に絞らず 500 未満とだけ判定すると、2xx・3xx の応答まで想定された失敗の Result に落ちてしまう。

### 完了条件
problem+json が、`safeParse` で parse されている。
4xx が Result で返され、5xx と parse 失敗が上位へ投げられている。
2xx・3xx の応答が、想定された失敗の Result に落ちていない。

### 禁止事項
4xx の想定された失敗と 5xx の欠陥を、同じ扱いにすること。
problem+json を、検証せずに信頼すること。
status の判定を、4xx の範囲でなく 500 未満のような緩い条件で行うこと。

### 行動
problem+json を `safeParse` し、parse に失敗したら欠陥として投げる。
status が 400 以上 500 未満のときだけ Result の err に、それ以外は欠陥として投げる。

### 例
```typescript
// v.parse は失敗で throw し、status も見ずに 500 未満を丸ごと err に落とす。2xx も err になりうる
const problem = v.parse(ProblemSchema, await response.json());
if (response.status < 500) return err(problem);

// safeParse で受け、4xx の範囲だけを想定された失敗として返す
const result = v.safeParse(ProblemSchema, await response.json());
if (!result.success) throw new Defect(result.issues);                           // problem+json 自体が不正なら欠陥
if (response.status >= 400 && response.status < 500) return err(result.output); // 4xx だけが想定された失敗
throw new Defect(result.output);                                                // 5xx は欠陥
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
