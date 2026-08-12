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
子が業務の Err を返した場合と join が JoinError を返した場合のどちらでも、JoinSet::shutdown で残りを取り消して drain し、完了を待ってから失敗を返す。
並行して需要を処理する job task の数は tokio::sync::Semaphore で上限を定める。
共有状態を単一所有する owner task は需要を並行処理する job task ではないため、Semaphore の permit の対象外とする。
job task の permit 待ちは、期限付きの permit 取得と CancellationToken の取消を select! で競わせる。
取消と permit 取得が同時に成立した場合は、取消を先に選び permit を取得しない。

### 根拠
spawn でタスクを投げっぱなしにすると、孤児のタスクが範囲の外で走り続け、失敗も取り消しも追えない。
JoinSet に束ねれば、範囲を抜けるときに残ったタスクが abort され、孤児が残らない。
join_next で範囲の中で回収すれば、失敗が範囲の中で扱える。
固定数の合流は try_join! で、一つの失敗が他の分岐を畳む。
join_next が失敗を返しても残りのタスクを走らせたままにすると、孤児と同じ無駄が残る。
JoinSet::shutdown は abort_all を呼んでから join_next を None が返るまで回すのと同じ動きをするので、取り消しと完了待ちを一度に行える。
job task の並行度を無制限にすると資源が枯渇し外部依存を圧迫するので、tokio::sync::Semaphore で上限を固定する。
単一の owner task に permit を要求すると、job の需要枠を常時一つ消費し、共有状態の直列化という別の役割を並行度制御と混同する。
permit 取得だけを期限で囲うと、CancellationToken が取り消されても permit が空くか期限を迎えるまで待ち続ける。

### 完了条件
並行のタスクが JoinSet で束ねられ、join_next で範囲の中で回収されている。
範囲を抜けたタスクが、残っていない。
子が業務の Err を返した場合と join が JoinError を返した場合のどちらでも、残りが JoinSet::shutdown で取り消され、drain の完了後に失敗が返されている。
並行して需要を処理する job task の数に、tokio::sync::Semaphore で上限が定められている。
単一の owner task が Semaphore の permit を取得せず、親の JoinSet だけで寿命を管理されている。
permit 待ち中に CancellationToken が取り消された job task が、permit を取得せず終了している。

### 禁止事項
spawn で、タスクを範囲の外へ投げっぱなしにすること。
子の失敗を、残りを取り消さずに走らせたまま放置すること。
JoinError だけ、または業務の Err だけを shutdown の契機にし、もう一方で残りを走らせ続けること。
Semaphore の permit を取得せず、JoinSet の並行 job task に需要を実行させること。
単一の owner task に job 用 Semaphore の permit を要求すること。
job task の permit 待ちを期限だけで囲い、CancellationToken の取消と競わせないこと。

### 行動
並行のタスクを JoinSet に束ね、join_next で回収する。
固定数の合流は try_join! で書く。
業務の Err または JoinError を検知したら、JoinSet::shutdown で残りを取り消して drain し、完了を待ってから失敗を返す。
並行 job task の上限は tokio::sync::Semaphore で固定する。
単一の owner task は permit の対象外とし、その寿命だけを親の JoinSet で管理する。
job task の permit 待ちは select! で CancellationToken の取消と競わせ、同時成立時は取消を先に選ぶ。

### 例
`spawn` で投げっぱなしにすると、孤児のタスクが範囲の外で走り続ける。

```rust
for job in jobs { tokio::spawn(run(job)); }
```

`JoinSet` に束ね、各仕事は `Semaphore` の permit を持つ間だけ実行する。業務の失敗と `JoinError` のどちらでも、残りのタスクを停止して回収する。

```rust
let mut set = JoinSet::new();
let permits = Arc::new(Semaphore::new(MAX_IN_FLIGHT));
for job in jobs {
    let permits = Arc::clone(&permits);
    let env = Arc::clone(&env);
    let child = cancellation.child_token();
    set.spawn(async move {
        let remaining = deadline.remaining(env.now())?;
        let _permit = tokio::select! {
            biased;
            _ = child.cancelled() => return Err(JobError::Canceled),
            permit = tokio::time::timeout(remaining, permits.acquire_owned()) => {
                permit
                    .map_err(|_| JobError::DeadlineExceeded)?
                    .map_err(JobError::Permit)?
            }
        };
        if child.is_cancelled() { return Err(JobError::Canceled); }
        run(env.as_ref(), job, deadline, child).await
    });
}
while let Some(result) = set.join_next().await {
    match result {
        Ok(Ok(())) => {}
        Ok(Err(error)) => {
            set.shutdown().await;
            return Err(ScopeError::Job(error));
        }
        Err(error) => {
            set.shutdown().await;
            return Err(ScopeError::Join(error));
        }
    }
}
```

