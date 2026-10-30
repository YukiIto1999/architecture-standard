# tokio-util

用途は、協調的な取り消しを、処理の木へ伝える token の機構である。
採用は、Rust は tokio-util である。
判断基準は、採用済みの非同期基盤と同じ系統で、token の分配と連鎖を担えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 取り消し

### 要求
取り消しは CancellationToken で協調して伝え、停止の合図と処理は select! で競わせる。
select! の分岐に置く処理は、cancellation safety を満たすものに限る。
取り消し要求、処理の完了、資源解放前の合流は [concurrency](../../concerns/concurrency/structured-concurrency.md) の「構造化並行で寿命をスコープに束ねる」に従う。
CancellationToken::cancel と cancelled の完了は要求の通知であり、task の終了確認には所有者が保持する JoinSet または JoinHandle の join を使う。
時間の上限は `Deadline` carrier の絶対時刻で表し、request、message、job の境界で一度だけ生成する。
境界より内側の async API は、非取消の後始末を除き、同じ Deadline と CancellationToken を受け取り、下流へ渡す。
この Deadline と CancellationToken は、[context-propagation](../../concerns/context-propagation/unified-request-context.md) の「実行文脈の由来と寿命を保って伝える」に従う実行 metadata を個別の引数へ取り出した値とし、認証主体や業務入力と一つの context の型にまとめない。
同期の純粋な domain の関数には、Deadline と CancellationToken の引数を要求しない。
非同期の close や所有者の終了処理は、元の Deadline を保持する非取消の後始末として token による中断から外す。
`Deadline` から Tokio の timeout を作るのは、`Deadline` を生成した境界の所有者だけとする。
境界の所有者は、現在時刻から `Deadline` までの remaining で timeout を作り、成立したら子の CancellationToken を cancel して、同じ絶対期限を渡した下流へ取り消しを伝える。
境界の timeout は処理 future を pin して可変参照だけを待ち、成立したことを自身の状態として持ち、成立時は子を cancel した後に同じ future を完了まで drain してから戻る。
境界の内側の hop は、受け取った CancellationToken を子へ渡し、`Deadline` から別の timeout を作らない。
協調取消に応答した子は必要な後始末を await し、業務の Result と区別した取消の終了通知を所有者へ返す。
`Deadline` を生成した境界の所有者は、自身の Deadline の超過を想定内の失敗として受け取り、親の CancellationToken の取り消しは取消の終了通知のまま通す。
境界の所有者は、drain した出力が取消の終了通知のとき、判定の時点で親の CancellationToken が取り消し済みなら、期限の超過が併存していても取消の終了通知のまま返す。
親の token が取り消されておらず自身の timeout が成立していれば、境界の error の期限超過の variant を持つ Err で終える。
親の token も自身の timeout も成立していない取消の終了通知は、adapter を経ずに境界へ届いた写し損ねなので、取消にも期限超過にもせず、不変条件の違反として panic で表す。
境界の内側の hop は、子の取消を、自身の error へ写さず取消の終了通知で終える。
呼び出しごとの時間上限は、adapter が `Deadline` から導かない自身の `tokio::time::timeout` で設け、その `Elapsed` を自身の状態として持ち、reqwest の `timeout`・`read_timeout`・`connect_timeout` を上限の手段にしない。
協調取消と非同期の後始末を持たない末端の future(reqwest の要求など)は、呼び出しごとの時間上限の超過で drop してよい。
上限を設けた側は、自身が中断させた終了(自身の timeout の成立か受け取った CancellationToken の取り消しによる future の drop)にだけ、受け取った token が取り消し済みなら取消の終了通知のまま通し、そうでなく自身の timeout が成立していれば自身の想定内の失敗として受け取る。
下位の層(reqwest や OS の timeout など)が返した Err は確定した終了であり、token や自身の timeout の状態を見ずに、adapter が通信の失敗へ写す。
協調取消または非同期の後始末を持つ future は、子の完了と取消または timeout の成立が競合したとき、drain した同じ future の出力が終了を決める。
drain した出力が業務の Result または後始末の欠陥なら、期限の超過や取消で書き換えず、それぞれ観測し、期限を越えていれば診断として記録する。

