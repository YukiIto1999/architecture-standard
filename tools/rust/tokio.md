# Tokio

用途は、非同期の実行を担う runtime である。
採用は、Rust は Tokio である。
判断基準は、runtime を一つに固定でき、タスクの生成・取り消し・channel の扱いを一貫させられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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
