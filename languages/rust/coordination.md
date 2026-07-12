# coordination

## 概要
coordination は、Rust で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、Rust の機構で満たす。
取り消しは Future の drop と CancellationToken の協調で計算全体へ伝播し、[effect](../../concerns/effect.md) の取り消しの終了を実現する。
資源は所有権と Drop で解放する。

## runtime

### 要求
非同期の runtime は、タスクの生成・取り消し・channel の扱いが一貫するよう単一に固定する。これを Tokio で満たす。

### 根拠
非同期の runtime を一つに固定すれば、タスクの生成・取り消し・channel の扱いが一貫する。
runtime が混在すると、future の実行と待ち合わせの前提が食い違う。

### 完了条件
非同期の runtime が、Tokio に固定されている。

### 禁止事項
複数の非同期 runtime を、混在させること。

### 行動
非同期の実行を Tokio に統一する。

## 構造化並行

### 要求
並行のタスクは JoinSet で束ね、join_next で完了と失敗を範囲の中で回収する。
範囲を抜けたタスクを残さず、固定数の合流は try_join! を使う。
子の一つが失敗したら、JoinSet::shutdown で残りを取り消し、完了を待ってから失敗を返す。
並行して走らせる数は tokio::sync::Semaphore で上限を定める。

### 根拠
spawn でタスクを投げっぱなしにすると、孤児のタスクが範囲の外で走り続け、失敗も取り消しも追えない。
JoinSet に束ねれば、範囲を抜けるときに残ったタスクが abort され、孤児が残らない。
join_next で範囲の中で回収すれば、失敗が範囲の中で扱える。
固定数の合流は try_join! で、一つの失敗が他の分岐を畳む。
join_next が失敗を返しても残りのタスクを走らせたままにすると、孤児と同じ無駄が残る。
JoinSet::shutdown は abort_all を呼んでから join_next を None が返るまで回すのと同じ動きをするので、取り消しと完了待ちを一度に行える。
並行度を無制限にすると資源が枯渇し外部依存を圧迫するので、tokio::sync::Semaphore で上限を固定する。

### 完了条件
並行のタスクが JoinSet で束ねられ、join_next で範囲の中で回収されている。
範囲を抜けたタスクが、残っていない。
子の一つが失敗したとき、残りが JoinSet::shutdown で取り消され、完了を待ってから失敗が返されている。
並行して走る数に、tokio::sync::Semaphore で上限が定められている。

### 禁止事項
spawn で、タスクを範囲の外へ投げっぱなしにすること。
子の失敗を、残りを取り消さずに走らせたまま放置すること。

### 行動
並行のタスクを JoinSet に束ね、join_next で回収する。
固定数の合流は try_join! で書く。
子の失敗を検知したら、JoinSet::shutdown で残りを取り消し、完了を待ってから失敗を返す。
並行度の上限は tokio::sync::Semaphore で固定する。

### 例
```rust
// spawn で投げっぱなし。孤児のタスクが範囲の外で走り続ける
for job in jobs { tokio::spawn(run(job)); }

// JoinSet に束ね、一つの失敗で残りを取り消し、完了を待ってから返す
let mut set = JoinSet::new();
for job in jobs { set.spawn(run(job)); }
while let Some(result) = set.join_next().await {
    if let Err(error) = result? {
        set.shutdown().await; // abort_all してから残りタスクの終了を待つ
        return Err(error);
    }
}
```

## 取り消し

### 要求
取り消しは CancellationToken で協調して伝え、停止の合図と処理は select! で競わせる。
select! の分岐に置く処理は、cancellation safety を満たすものに限る。
絶対期限を文脈に載せて下流へ伝える機構は、標準が固定せず project が単一の採用を ADR に明記する。

### 根拠
future を drop するとその場で止まるが、途中の後始末は保証されない。
CancellationToken で協調して伝えれば、安全な地点まで走らせてから止め、資源を解放できる。
select! は停止の合図と処理を競わせ、合図が来たら処理を止める。
loop の中の select! は分岐が完了するたび他の future を drop して作り直すので、途中まで進んだ状態を保持する処理を置くと進捗が失われる。
絶対期限を運ぶ文脈の型は project ごとの選択が割れやすいので、CancellationToken のような取り消しの協調とは別に、project の ADR に単一採用を明記させる。