### 根拠
処理 Future の drop はその Future の状態を破棄するが、spawn した task を終了させるとは限らず、非同期の後始末を実行しない。
CancellationToken の cancel は listener を起こすための要求であり、listener が取消を観測して終了するまでの待機は含まない。
select! は選ばれなかった分岐を drop するため、合図を選んだことだけで処理の後始末も完了したとは扱えない。
loop 内で未完了の分岐を作り直すと進捗が失われ得るので、drop による取消の安全性と、完了まで保持して回収する所有者を区別する。
`Deadline` を一度だけ作って値のまま渡せば、hop が増えても時間枠の起点は動かない。
境界が一つの timeout を作り、内側が受け取った token を引き継げば、通常処理の待機期限を引き直さずに済むが、取消後の drain がその期限内に終わる保証にはならない。
adapter が依存先の呼び出しに設ける上限は、[resilience](../../concerns/resilience/dependency-call-control.md) の「外部依存の呼び出しを制御する層に置く」が定める port 層の上限であり、`Deadline` から導かず、受け取った token と合わせて短い方を採るので、境界の時間枠を引き直さない。
Deadline と CancellationToken を個別の引数で渡せば、Tokio の協調取消と remaining の計算をそのまま使いながら、期限の起点と取消の系統を保てる。
同期の純粋な domain の関数は期限も取消も観測しないので、引数を要求しても使われない値が核へ入るだけである。
境界の timeout と CancellationToken を結び、所有者が同じ処理を回収すれば、期限成立後に新しい外部効果を始めず、必要な後始末を待てる。
協調取消または非同期の後始末を持つ future は、timeout に所有権を渡さなければ、期限成立時にも future を drop せず、協調取消を観測した後始末まで待てる。
協調取消も非同期の後始末も持たない末端の future は、drop が失うものが無く、drop の他に止める手段も無いので、上限の超過で drop すれば上限が効き、drain の規則を掛けると要求の完了まで待ち続けて上限が効かない。
下位の層の timeout は全ての経路で外せないので、下位の層が返した Err を確定した終了として、adapter が通信の失敗へ写す。
reqwest の timeout を上限の手段にすると、超過が通信の失敗になり時間上限の超過にならない。
`tokio::time::timeout` は内側の future を先に poll するので、期限と同時に完了した出力は、期限切れより先に Ok として返る。
select! は既定で分岐を無作為な順に評価するので、完了と取消が同時に成立すると、完了済みの処理が取消の分岐に負け得る。
取消または期限の成立の後も、pin した同じ future を drain すれば、完了済みの出力も取消に応答した終了通知も失わず、その出力が終了を決める。
CancellationToken と取消の終了通知は取り消しの原因を持たないので、取り消しの原因は、上限を設けた側が所有する状態で判定する。
各 hop が `Deadline` から別の timeout を作ると、hop の timeout が先に成立した取消の終了通知が境界へ届いたとき、境界は自身の timeout の成立を観測しておらず、期限の超過を自身の状態で判定できない。
timeout を境界の一つにすれば、期限の超過は境界が所有する timeout の成立の状態で判定でき、内側の取消は親の取り消しか境界の取消のどちらかとして届く。
境界は、親の token と自身の timeout のどちらからも説明できない取消の終了通知を、期限の超過と推測しない。
親の token が取り消されていれば結果を要らなくなった側が居るので、期限も超過していても取り消しとして通す。
Deadline の超過は、境界にとって応答や再試行を決める必要のある結果であり、結果を要らなくなった親の取り消しとは扱いが異なる。
境界の内側の子に伝わるのは、結果を待たなくなったことだけなので、子は取消の終了通知で終える。
完了した業務の Result や後始末の欠陥を、後から観測した期限の超過や取消で書き換えると、成功した書き込みが失敗として報告され、呼び出し側が重複した再実行を始める。

