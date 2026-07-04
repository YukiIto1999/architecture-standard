# formation

## 概要
formation は、TypeScript で値・型・不変条件をモデリングする実現軸である。
principles の [modeling](../../principles/modeling.md) が定める業務意味の型封入と、concerns の [types](../../concerns/types.md) が定める型の規律を、TypeScript の機構で満たす。

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
```typescript
// 検証なしの裸の cast。任意の文字列が Email を名乗れる
const email = request.body.email as Email;

// schema を真実源にし、factory は safeParse を Result へ変換する
const EmailSchema = v.pipe(v.string(), v.email(), v.brand("Email"));
type Email = v.InferOutput<typeof EmailSchema>;
type EmailError = { kind: "invalidEmail" };
function toEmail(value: string): Result<Email, EmailError> {
  const result = v.safeParse(EmailSchema, value);
  return result.success ? ok(result.output) : err({ kind: "invalidEmail" });
}
```

## 不正な状態を構築できなくする

### 要求
場合分けのある概念は判別子つきの union で表し、分岐は switch の網羅で書いて漏れを型検査に検出させる。
不在は undefined の union で表し、strict の型検査で扱いを強制する。

### 根拠
判別子つきの union は、リテラルの判別子で取りうる形を枚挙し、文字列の綴り間違いを型で弾く。
すべての分岐を消すと残りが never になるので、never への代入で網羅を確かめれば、形の追加が型エラーで気づける。
省略可能なプロパティで状態を表すと、不在を実行時に踏む。
undefined の union と strict の型検査は、不在の扱いを呼び出し側に強制する。

### 完了条件
場合分けが、判別子つきの union で表されている。
分岐が switch の網羅で書かれ、形の追加が never への代入で型エラーになる。
不在が、undefined の union で表され strict で扱いが強制されている。

### 禁止事項
場合分けを、省略可能なプロパティの組み合わせで表すこと。
網羅でない分岐で、形の追加を見逃すこと。

### 行動
場合分けは class の階層でなく判別子つきの union と関数で表し、switch の網羅で扱う。
default のアームで残りを never に代入し、形の追加を型エラーにする。

### 例
```typescript
// 省略可能なプロパティ。radius の不在を実行時に踏む
interface Shape { kind: string; radius?: number; side?: number }

// 判別子つき union と never 網羅
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "square"; side: number };
function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "square": return shape.side ** 2;
    default: { const _exhaustive: never = shape; return _exhaustive; } // 形の追加で型エラー
  }
}
```

## 不変を既定にする

### 要求
値の property は readonly で表し、変更は新しいオブジェクトを作る形で表す。
固定の値は as const で最も狭いリテラルの型に固定する。

### 根拠
readonly と Readonly は、構築の後の書き換えを型で塞ぐ。
as const は値を最も狭いリテラルの型に固定し、再代入と書き換えを防ぐ。
不変のデータ構造は、状態の発散を抑える。

### 完了条件
値の property が、readonly で表されている。
変更が、新しいオブジェクトの生成で表されている。

### 禁止事項
値の property を、書き換え可能なまま公開すること。

### 行動
property を readonly にし、オブジェクト全体は Readonly で包む。
固定の値は as const で固定し、変更は新しいオブジェクトを作る形で表す。

### 例
```typescript
// 再代入も書き換えもできる
const settings = { mode: "fast" };
// readonly と as const で固定する
const config = { mode: "fast" } as const;          // mode は "fast" に固定
type State = Readonly<{ items: readonly Item[] }>;
```

## 意味と単位を型で区別する

### 要求
意味や単位が異なる値は、構造が同じでも別の branded type で区別する。

### 根拠
同じ `string` でも利用者の識別子と注文の識別子は別の概念で、取り違えると別のものを指す。
別の brand を付ければ、構造が同型でもコンパイラが取り違えを拒否する。

### 完了条件
意味や単位が異なる値が、別の branded type で区別されている。
取り違えが、型エラーになる。