## 取り消し

### 要求
取り消しは CancellationToken で協調して伝え、停止の合図と処理は select! で競わせる。
select! の分岐に置く処理は、cancellation safety を満たすものに限る。
時間の上限は `Deadline` carrier の絶対時刻で表し、request、message、job の境界で一度だけ生成する。
境界より内側の全ての async API は、同じ `Deadline` と CancellationToken を受け取り、下流へ渡す。
各 hop は現在時刻から `Deadline` までの remaining を計算し、その remaining から Tokio の局所 timeout を作る。
局所 timeout が成立した場合は子の CancellationToken を cancel し、同じ絶対期限を渡した下流へ取り消しを伝える。
局所 timeout は処理 future を pin して可変参照だけを待ち、期限成立時は子を cancel した後に同じ future を完了まで drain してから戻る。

### 根拠
future を drop するとその場で止まるが、途中の後始末は保証されない。
CancellationToken で協調して伝えれば、安全な地点まで走らせてから止め、資源を解放できる。
select! は停止の合図と処理を競わせ、合図が来たら処理を止める。
loop の中の select! は分岐が完了するたび他の future を drop して作り直すので、途中まで進んだ状態を保持する処理を置くと進捗が失われる。
`Deadline` を一度だけ作って値のまま渡せば、hop が増えても時間枠の起点は動かない。
各 hop が同じ絶対時刻から remaining を計算すれば、Tokio の timeout はその hop の待ちだけを止めながら、全体の時間上限を越えない。
局所 timeout と CancellationToken を結べば、上流が待ちを打ち切った後も下流の処理を走らせ続けない。
timeout に処理 future の所有権を渡さなければ、期限成立時にも future を drop せず、協調取消を観測した後始末まで待てる。

### 完了条件
取り消しが、CancellationToken で協調して伝えられている。
停止の合図と処理が、select! で競わされている。
select! の分岐の処理が、cancellation safety を満たしている。
絶対時刻の `Deadline` が、request、message、job の境界で一度だけ生成されている。
境界より内側の全ての async API が、同じ `Deadline` と CancellationToken を受け取り下流へ渡している。
各 hop の局所 timeout が、現在時刻から同じ `Deadline` までの remaining から作られている。
局所 timeout が、子の CancellationToken の cancel として下流へ伝播している。
局所 timeout が処理 future の可変参照だけを待ち、期限成立時に子を cancel して同じ future を drain している。

### 禁止事項
cancellation safety を満たさない処理を、loop の中の select! の分岐に置くこと。
hop ごとに相対 timeout を引き直し、新しい時間枠を始めること。
絶対期限を remaining に置き換え、下流へ相対値だけを渡すこと。
`Deadline` または CancellationToken を受け取らない async API を、境界より内側に作ること。
処理 future の所有権を timeout へ渡し、期限成立時に協調取消より先に drop すること。

### 行動
CancellationToken を clone して各タスクへ渡し、cancel で一斉に伝える。
select! で停止の合図と処理を競わせ、合図で安全に止める。
境界で `Deadline` を一度だけ生成し、全ての async API に同じ値と CancellationToken を渡す。
各 hop で `deadline.remaining(clock.now())` を計算し、その値だけを Tokio の局所 timeout に使う。
局所 timeout では子の CancellationToken を cancel し、下流へは remaining でなく元の `Deadline` を渡す。
処理 future を pin し、timeout には可変参照だけを渡し、期限成立時は子を cancel して同じ future を drain する。

### 例
要求の境界で絶対期限を一度だけ生成し、同じ期限を下流へ渡す。局所の timeout には処理 future の可変参照を渡し、期限成立後も協調取消の後始末まで回収する。

