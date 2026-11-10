# valibot

用途は、受信側固有の業務値と公開契約外の入力を schema で検証し、その型を導出する機構である。
採用は、TypeScript は valibot である。
判断基準は、schema から型を導出でき、Standard Schema V1 に適合し他のツールとの相互運用を保てることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 業務の値を型に封じる

### 要求
独立した意味と操作を持つ値と、複数のモデルや境界を越えて同じ意味・単位・区別を維持すべき値は valibot の schema を `v.brand` で名指しした branded type で表す。
複数の要素にまたがる不変条件を持つ値は、要素を持つ object の schema に不変条件の検証を置いて brand を付け、要素ごとの brand は要求で定めた値型の保証を担う場合に限って足す。
一つの業務モデルが private に持つ値の制約と正規化は、そのモデルの構築の検証で守り、値ごとの brand を必須にしない。
schema は業務概念ごとに一度だけ定義し、型は `v.InferOutput` で導出する。
構築は schema の `safeParse` を通す factory に一点化し、検証を経ない値に brand を与えない。
factory は不変条件の違反を throw でなく Result の err で返す。
直列化の境界を越えて入った値は、必ず同じ schema を通して再構築する。

### 根拠
TypeScript は構造的な型付けなので、同じ構造の値は別の意味でも代入できてしまう。
valibot の `v.brand` は schema の出力型に名前を持たせ、構造が同じでも別の名前を持つ型にして取り違えを型検査で防ぐ。
schema を業務概念ごとに一つだけ定義すれば、同じ brand 名を複数箇所で手作業で宣言して機構が割れることがない。
factory を schema の `safeParse` に一本化すれば、検証を経ない値が brand を名乗れない。
要素の組にまたがる不変条件は、要素を持つ object の schema の検証だけが守り、要素ごとの brand では組の検査が残る。
独立した値型を要しない値は、そのモデルの構築が検証と正規化を守れるので、brand を足しても型と変換が増えるだけになる。
想定された失敗を throw で表すと呼び出し側が捕捉を強制されないので、Result で返して失敗を型に現す。

### 完了条件
独立した意味と操作を持つ値と、複数のモデルや境界を越えて同じ意味・単位・区別を維持すべき値が、valibot の `v.brand` で名指しされた branded type で表されている。
型が、schema から `v.InferOutput` で導出されている。
構築が schema の `safeParse` を通す factory に限られ、検証を経ない値に brand が与えられていない。
factory の失敗が、throw でなく Result の err で返されている。
直列化の境界を越えて入った値が、同じ schema を通して再構築されている。

### 禁止事項
brand の付与を、schema の `safeParse` を経ずに行うこと。
直列化の境界を越えて入った値を、検証を経ずに branded type として扱うこと。
factory の失敗を、throw で表すこと。
検証・区別・操作のいずれの保証も増やさない brand を、フィールドごとに足すこと。
値に制約や正規化があることだけを理由に、brand を必須にすること。

### 行動
独立した意味と操作を持つ業務概念と、複数のモデルや境界を越えて維持すべき意味・単位・区別を持つ業務概念ごとに `v.brand` で名指しした schema を一度だけ定義し、型は schema から `v.InferOutput` で導出する。
factory は schema の `safeParse` を呼び、失敗を Result の err、成功を Result の ok で返す。
一つのモデルが private に持つ値は、モデルの構築に制約と正規化を置き、値ごとの brand を足さない。

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
公開契約外の入力は unknown で受け、その境界が所有する Valibot の schema で safeParse する。
safeParse は受理値または構造化した違反情報を返し、呼出側は [effect](../../concerns/effect/value-origin-classification.md) の「失敗と欠陥を値の出所で判別する」に従って想定内失敗と欠陥を分類する。
受信側固有の業務型の schema は、その業務側が新たに保証する性質を所有し、公開契約の field・variant・制約を写さない。
HTTP・IPC・postMessage の公開契約は [translation](./translation.md) が定める生成 codec に通し、Valibot の schema を同じ契約の第二の検証機構にしない。

### 根拠
TypeScript の静的な型は外部の値を保証しないが、受信側が所有する schema を一度通せば、その境界が保証する型を導出できる。
公開契約と業務値の所有を分ければ、同じ schema へ別々の変更理由を混ぜずに済む。

### 完了条件
公開契約外の入力が unknown で受けられ、所有する schema の safeParse を通っている。
parse の違反が出所に応じて分類され、公開契約の decode が Valibot の同義 schema で再実装されていない。

### 禁止事項
外部入力を型 assertion で信頼すること。
公開契約の field・variant・制約を手書き schema に写すこと。

### 行動
入力ごとに公開契約と受信側固有の保証を分け、前者は生成 codec、後者は所有する schema の safeParse へ接続する。
内側へは検証を通った値だけを渡し、同じ性質を再検証しない。