### 完了条件
取り消しが、CancellationToken で協調して伝えられている。
停止の合図と処理が、select! で競わされている。
select! の分岐の処理が、cancellation safety を満たしている。
絶対時刻の `Deadline` が、request、message、job の境界で一度だけ生成されている。
境界より内側の async API が、非取消の後始末を除き、同じ Deadline と CancellationToken を受け取り下流へ渡している。
非取消の後始末が元の Deadline を保持し、取消済みの token で中断されていない。
`Deadline` から Tokio の timeout を作るのが、境界の所有者だけである。
境界の timeout の成立が、子の CancellationToken の cancel として下流へ伝播している。
境界の timeout が処理 future の可変参照だけを待ち、成立を状態として持ち、成立時に子を cancel して同じ future を drain している。
境界の内側の hop が、受け取った CancellationToken を子へ渡し、`Deadline` から別の timeout を作っていない。
adapter の呼び出しごとの時間上限が、`Deadline` から導かれていない。
cancelled の完了後も子が動いている状態を処理の終了と扱わず、全ての子の終了と後始末を join で回収している。
取消の終了通知が業務の失敗の Result と区別され、drain 中の業務の失敗や後始末の欠陥も観測されている。
`Deadline` を生成した境界の所有者が、判定の時点で親の CancellationToken が取り消されておらず自身の timeout が成立している取消の終了通知だけを、境界の error の期限超過の variant を持つ Err で終えている。
親の CancellationToken が取り消し済みの取消の終了通知が、期限の超過が併存していても取消の終了通知のまま返されている。
親の token も自身の timeout も成立していない取消の終了通知が、adapter を経ずに届いた写し損ねとして、取消にも期限超過にもならず、panic で欠陥として表されている。
呼び出しごとの時間上限が、reqwest の timeout でなく設けた側の `timeout` で設けられ、自身が中断させた終了では受け取った token、自身の `Elapsed` の順に判定されて、時間上限の超過だけが設けた側の想定内の失敗になり、下位の層が返した Err が token や自身の timeout の状態によらず通信の失敗へ写されている。
協調取消と非同期の後始末を持たない末端の future が上限の超過で drop され、協調取消または非同期の後始末を持つ future が drain されている。
協調取消または非同期の後始末を持つ future で、完了と取消または timeout の成立が競合したとき、drain した出力が終了を決め、業務の Result と後始末の欠陥が期限超過や取消へ書き換えられず、期限の超過が診断に記録されている。
同期の純粋な domain の関数が Deadline と CancellationToken を引数に持たず、Deadline と CancellationToken が認証主体や業務入力と同じ context の型にまとめられていない。

### 禁止事項
cancellation safety を満たさない処理を、loop の中の select! の分岐に置くこと。
境界の `Deadline` から、hop ごとに相対 timeout を引き直し、新しい時間枠を始めること。
絶対期限を remaining に置き換え、下流へ相対値だけを渡すこと。
非取消の後始末でないのに、Deadline または CancellationToken を受け取らない async API を境界より内側に作ること。
同期の純粋な domain の関数へ、Deadline または CancellationToken を要求すること。
Deadline と CancellationToken を、認証主体や業務入力を含む一つの context の型へまとめること。
協調取消または非同期の後始末を持つ処理 future の所有権を timeout や `CancellationToken::run_until_cancelled` へ渡し、取消または期限の成立時に協調取消より先に drop すること。
CancellationToken::cancel、cancelled、処理 Future の drop だけで、spawn した子と非同期の後始末が完了したと扱うこと。
drain の結果を捨て、後始末の失敗を期限超過または取消で隠すこと。
`Deadline` を生成した境界の所有者で、自身の Deadline の超過を取消の終了通知のまま返すこと。
親の CancellationToken が取り消し済みの取消の終了通知を、期限超過へ写すこと。
境界の内側の hop で、`Deadline` から別の timeout を作ること。
親の token が取り消されていないことだけから、取消の終了通知を期限超過と推測すること。
親の token も自身の timeout も成立していない取消の終了通知を、境界で取消または期限超過として返すこと。
reqwest の timeout を、呼び出しごとの時間上限の手段にすること。
協調取消も非同期の後始末も持たない末端の future に drain の規則を掛け、呼び出しごとの時間上限を効かなくすること。
完了した業務の Result、下位の層が返した Err、後始末の欠陥を、後から観測した取消や期限の超過で別の終了へ書き換えること。