```rust
#[derive(Clone, Copy)]
struct Deadline(SystemTime);

impl Deadline {
    fn from_budget(now: SystemTime, budget: Duration) -> Result<Self, DeadlineExceeded> {
        now.checked_add(budget).map(Self).ok_or(DeadlineExceeded)
    }

    fn remaining(self, now: SystemTime) -> Result<Duration, DeadlineExceeded> {
        self.0.duration_since(now).map_err(|_| DeadlineExceeded)
    }
}

let deadline = Deadline::from_budget(env.now(), REQUEST_BUDGET)?;
handle_request(&env, request, deadline, request_token).await?;

async fn handle_request<Env: HasClock + HasStore>(
    env: &Env,
    request: Request,
    deadline: Deadline,
    cancellation: CancellationToken,
) -> Result<Response, RequestError> {
    let remaining = deadline.remaining(env.now())?;
    let child = cancellation.child_token();
    let load_operation = env.store().load(request.id, deadline, child.clone());
    tokio::pin!(load_operation);
    match tokio::time::timeout(remaining, load_operation.as_mut()).await {
        Ok(result) => result,
        Err(_) => {
            child.cancel();
            let _ = load_operation.as_mut().await;
            Err(RequestError::DeadlineExceeded)
        }
    }
}
```

## ブロッキング

### 要求
spawn_blocking に委ねるのは、実行時間が短く、同時実行数に上限を置ける処理に限る。
project は、spawn_blocking に渡す処理の最大実行時間と permit 数を ADR に記録する。
spawn_blocking は、Semaphore の permit を先に取得する共通 wrapper からだけ呼ぶ。
共通 wrapper の permit 待ちは、CancellationToken の取消を先頭に置いた biased な select! で、期限付きの permit 取得と競わせる。
permit 取得後にも CancellationToken を再確認し、取り消されていれば spawn_blocking を開始せず permit を解放する。
共通 wrapper の外から spawn_blocking を直接呼ぶことは、clippy の disallowed_methods と構造検査で拒否する。
長く走るブロッキング処理は、専用の process へ分離するか、取り消しを確認できる短い chunk に分ける。
開始済みのブロッキング処理は abort で停止できると扱わない。
非同期のタスクの中で、同期の I/O を直接呼ばない。

### 根拠
非同期のタスクの中で同期の I/O を直接呼ぶと、実行のスレッドが塞がり、同じスレッドの他のタスクが進まない。
spawn_blocking に委ねれば、ブロッキングが専用のスレッドで走り、非同期の実行を塞がない。
共通 wrapper が permit を取得してから起動すれば、blocking pool の大きさとは独立に application が開始する処理数を制限できる。
permit 待ちを CancellationToken と競わせれば、親取消後に permit が空くか期限を迎えるまで待ち続けない。
permit 取得後に取消を再確認すれば、select! の完了直後に成立した取消で新しいブロッキング処理を始めない。
直接呼び出しを検査で拒否すれば、permit を経由しない経路を作れない。
開始済みの spawn_blocking は abort しても処理が続くため、停止の手段として使えない。
長い処理を専用の process へ分けるか短い chunk にすれば、停止時に新しい仕事を止め、区切りで終了を判断できる。

### 完了条件
spawn_blocking の処理が、短く、同時実行数に上限を持っている。
最大実行時間と permit 数が、project の ADR に記録されている。
全ての spawn_blocking が、permit を取得する共通 wrapper から呼ばれている。
共通 wrapper の permit 待ちが、CancellationToken の取消を先頭に置いた biased な select! で期限付き permit 取得と競わされている。
permit 取得後に CancellationToken が再確認され、取り消されていれば spawn_blocking が開始されず permit が解放されている。
共通 wrapper が開始する同時実行数が、記録した permit 数を超えないことを実行テストで確かめている。
処理が最大実行時間を超えないことを、計測テストとレビューで確かめている。
長いブロッキング処理が、専用の process または取り消しを確認する短い chunk に分離されている。
開始済みのブロッキング処理を、abort で停止できる前提にしていない。
非同期のタスクの中で、同期の I/O を直接呼んでいない。

### 禁止事項
非同期のタスクの中で、同期の I/O を直接呼ぶこと。
共通 wrapper の外から、spawn_blocking を直接呼ぶこと。
ADR に記録した permit 数を経由せず、ブロッキング処理を起動すること。
共通 wrapper の permit 待ちを期限だけで囲い、CancellationToken の取消と競わせないこと。
permit 取得後に CancellationToken を再確認せず、spawn_blocking を開始すること。
長く走る処理や同時実行数を制限できない処理を、spawn_blocking に渡すこと。
開始済みのブロッキング処理を、abort で停止できると扱うこと。

