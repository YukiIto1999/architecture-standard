# CsCheck

用途は、入出力の不変量を性質として多くの入力で検査する property-based testing である。
採用は、C# は CsCheck である。
判断基準は、失敗した入力を最小化でき、状態の遷移を操作の列を生成する stateful な形で突けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 性質

### 要求
property-based testing は CsCheck で書き、状態の遷移は CsCheck の stateful な形で書く。

### 根拠
[verification](../../principles/verification.md) が定める、例だけを並べるより性質を書いて入力を多数生成すると見落とした場合が見つかるという要求に、CsCheck の入力生成で応える。
失敗した入力は最小化され、seed で再現できる。
状態の遷移は、操作の列を生成して実体とモデルの等価を確かめる stateful な形で突ける。

### 完了条件
性質が CsCheck で書かれ、入出力の不変量を多くの入力で突いている。
状態の遷移が、stateful な形で書かれている。

### 禁止事項
性質の本体を、常に成功する形にして何も検査しないこと。

### 行動
入出力の不変量を性質にし、CsCheck の Sample で多くの入力を突く。
状態の遷移は、実体とモデルを並べる stateful な形で書く。

### 例
固定した一つの入力だけを検査すると、他の入力に対する性質を確かめられない。

```csharp
[Test] public async Task Rev() => await Assert.That(Reverse(Reverse([1, 2, 3]))).IsEqualTo([1, 2, 3]);
```

生成した多くの入力に対して、逆順を二度適用すると元へ戻る性質を検査する。

```csharp
[Test]
public void ReversingTwiceReturnsOriginal() =>
    Gen.Int.Array.Sample(values => values.Reverse().Reverse().SequenceEqual(values));
```
