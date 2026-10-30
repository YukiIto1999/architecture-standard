# formation

## 概要
formation は、TypeScript で値・型・不変条件をモデリングする実現軸である。
principles の [modeling](../../principles/modeling/README.md) が定める業務意味の型封入と、concerns の [types](../../concerns/types/README.md) が定める型の規律を、TypeScript の機構で満たす。
境界で受けた値を検証する schema の規律は [valibot](./valibot.md) が持つ。

## 不正な状態を構築できなくする

### 要求
場合分けのある概念は判別子つきの union で表し、分岐は switch で書いて、switch の網羅を oxlint-tsgolint の `typescript/switch-exhaustiveness-check` に検査させる。
switch で書かない判別子の分岐は、末尾で残りを never に代入し、形の追加を型検査に検出させる。
不在は undefined の union で表し、strict の型検査で扱いを強制する。

### 根拠
判別子つきの union は、リテラルの判別子で取りうる形を枚挙し、文字列の綴り間違いを型で弾く。
`typescript/switch-exhaustiveness-check` は、switch の未処理の種別を、default のアームがあっても報告するので、default が新しい種別を黙って受けない。
この規則は pedantic 区分で既定では無効であり、型情報を要するので、`vite.config.ts` の `lint` block で error にして `typeAware` で実行する。
`considerDefaultExhaustiveForUnions` を有効にすると default のアームが網羅とみなされるので、有効にしない。
この規則は switch 文だけを見るので、switch で書かない分岐は、すべての分岐を消すと残りが never になる性質を使い、never への代入で網羅を確かめれば、形の追加が型エラーで気づける。
switch に never への代入を重ねると、同じ性質を lint と型検査の二つで判定するので、switch には置かない。
省略可能なプロパティで状態を表すと、不在を実行時に踏む。
undefined の union と strict の型検査は、不在の扱いを呼び出し側に強制する。

### 完了条件
場合分けが、判別子つきの union で表されている。
switch の分岐が、`typescript/switch-exhaustiveness-check` を error にした lint で、全ての種別を処理していると判定されている。
switch で書かない判別子の分岐が、末尾で残りを never に代入し、形の追加が型エラーになる。
不在が、undefined の union で表され strict で扱いが強制されている。

### 禁止事項
場合分けを、省略可能なプロパティの組み合わせで表すこと。
網羅でない分岐で、形の追加を見逃すこと。
`considerDefaultExhaustiveForUnions` を有効にして、default のアームを網羅とみなすこと。
switch に、never への代入の default を重ねること。

### 行動
場合分けは class の階層でなく判別子つきの union と関数で表し、switch で扱う。
`vite.config.ts` の `lint` block で `typescript/switch-exhaustiveness-check` を error に設定し、`considerDefaultExhaustiveForUnions` を有効にしない。
switch で書かない判別子の分岐は、末尾で残りを never に代入する。

### 例
省略可能な property の組み合わせでは、`circle` に `radius` が無い状態も表せてしまう。

```typescript
interface Shape { kind: string; radius?: number; side?: number }
```

判別子つき union と switch で場合分けを閉じれば、形の追加を lint が検出する。

```typescript
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "square"; side: number };
function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "square": return shape.side ** 2;
  }
}
```

switch で書かない分岐は、末尾で残りを `never` に代入すれば、形の追加が型エラーになる。

```typescript
function areaOf(shape: Shape): number {
  if (shape.kind === "circle") return Math.PI * shape.radius ** 2;
  if (shape.kind === "square") return shape.side ** 2;
  const exhaustive: never = shape;
  return exhaustive;
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
通常の object は property を書き換えられる。

```typescript
const settings = { mode: "fast" };
```

`as const` でリテラル型に固定し、`Readonly` で property の書き換えを禁じる。

```typescript
const config = { mode: "fast" } as const;
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
`UserId` と `OrderId` は同じ `string` から構築しても代入互換にならない。

```typescript
const UserIdSchema = v.pipe(v.string(), v.brand("UserId"));
const OrderIdSchema = v.pipe(v.string(), v.brand("OrderId"));
type UserId = v.InferOutput<typeof UserIdSchema>;
type OrderId = v.InferOutput<typeof OrderIdSchema>;
function findUser(id: UserId): User { /* ... */ }
```

## 参照
業務意味の型封入は [modeling](../../principles/modeling/README.md)、型の規律は [types](../../concerns/types/README.md) に従う。
命名と整形、ドキュメントコメントの体裁は [conventions](./conventions.md) に従う。
境界での外部表現の変換は [translation](./translation.md)、Result の機構は [ts-results-es](./ts-results-es.md) に従う。
