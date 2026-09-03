## 宣言と使用を近接させる

### 要求
変数と補助的な処理の宣言は、最初に使う箇所の近くに置く。
スコープは、必要な最小の範囲に絞る。

### 根拠
短さを求める理由は、画面に収めることでなく、スコープを狭めて誤用と干渉の余地を減らすことにある。
宣言と使用が離れるほど、読み手が保持する文脈が増える。
スコープが広いほど、値の変更点と参照点の組み合わせが増え、追跡が難しくなる。

### 完了条件
宣言から最初の使用までの距離が短い。
各宣言のスコープが、使用の範囲を超えていない。

### 禁止事項
使用から離れた場所へ、宣言をまとめて置くこと。
必要より広いスコープで宣言すること。

### 行動
宣言を最初の使用の直前へ移す。
広いスコープの宣言は、使用範囲に合わせて絞るか、関数へ切り出す。

### 例
宣言を冒頭へ集めると使用までの距離が開き、前処理の間も値へ干渉できる。

```ts
function summarize(orders: Order[]) {
  let total = 0;
  const normalized = normalize(orders);
  total = normalized.reduce((sum, order) => sum + order.amount, 0);
  return total;
}
```

宣言を使用の直前に置けば、スコープを最小にできる。

```ts
function summarize(orders: Order[]) {
  const normalized = normalize(orders);
  const total = normalized.reduce((sum, order) => sum + order.amount, 0);
  return total;
}
```
