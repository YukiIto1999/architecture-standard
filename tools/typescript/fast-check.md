# fast-check

用途は、入出力の不変量を性質として多くの入力で検査する property-based testing である。
採用は、TypeScript は fast-check である。
判断基準は、失敗した入力を最小化でき、状態の遷移を操作の列を生成する stateful な形で突けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 性質

### 要求
property-based testing は fast-check で書き、状態の遷移は fast-check の model-based な形で書く。

### 根拠
[verification](../../principles/verification.md) が定める、例だけを並べるより性質を書いて入力を多数生成すると見落とした場合が見つかるという要求に、fast-check の入力生成で応える。
失敗した入力は最小化され、seed と path で再現できる。
状態の遷移は、操作の列を生成して実体とモデルの等価を確かめる model-based な形で突ける。

### 完了条件
性質が fast-check で書かれ、入出力の不変量を多くの入力で突いている。
状態の遷移が、model-based な形で書かれている。

### 禁止事項
model を、検証対象の実装の写しにすること。

### 行動
入出力の不変量を性質にし、fast-check で多くの入力を突く。
状態の遷移は、実体と独立したモデルを並べる model-based な形で書く。

### 例
一つの固定入力だけでは、性質が他の入力でも成り立つかは分からない。

```typescript
test("rev", () => { expect(reverse(reverse([1, 2, 3]))).toEqual([1, 2, 3]); });
```

property-based testing では、同じ性質を生成した多くの入力で確かめる。

```typescript
fc.assert(fc.property(fc.array(fc.integer()), (values) => {
  expect(reverse(reverse(values))).toEqual(values);
}));
```