### 禁止事項
意味や単位の異なる値を、同じプリミティブで扱うこと。

### 行動
単位ごと・識別子ごとに brand を分け、factory を通して組み立てる。

### 例
```typescript
const UserIdSchema = v.pipe(v.string(), v.brand("UserId"));
const OrderIdSchema = v.pipe(v.string(), v.brand("OrderId"));
type UserId = v.InferOutput<typeof UserIdSchema>;
type OrderId = v.InferOutput<typeof OrderIdSchema>;
// UserId を要求する関数に OrderId を渡すと型エラーになる
function findUser(id: UserId): User { /* ... */ }
```

## 命名と整形を道具に委ねる

### 要求
命名は標準的な TypeScript の規約に従い、型は PascalCase、値と関数は camelCase にする。
整形は oxfmt の既定に従い、手で揃えない。
ファイル名は kebab-case で統一し、oxlint の `unicorn/filename-case` で揃える。

### 根拠
整形を手で揃えると、差分に無意味な変更が混じり、規約の揺れがレビューの対象になる。
道具に委ねれば表記が一意に決まり、議論を設計に集中できる。
TypeScript はファイル名の標準の規約を持たないため、一つの表記に固定しないと表記が揺れる。
kebab-case に固定して `unicorn/filename-case` で揃えれば、ファイル名が一意に決まる。
型と値の命名規約(PascalCase・camelCase)自体を検査する規則は oxlint に無く、この部分はレビューで確認する。

### 完了条件
命名が、型は PascalCase、値と関数は camelCase になっている。
ファイル名が、kebab-case で統一され `unicorn/filename-case` で検査されている。
整形が、oxfmt の既定で一意に決まっている。

### 禁止事項
整形を、手で揃えること。
ファイル名の表記を、混在させること。

### 行動
型を PascalCase、値と関数を camelCase で名付ける。
ファイル名を kebab-case にし、oxfmt と oxlint を既定で適用する。

## 契約をドキュメントコメントに書く

### 要求
宣言した要素に TSDoc のドキュメントコメントを付ける。
対象が持つ @typeParam・@param・@returns・@throws を省かない。
想定された失敗は戻り値の Result の型に現し、@throws は欠陥に限る。
summary の最初の一行と文体の規律は [comment](../../principles/comment.md) に従う。

### 根拠
TSDoc は、ツールが一貫して解釈できる統一文法で、利用者が実装を読まずに用途と契約を読めるようにする。
@param・@returns は、引数と戻り値を契約として宣言し、想定された失敗は戻り値の Result の型に現す。
summary の最初の一行と文体の理由は [comment](../../principles/comment.md) に従う。

### 完了条件
宣言した要素に、用途と契約を述べる TSDoc のドキュメントコメントがある。
@typeParam・@param・@returns・@throws が、対象の持つものを網羅している。
summary の最初の一行と文体が、[comment](../../principles/comment.md) の完了条件を満たしている。

### 禁止事項
宣言した要素の契約を、未記述で放置すること。
対象が持つ @typeParam・@param・@returns・@throws を、省くこと。

### 行動
要素ごとに目的の summary を一行で書き、型引数・引数・戻り値・送出する欠陥を @typeParam・@param・@returns・@throws のうち該当するものに記す。
summary の最初の一行と文体は [comment](../../principles/comment.md) に従って書く。

### 例
```typescript
/**
 * 検証済みカートの確定と在庫引当
 * @param cart - 確定対象の検証済みカート
 * @returns 確定済みの注文または在庫不足の失敗
 * @throws InvariantViolation 保存済みの注文が不変条件に違反している
 */
function place(cart: ValidCart): Result<Order, OrderError> { /* ... */ }
```

## 参照
業務意味の型封入は [modeling](../../principles/modeling.md)、型の規律は [types](../../concerns/types.md)、ドキュメントコメントは [comment](../../principles/comment.md) に従う。
境界での外部表現の変換は [translation](./translation.md)、Result の機構(neverthrow)は [connection](./connection.md) に従う。
