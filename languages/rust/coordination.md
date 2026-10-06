# coordination

## 概要
coordination は、Rust で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency/README.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、Rust の機構で満たす。
runtime・構造化並行・取り消し・ブロッキングの隔離・共有状態の規律は、[tokio](./tokio.md) と [tokio-util](./tokio-util.md) が持つ。
資源は所有権と Drop で解放する。

## 資源の解放

### 要求
同期に解放できる資源は所有権と Drop に結び付け、正常終了、失敗、協調取消、panic の unwind で値が破棄される経路で解放する。
子が使う資源の解放順序は [concurrency](../../concerns/concurrency/structured-concurrency.md) の「構造化並行で寿命をスコープに束ねる」に従い、子へ合流してから所有者の資源を drop する。
非同期の close、flush、protocol の終了など await が必要な後始末は、資源の寿命を持つ所有者の明示的な終了処理で完了させ、Drop だけに委ねない。
終了処理は取り消し済みの業務 token で中断せず、元の処理の終了理由と後始末の失敗をともに観測する。
子の panic で Future が破棄されても必要な非同期の後始末を実行できるよう、資源とその終了処理の責任を、子の終了後も存続する所有者に残す。

### 根拠
Drop は値の破棄に同期の解放を結び付けるが、await を実行せず、子の task の終了も待たない。
join による子の終了の観測と所有者の資源の drop を順序付ければ、子の destructor が終わる前に共有資源を閉じない。
非同期の後始末を所有者の終了処理で await すれば、Future の drop によって後始末が始まらない経路を避けられる。
panic の unwind は Future の destructor を呼ぶだけなので、子にだけ資源を持たせると、必要な async の後始末を開始できないまま失う。
process の強制終了や panic=abort は destructor の実行を保証しないため、正常停止とは分けて lifecycle の回復契約で扱う。

### 完了条件
同期の解放が Drop に現れ、子へ合流した後に所有者の資源が破棄されている。
非同期の後始末が所有者の明示的な終了処理で完了まで await され、処理と後始末の失敗がそれぞれ観測されている。
子の panic を JoinError で観測した場合にも、存続する資源の所有者が必要な非同期の後始末を実行している。
Future、JoinHandle、JoinSet の drop を、非同期の後始末または子の完了待ちの代わりにしていない。

### 禁止事項
資源を、`Drop` を実装しない生ハンドルのまま持ち回ること。
同期資源の解放を、Drop でなく呼び出し側の手動の後始末に頼ること。
Drop の中で非同期の後始末を spawn し、別の寿命の所有者がないまま解放済みと扱うこと。
Drop だけで、子の合流や非同期の解放を保証できるとみなすこと。

### 行動
資源を取得したら `Drop` を実装した型でラップし、所有権のスコープを抜けるときに解放させる。
非同期の後始末は所有者の終了処理で await し、全ての子の合流、後始末、所有者の同期資源の drop の順に閉じる。

### 例
生ハンドルを持ち回ると、経路によっては `close` を呼び忘れる。

```rust
struct Connection { handle: RawHandle }
```

同期の解放を Drop に実装すれば、値が破棄される正常終了、失敗、取り消しの経路で、生存期間に対応して解放される。

```rust
struct Connection { handle: RawHandle }
impl Drop for Connection {
    fn drop(&mut self) { close(self.handle); }
}
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency/README.md)、副作用を境界に集める原則は [separation](../../principles/separation/README.md)、効果の取り消しと資源は [effect](../../concerns/effect/README.md)、停止の合図と優雅な終了は [lifecycle](../../concerns/lifecycle/README.md) に従う。
効果の合成は [connection](./connection.md)、永続化される資源は [sqlx](./sqlx.md) に従う。