### 行動
CancellationToken を clone して各タスクへ渡し、cancel で一斉に伝える。
select! には drop による取消が安全な処理か、所有者が後で回収できる pin 済み Future または保持した JoinHandle の可変参照を置く。
境界で Deadline を一度だけ生成し、非取消の後始末を除く全ての async API に同じ値と CancellationToken を渡す。
境界で `deadline.remaining(clock.now())` を計算し、その値だけを Tokio の timeout に使う。
境界の timeout では子の CancellationToken を cancel し、下流へは remaining でなく元の `Deadline` と子の token を渡し、内側の hop は受け取った token を子へ渡す。
同期の純粋な domain の関数からは Deadline と CancellationToken を除き、効果を実行する async API だけが個別の引数で受ける。
処理 future を pin し、timeout には可変参照だけを渡し、timeout の成立を状態として持ち、成立時は子を cancel して同じ future を drain する。
非同期の後始末を token による中断から外し、子の取消の終了通知と drain 中の失敗を別々に所有者へ回収する。
境界の所有者は、drain した出力が取消の終了通知なら、親の CancellationToken が取り消し済みなら取消の終了通知のまま、そうでなく自身の timeout が成立していれば境界の error の期限超過の variant を持つ Err で、どちらでもなければ panic で返す。
内側の hop は、子の取消を、取消の終了通知のまま所有者へ返す。
呼び出しごとの時間上限は、設けた側が自身の `timeout` で設け、自身が中断させた終了では受け取った token、自身の `Elapsed` の順に判定し、下位の層が返した Err は状態を見ずに通信の失敗へ写す。
協調取消と非同期の後始末を持たない末端の future は上限の超過で drop し、それ以外の future は drain する。
drain した出力が業務の Result または後始末の欠陥なら、期限の超過や取消で書き換えず、期限を越えていれば診断へ記録する。

### 例
協調取消または非同期の後始末を持つ処理 future の所有権を timeout へ渡すと、期限成立時に drain の前に drop され、完了済みの出力も必要な後始末も失う。

```rust
match timeout(deadline.remaining(clock.now()), handle(parent.child_token(), deadline)).await {
    Ok(exit) => exit,
    Err(_) => Exit::Done(Err(HandleError::DeadlineExceeded)),
}
```

境界の所有者は、処理 future を pin して可変参照だけを timeout へ渡し、成立を状態として持ち、成立時に子を cancel して同じ future を drain する。
drain した出力が取消の終了通知のとき、親の CancellationToken が取り消し済みなら取消のまま、そうでなく自身の timeout が成立していれば期限超過の Err へ写し、どちらでもなければ panic にする。
取消の終了通知以外は書き換えず、期限を越えていれば診断へ記録する。

```rust
let child = parent.child_token();
let mut work = pin!(handle(child.clone(), deadline));
let mut expired = false;
let exit = match timeout(deadline.remaining(clock.now()), &mut work).await {
    Ok(exit) => exit,
    Err(_) => {
        expired = true;
        child.cancel();
        work.await
    }
};
match exit {
    Exit::Cancelled if parent.is_cancelled() => Exit::Cancelled,
    Exit::Cancelled if expired => Exit::Done(Err(HandleError::DeadlineExceeded)),
    Exit::Cancelled => panic!("取消の終了通知の原因が、親の token でも境界の timeout でもない"),
    other => {
        if deadline.remaining(clock.now()).is_zero() {
            diagnostics.record_overrun(deadline);
        }
        other
    }
}
```

adapter が依存先の呼び出しに設ける上限は、`Deadline` から導かない自身の timeout で、末端の要求の future を包む。
受け取った token と同時に待ち、上限の超過は drop で止め、自身が drop した終了では取り消しと重なれば取り消しを優先し、要求が返した Err は状態を見ずに通信の失敗へ写す。

```rust
async fn send(&self, order: Order, token: &CancellationToken) -> Exit<Receipt, SendFailure> {
    if token.is_cancelled() {
        return Exit::Cancelled;
    }
    let outcome = tokio::select! {
        biased;
        sent = timeout(CALL_LIMIT, self.http.send(order)) => sent,
        _ = token.cancelled() => return Exit::Cancelled,
    };
    match outcome {
        Ok(received) => Exit::Done(received.map_err(SendFailure::Communication)),
        Err(_) if token.is_cancelled() => Exit::Cancelled,
        Err(_) => Exit::Done(Err(SendFailure::TimeLimitExceeded)),
    }
}
```

