# formation

## 概要
formation は、TypeScript で値・型・不変条件をモデリングする実現軸である。
principles の [modeling](../../principles/modeling.md) が定める業務意味の型封入と、concerns の [types](../../concerns/types.md) が定める型の規律を、TypeScript の機構で満たす。
業務の値の型封入の規律は [valibot](./valibot.md) が持つ。

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
省略可能な property の組み合わせでは、`circle` に `radius` が無い状態も表せてしまう。

```typescript
interface Shape { kind: string; radius?: number; side?: number }
```

判別子つき union と `never` で場合分けを閉じれば、形の追加が型エラーになる。

```typescript
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "square"; side: number };
function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "square": return shape.side ** 2;
    default: { const _exhaustive: never = shape; return _exhaustive; }
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
業務意味の型封入は [modeling](../../principles/modeling.md)、型の規律は [types](../../concerns/types.md) に従う。
命名と整形、ドキュメントコメントの体裁は [conventions](./conventions.md) に従う。
境界での外部表現の変換は [translation](./translation.md)、Result の機構は [neverthrow](./neverthrow.md) に従う。