### 行動
spawn_blocking に渡す処理の最大実行時間と permit 数を、project の ADR に記録する。
Semaphore の permit を取得してから spawn_blocking を呼ぶ共通 wrapper を一つ作る。
共通 wrapper の permit 待ちは、CancellationToken の取消を先頭に置いた biased な select! で期限付き permit 取得と競わせる。
permit 取得後に CancellationToken を再確認し、取り消されていれば permit を解放して終了する。
共通 wrapper 内の呼び出しだけを局所的に許可し、それ以外は clippy の disallowed_methods と構造検査で拒否する。
共通 wrapper の同時実行数を実行テストで測り、記録した permit 数を超えないことを確かめる。
各処理の実行時間を計測テストで測り、記録した最大実行時間を超えないことを確かめる。
長く走る処理は専用の process へ分けるか、各 chunk の間で CancellationToken を確認する形へ分割する。

### 例
`disallowed_methods` の局所許可は、blocking job を期限と取り消しの規律に接続する wrapper だけに置く。

```rust
#[allow(clippy::disallowed_methods)]
async fn run_blocking<Env: HasClock>(
    env: &Env,
    job: BlockingJob,
    deadline: Deadline,
    cancellation: CancellationToken,
) -> Result<Output, BlockingError> {
    let remaining = deadline.remaining(env.now())?;
    let permit = tokio::select! {
        biased;
        _ = cancellation.cancelled() => return Err(BlockingError::Canceled),
        permit = tokio::time::timeout(
            remaining,
            BLOCKING_PERMITS.clone().acquire_owned(),
        ) => permit.map_err(|_| BlockingError::DeadlineExceeded)??,
    };
    if cancellation.is_cancelled() {
        drop(permit);
        return Err(BlockingError::Canceled);
    }
    let output = tokio::task::spawn_blocking(move || {
        let _permit = permit;
        job.run()
    }).await??;
    deadline.remaining(env.now())?;
    Ok(output)
}
```

## 共有状態

### 要求
可変の共有状態は bounded な mpsc channel を受け取る単一のタスクへ閉じ込める。

### 根拠
可変の共有状態を複数のタスクから触ると、非同期の織り込みで状態が壊れる。
単一のタスクへ閉じ込め mpsc channel で受け渡せば、状態を触るのが一つのタスクだけになり、競合が起きない。
bounded な channel は、送り手が詰まったときに背圧をかける。
同じ目的に lock を併用すると、状態更新の経路が channel と lock に分かれ、単一所有の境界が崩れる。

### 完了条件
可変の共有状態が、bounded な mpsc channel を受け取る単一のタスクへ閉じ込められている。
状態を更新する全ての経路が、その channel に集まっている。

### 禁止事項
可変の共有状態を、複数のタスクから直接触ること。
同じ状態を、channel と lock の二つの経路から更新すること。
可変の共有状態を、unbounded な channel へ流すこと。

### 行動
可変の共有状態を単一のタスクへ閉じ込め、bounded な mpsc channel で受け渡す。

### 例
`Arc<Mutex>` を複数のタスクから直接触ると、状態の所有者が定まらない。

```rust
let shared = Arc::new(Mutex::new(state));
```

状態は bounded channel を受け取る単一の owner task に閉じ込め、その寿命を親の `JoinSet` で管理する。

```rust
let (sender, mut receiver) = mpsc::channel(64);
let mut parent_set = JoinSet::new();
parent_set.spawn(async move {
    while let Some(command) = receiver.recv().await {
        state.apply(command)?;
    }
    Ok::<(), OwnerError>(())
});

drop(sender);
while let Some(result) = parent_set.join_next().await {
    match result {
        Ok(Ok(())) => {}
        Ok(Err(error)) => {
            parent_set.shutdown().await;
            return Err(ScopeError::Owner(error));
        }
        Err(error) => {
            parent_set.shutdown().await;
            return Err(ScopeError::Join(error));
        }
    }
}
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
効果の合成は [connection](./connection.md)、永続化される資源は [retention](./retention.md) に従う。
