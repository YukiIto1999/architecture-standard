# context-propagation

## 概要
context-propagation は、同一実行に随伴して境界を越える metadata の不変な carrier と伝播の契約を全系で統べる規律である。
principles の [construction](../principles/construction.md) が定める不変の定めを、同一実行に随伴して境界を越える metadata の carrier と伝播の契約として具象化する。

## 文脈を一つにまとめて伝える

### 要求
trace・cancel・principal は一つの request context にまとめて伝え、処理は必要な文脈をその context から受け取る。
相関の識別子を文脈に載せ、境界を越えて伝播させる。
context は不変に保ち、値の追加は新しい context を生む。
境界を越えて伝播する文脈に、秘密や個人情報を載せない。

### 根拠
trace・cancel・principal を別々の経路で引き回すと、引数が増え、伝え漏れが起きる。
一つの context にまとめれば、境界を越える文脈が一貫して伝わる。
相関の識別子を載せれば、分散した処理を一つの流れとして追える。
context を不変にすれば、並行する処理が同じ context を共有しても壊れない。
伝播する文脈は境界を越えて外まで流れるので、秘密や個人情報を載せると漏れる。

### 完了条件
trace・cancel・principal が、一つの request context で伝わっている。
処理が、必要な文脈をその context から受け取っている。
相関の識別子が、境界を越えて伝播している。
request context が不変で、値の追加が新しい context を生んでいる。
境界を越えて伝播する文脈に、秘密や個人情報が載っていない。

### 禁止事項
trace・cancel・principal を、別々の経路で個別に引き回すこと。
相関の識別子を、境界で途切れさせること。
request context を、破壊的に書き換えること。
境界を越えて伝播する文脈に、秘密や個人情報を載せること。

### 行動
文脈を一つの request context にまとめ、境界を越えて伝播させる。
相関の識別子を文脈に載せ、下流と外部呼び出しへ引き継ぐ。

### 例

trace、cancel、principal を別々に引き回すと、引数が増えて伝達漏れが起きる。

```
f(trace, cancel, principal, arg)
```

trace、cancel、principal、相関 ID を一つの context にまとめて伝える。

```
f(context, arg)
```

## 参照
trace の意味と観測への付与は [observability](./observability.md) が正本である。
取り消しと期限の意味は [concurrency](./concurrency.md) が正本である。
actor の構築は [authentication](./authentication.md) が正本である。
載せてよい情報の制限は [privacy](./privacy.md) と [security](./security.md) が正本である。
