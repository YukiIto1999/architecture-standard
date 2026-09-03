# tokio-util

用途は、協調的な取り消しを、処理の木へ伝える token の機構である。
採用は、Rust は tokio-util である。
判断基準は、採用済みの非同期基盤と同じ系統で、token の分配と連鎖を担えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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
