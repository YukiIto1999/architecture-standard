# coordination

## 概要
coordination は、Rust で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、Rust の機構で満たす。
runtime・構造化並行・取り消し・ブロッキングの隔離・共有状態の規律は、[tokio](./tokio.md) と [tokio-util](./tokio-util.md) が持つ。
資源は所有権と Drop で解放する。

## 資源の解放

### 要求
資源の取得と解放は所有権と `Drop` に一致させ、解放を値の生存期間に結び付ける。
通常の経路だけでなく、失敗や取り消しで途中で抜ける経路でも `Drop` が必ず走るようにする。

### 根拠
Rust の所有権と `Drop` は、値が生存期間を抜けるときに必ず解放を呼ぶ言語機構である。
生存期間に解放を結び付ければ、成功・失敗・取り消しのどの経路で抜けても、`Drop` が一度だけ解放する。
効果システムを言語の効果型に重ねない方針([connection](./connection.md))と同じく、資源の解放にも別の combinator を重ねず、言語の所有権機構をそのまま使う。

### 完了条件
資源の解放が、`Drop` の実装に現れている。
資源の取得と解放が、一つの値の生存期間に一致している。
失敗や取り消しの経路でも、`Drop` が解放を実行している。

### 禁止事項
資源を、`Drop` を実装しない生ハンドルのまま持ち回ること。
資源の解放を、呼び出し側の手動の後始末に頼ること。

### 行動
資源を取得したら `Drop` を実装した型でラップし、所有権のスコープを抜けるときに解放させる。

### 例
生ハンドルを持ち回ると、経路によっては `close` を呼び忘れる。

```rust
struct Connection { handle: RawHandle }
```

`Drop` に解放を実装すれば、成功、失敗、取り消しのどの経路でも、所有権のスコープを抜けるときに解放される。

```rust
struct Connection { handle: RawHandle }
impl Drop for Connection {
    fn drop(&mut self) { close(self.handle); }
}
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency.md)、副作用を境界に集める原則は [separation](../../principles/separation.md)、効果の取り消しと資源は [effect](../../concerns/effect.md)、停止の合図と優雅な終了は [lifecycle](../../concerns/lifecycle.md) に従う。
効果の合成は [connection](./connection.md)、永続化される資源は [sqlx](./sqlx.md) に従う。