### 完了条件
取り消しが、CancellationToken で協調して伝えられている。
停止の合図と処理が、select! で競わされている。
select! の分岐の処理が、cancellation safety を満たしている。

### 禁止事項
cancellation safety を満たさない処理を、loop の中の select! の分岐に置くこと。

### 行動
CancellationToken を clone して各タスクへ渡し、cancel で一斉に伝える。
select! で停止の合図と処理を競わせ、合図で安全に止める。

### 例
```rust
// 停止の合図と処理を select! で競わせる
loop {
    tokio::select! {
        _ = token.cancelled() => break,       // 合図で止める
        item = receiver.recv() => handle(item),     // cancel safe な受信に限る
    }
}
```

## ブロッキング

### 要求
ブロッキングの処理は spawn_blocking に委ね、非同期のタスクの中で同期の I/O を直接呼ばない。

### 根拠
非同期のタスクの中で同期の I/O を直接呼ぶと、実行のスレッドが塞がり、同じスレッドの他のタスクが進まない。
spawn_blocking に委ねれば、ブロッキングが専用のスレッドで走り、非同期の実行を塞がない。

### 完了条件
ブロッキングの処理が、spawn_blocking に委ねられている。
非同期のタスクの中で、同期の I/O を直接呼んでいない。

### 禁止事項
非同期のタスクの中で、同期の I/O を直接呼ぶこと。

### 行動
ブロッキングの処理を spawn_blocking に委ねる。

## 共有状態

### 要求
可変の共有状態は bounded な mpsc channel を受け取る単一のタスクへ閉じ込める。
lock を await をまたいで保持せず、await をまたぐ必要がある lock は tokio::sync の Mutex を使う。

### 根拠
可変の共有状態を複数のタスクから触ると、非同期の織り込みで状態が壊れる。
単一のタスクへ閉じ込め mpsc channel で受け渡せば、状態を触るのが一つのタスクだけになり、競合が起きない。
bounded な channel は、送り手が詰まったときに背圧をかける。
await をまたいで lock を保持すると、待っている間に他のタスクが同じ lock を待ち、長い待ちやデッドロックを招く。

### 完了条件
可変の共有状態が、bounded な mpsc channel を受け取る単一のタスクへ閉じ込められている。
std の lock が、await をまたいで保持されていない。
await をまたぐ lock が、tokio::sync の Mutex を使っている。

### 禁止事項
可変の共有状態を、複数のタスクから直接触ること。
std の lock を、await をまたいで保持すること。

### 行動
可変の共有状態を単一のタスクへ閉じ込め、bounded な mpsc channel で受け渡す。
await をまたぐ lock は tokio::sync の Mutex を使う。

### 例
```rust
// 可変の共有状態を Arc<Mutex> で複数タスクが触り、lock を await をまたいで保持する
let shared = Arc::new(Mutex::new(state));

// 状態を単一のタスクへ閉じ込め、mpsc で受け渡す
let (sender, mut receiver) = mpsc::channel(64);   // bounded で背圧をかける
tokio::spawn(async move { while let Some(command) = receiver.recv().await { state.apply(command); } });
```

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
```rust
// 生ハンドルを持ち回り、経路によっては close を呼び忘れる
struct Connection { handle: RawHandle }

// Drop に解放を実装し、所有権のスコープで必ず解放する
struct Connection { handle: RawHandle }
impl Drop for Connection {
    fn drop(&mut self) { close(self.handle); } // 成功・失敗・取り消しのいずれでも呼ばれる
}
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency.md)、副作用を境界に集める原則は [separation](../../principles/separation.md)、効果の取り消しと資源は [effect](../../concerns/effect.md)、停止の合図と優雅な終了は [lifecycle](../../concerns/lifecycle.md) に従う。
効果の合成は [connection](./connection.md)、永続化される資源は [retention](./retention.md) に従う。
