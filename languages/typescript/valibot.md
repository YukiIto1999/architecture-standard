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
  return result.success ? Ok(result.output) : Err({ kind: "invalidEmail" });
}
```

## unknown で受けて一度だけ parse する

### 要求
外部入力は `unknown` で受け、境界の parse は valibot で書く。
`safeParse` の失敗は Result の err へ変換する。
HTTP の応答と postMessage の受信は、どちらもこの parse を通す。
公開契約の境界 schema は canonical と binding から valibot の schema として生成し、生成 DTO と field、variant、制約を共有する。
公開契約の decode は通信を所有する host の adapter で行い、viewer と extension へは検証済みの生成 DTO を port から渡す。
生成した decode は、既知の必須項目、値の制約、判別子と variant の対応を検証し、全 variant と入れ子・配列内の object で契約にないキーの位置と名前を捕捉する。
未知キーを受容しても既知項目の不正を受容せず、捕捉情報を生成 DTO の業務データと送信 payload へ混ぜない。
decode を所有する host の adapter は、捕捉した位置とキーを警告として記録し、値そのものや未知の資格情報をログに載せない。
受信側固有の業務型の schema は formation が定める型封入に合わせ、その受信側が新たに保証する性質だけを所有する。
生成 DTO が受信側で必要な保証を満たすならその型を再利用し、全ての応答を別の branded type へ写すことを要求しない。

### 根拠
TypeScript の静的な型は、外部から来る値を保証しない。
`unknown` で受けて parse すれば、検証を通った値だけが型を名乗る。
valibot の schema は Standard Schema V1 に適合し、`~standard.validate` を通じてベンダー非依存に検証できるので、境界の parse を valibot に一本化しても他の Standard Schema 対応ツールとの相互運用を失わない。
業務の値の schema を formation の定義に一本化すれば、型と検証が別々に定義されてずれることも、同じ brand 名を複数箇所で宣言して機構が割れることもない。
境界の HTTP も postMessage も同じ parse に通せば、検証の漏れる経路がない。
生成 schema が未知キーを取り除く前に捕捉すれば、既知の契約だけを内側へ渡しながら、契約の進化による追加を検知できる。

### 完了条件
外部入力が、`unknown` で受けられている。
parse が valibot の schema を通し、失敗が Result の err になっている。
公開契約の DTO と schema が同じ canonical と binding から生成され、受信側固有の型はその責務と保証を所有する schema から導出されている。
全 variant と入れ子・配列内の object の未知キーが受容され、位置と名前が捕捉されて境界の警告へ到達し、捕捉した値が業務データと送信 payload へ流入していない。
既知の必須項目の欠落、制約違反、判別子と payload の不一致が拒否されている。
HTTP の応答と postMessage の受信が、同じ parse を通っている。

### 禁止事項
外部入力を、型アサーションで信頼すること。
公開契約の field、variant、制約を手書き schema へ写し、生成 DTO とは別の正本にすること。
未知キーを記録せずに捨てることや、捕捉を理由に既知項目の検証を省くこと。

### 行動
外部入力を `unknown` で受け、valibot の schema で `safeParse` し、失敗を Result の err にする。
公開契約は生成した valibot の schema で parse し、型の出力が生成 DTO と対応することを検証する。
valibot の schema の出力を、canonical と binding を使う単一の contracts 生成 task に含め、生成器の既定で出せない処理は schema 駆動の生成処理として管理する。
未知キーの捕捉も生成経路へ含め、全 variant と入れ子・配列内の object の位置とキーを decode の結果とは別に境界へ返し、host の adapter で警告を記録する。
未知キーの受容と記録、既知項目の不正の拒否、捕捉値の非流入を、生成された decode の実行で確かめる。
受信側で検証や解決の知識が増える場合は formation の schema でその保証を持つ型へ変換し、同じ性質を再検証しない。

### 例
型アサーションでは、検証していない外部入力がそのまま内側へ入る。

```typescript
const user = (await response.json()) as User;
```

`UserViewSchema` は canonical と binding から生成した schema であり、その出力型は生成 DTO の `UserView` に対応する。
受信側に追加の業務の保証が不要なら、その出力をそのまま使う。

```typescript
const raw: unknown = await response.json();
const result = v.safeParse(UserViewSchema, raw);
if (!result.success) return Err(result.issues);
const user = result.output;
```

## 受け取ったエラーを parse し、想定された失敗と欠陥を分ける

### 要求
client は problem+json を canonical と binding から生成した schema で `safeParse` する。
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
if (response.status >= 400 && response.status < 500) return Err(await response.json());
```

status と body の組を operation 契約で検証し、宣言された failure だけを返す。

```typescript
const raw: unknown = { status: response.status, body: await response.json() };
const result = v.safeParse(PlaceOrderErrorResponseSchema, raw);
if (!result.success) throw new ContractViolation(result.issues);
return Err(placeOrderFailureMapper(result.output));
```
