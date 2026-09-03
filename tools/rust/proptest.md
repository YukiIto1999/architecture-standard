# proptest

用途は、入出力の不変量を性質として多くの入力で検査する property-based testing である。
採用は、Rust は proptest である。
判断基準は、失敗した入力を最小化でき、状態の遷移を操作の列を生成する stateful な形で突けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 性質

### 要求
property-based testing は proptest で書き、状態の遷移は proptest の stateful な形で書く。

### 根拠
[verification](../../principles/verification.md) が定める、例だけを並べるより性質を書いて入力を多数生成すると見落とした場合が見つかるという要求に、proptest の入力生成で応える。
失敗した入力は最小化され、小さな反例で原因を追える。
状態の遷移は、操作の列を生成して不変量を確かめる stateful な形で突ける。

### 完了条件
性質が proptest で書かれ、入出力の不変量を多くの入力で突いている。
状態の遷移が、stateful な形で書かれている。

### 禁止事項
性質の検査の本体で、最小化の効かない通常の assert を使うこと。

### 行動
入出力の不変量を性質にし、proptest で多くの入力を突く。
失敗の seed を回帰として残し、状態の遷移は stateful な形で書く。

### 例
固定した一例だけでは、同じ性質を破る別の入力を検査できない。

```rust
#[test] fn rev() { assert_eq!(reverse(reverse(vec![1,2,3])), vec![1,2,3]); }
```

性質を多くの入力で検査し、失敗時に最小化できるアサーションを使う。

```rust
proptest! {
    #[test]
    fn rev_twice(values in proptest::collection::vec(any::<i32>(), 0..100)) {
        prop_assert_eq!(reverse(&reverse(&values)), values);
    }
}
```
