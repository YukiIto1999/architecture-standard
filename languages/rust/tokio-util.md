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
非同期の close や所有者の終了処理は、元の Deadline を保持する非取消の後始末として token による中断から外す。
各 hop は現在時刻から `Deadline` までの remaining を計算し、その remaining から Tokio の局所 timeout を作る。
局所 timeout が成立した場合は子の CancellationToken を cancel し、同じ絶対期限を渡した下流へ取り消しを伝える。
局所 timeout は処理 future を pin して可変参照だけを待ち、期限成立時は子を cancel した後に同じ future を完了まで drain してから戻る。
協調取消に応答した子は必要な後始末を await し、業務の Result と区別した取消の終了通知を所有者へ返す。
drain で得た業務の失敗または後始末の欠陥は、期限切れの報告で上書きせず、それぞれ観測する。

### 根拠
処理 Future の drop はその Future の状態を破棄するが、spawn した task を終了させるとは限らず、非同期の後始末を実行しない。
CancellationToken の cancel は listener を起こすための要求であり、listener が取消を観測して終了するまでの待機は含まない。
select! は選ばれなかった分岐を drop するため、合図を選んだことだけで処理の後始末も完了したとは扱えない。
loop 内で未完了の分岐を作り直すと進捗が失われ得るので、drop による取消の安全性と、完了まで保持して回収する所有者を区別する。
`Deadline` を一度だけ作って値のまま渡せば、hop が増えても時間枠の起点は動かない。
各 hop が同じ絶対時刻から remaining を計算すれば、通常処理の待機期限を引き直さずに済むが、取消後の drain がその期限内に終わる保証にはならない。
局所 timeout と CancellationToken を結び、所有者が同じ処理を回収すれば、期限成立後に新しい外部効果を始めず、必要な後始末を待てる。
timeout に処理 future の所有権を渡さなければ、期限成立時にも future を drop せず、協調取消を観測した後始末まで待てる。

### 完了条件
取り消しが、CancellationToken で協調して伝えられている。
停止の合図と処理が、select! で競わされている。
select! の分岐の処理が、cancellation safety を満たしている。
絶対時刻の `Deadline` が、request、message、job の境界で一度だけ生成されている。
境界より内側の async API が、非取消の後始末を除き、同じ Deadline と CancellationToken を受け取り下流へ渡している。
非取消の後始末が元の Deadline を保持し、取消済みの token で中断されていない。
各 hop の局所 timeout が、現在時刻から同じ `Deadline` までの remaining から作られている。
局所 timeout が、子の CancellationToken の cancel として下流へ伝播している。
局所 timeout が処理 future の可変参照だけを待ち、期限成立時に子を cancel して同じ future を drain している。
cancelled の完了後も子が動いている状態を処理の終了と扱わず、全ての子の終了と後始末を join で回収している。
取消の終了通知が業務の失敗の Result と区別され、drain 中の業務の失敗や後始末の欠陥も観測されている。

### 禁止事項
cancellation safety を満たさない処理を、loop の中の select! の分岐に置くこと。
hop ごとに相対 timeout を引き直し、新しい時間枠を始めること。
絶対期限を remaining に置き換え、下流へ相対値だけを渡すこと。
非取消の後始末でないのに、Deadline または CancellationToken を受け取らない async API を境界より内側に作ること。
処理 future の所有権を timeout へ渡し、期限成立時に協調取消より先に drop すること。
CancellationToken::cancel、cancelled、処理 Future の drop だけで、spawn した子と非同期の後始末が完了したと扱うこと。
drain の結果を捨て、後始末の失敗を期限切れまたは取消で隠すこと。

### 行動
CancellationToken を clone して各タスクへ渡し、cancel で一斉に伝える。
select! には drop による取消が安全な処理か、所有者が後で回収できる pin 済み Future または保持した JoinHandle の可変参照を置く。
境界で Deadline を一度だけ生成し、非取消の後始末を除く全ての async API に同じ値と CancellationToken を渡す。
各 hop で `deadline.remaining(clock.now())` を計算し、その値だけを Tokio の局所 timeout に使う。
局所 timeout では子の CancellationToken を cancel し、下流へは remaining でなく元の `Deadline` を渡す。
処理 future を pin し、timeout には可変参照だけを渡し、期限成立時は子を cancel して同じ future を drain する。
非同期の後始末を token による中断から外し、子の取消の終了通知と drain 中の失敗を別々に所有者へ回収する。

