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
処理の所属と終了順序は [concurrency](../../concerns/concurrency/structured-concurrency.md) の「構造化並行で寿命をスコープに束ねる」に従う。
spawn する子は所有者の JoinSet に登録し、join_next で全ての出力と JoinError を回収する。
業務の Err、子の取消、JoinError、外部取消のどの終了経路でも、所有者の CancellationToken で兄弟へ協調取消を伝えてから、join_next が None を返すまで drain する。
子の出力では業務の Result と取消による終了を区別し、JoinError では is_panic と is_cancelled を区別して、最初の失敗と追加の失敗を保持する。
async の後始末を要する子は、取消後に後始末を await してから終了を返す。
abort は、Future を drop しても必要な後始末と外部効果の整合性を失わない子に限り、abort_all の後も join_next で全ての終了を回収する。
同じ task 内の固定数の分岐は共有する CancellationToken へ各分岐の失敗を通知し、join! で全ての終了を待つ。
所有者の Future 自体は host の停止経路で完了まで await し、timeout、select!、abort で drop して drain を飛ばさない。
監督中に panic し得る処理は監督対象の子へ隔離して JoinError で回収し、所有者の unwind による JoinSet の drop を正常な終了処理にしない。
固定数でも分岐の panic による unwind が所有者の合流や非同期の後始末を飛ばす場合は、分岐を JoinSet の子として実行する。
長寿命の処理は host の長寿命の所有者の JoinSet に開始時から所属させ、request の終了ではなく、その所有者の停止で回収する。
並行して需要を処理する job task の数は tokio::sync::Semaphore で上限を定める。
共有状態を単一所有する owner task は需要を並行処理する job task ではないため、Semaphore の permit の対象外とする。
job task の permit 待ちは、期限付きの permit 取得と CancellationToken の取消を select! で競わせる。
取消と permit 取得が同時に成立した場合は、取消を先に選び permit を取得しない。

### 根拠
JoinHandle の drop は task を detach し、JoinSet の drop は残る task に abort を要求するが、どちらも全ての終了の観測と非同期の後始末の完了待ちにはならない。
join_next は子の出力と JoinError を返し、join によって終了を観測した時点では子の同期 destructor も完了している。
CancellationToken の cancel と abort_all は完了待ちではないため、要求を出した後も join_next で子の終了を回収する必要がある。
JoinSet::shutdown は abort と drain を行うが出力を捨てて panic を無視するため、全失敗を観測する所有者の終了経路には使えない。
try_join! は最初の Err で未完了の分岐を drop し、分岐が持つ JoinHandle も detach するため、必要な後始末と全失敗の観測を保証しない。
共有 token に失敗を通知して join! で待てば、固定数の分岐にも協調取消と全完了の回収を接続できる。
Drop は await できないので、所有者を drop してから async の後始末を回収することはできない。
job task の並行度を無制限にすると資源が枯渇し外部依存を圧迫するので、tokio::sync::Semaphore で上限を固定する。
単一の owner task に permit を要求すると、job の需要枠を常時一つ消費し、共有状態の直列化という別の役割を並行度制御と混同する。
permit 取得だけを期限で囲うと、CancellationToken が取り消されても permit が空くか期限を迎えるまで待ち続ける。

### 完了条件
spawn した全ての子が、要求または host の長寿命の所有者の JoinSet に所属している。
業務の Err、子の取消、JoinError、外部取消で兄弟へ協調取消が伝わり、join_next が None を返すまで全ての終了を回収している。
回収した業務結果、取消、panic、追加の後始末の失敗がそれぞれ観測され、最初の失敗だけへ潰されていない。
協調取消の子の async の後始末が終了通知より先に完了し、panic した子の後始末も存続する資源の所有者が回収している。
所有者の Future が drain 中に drop または abort されていない。
abort を使う子が drop による取消の安全性を満たし、abort_all の後も全ての終了を join_next で観測している。
同じ task 内の固定数の分岐が、共有 token による失敗時の取消と join! による全完了待ちに接続され、必要な後始末を飛ばす panic の経路がない。
並行して需要を処理する job task の数に、tokio::sync::Semaphore で上限が定められている。
単一の共有状態の owner task が job 用 Semaphore の permit を取得せず、明示した寿命の所有者の JoinSet へ合流している。
permit 待ち中に CancellationToken が取り消された job task が、permit を取得せず終了している。

### 禁止事項
task の完了ハンドルを保持する寿命の所有者を定めずに、spawn または detach すること。
JoinSet の drop、abort_all、CancellationToken の cancel を、drain の完了とみなすこと。
JoinSet::shutdown または最初の Err で戻る try_join! を、全失敗の観測と非同期の後始末を要する終了経路へ使うこと。
業務の Err または JoinError の一方だけを終了経路へ接続し、他方で兄弟の回収を飛ばすこと。
async の後始末が必要な子を、安全性を確かめず abort すること。
所有者の Future を drop または abort し、JoinSet の destructor だけへ終了を委ねること。
Semaphore の permit を取得せず、JoinSet の並行 job task に需要を実行させること。
単一の owner task に job 用 Semaphore の permit を要求すること。
job task の permit 待ちを期限だけで囲い、CancellationToken の取消と競わせないこと。

### 行動
spawn する子は寿命の所有者の JoinSet に登録し、所有者自身は上位の host の停止経路から完了まで待つ。
失敗と取消を検知したら兄弟の token を cancel し、join_next が None を返すまで回収を続け、子の業務結果と JoinError をそれぞれ仕分ける。
固定数の分岐も失敗で共有 token を cancel して join! で待ち、未完了の分岐を捨てない。
abort が許される子にも abort_all の後に同じ回収経路を使い、shutdown による結果の破棄を避ける。
並行 job task の上限は tokio::sync::Semaphore で固定する。
単一の共有状態の owner task は permit の対象外とし、寿命だけを要求または host の JoinSet で管理する。
job task の permit 待ちは select! で CancellationToken の取消と競わせ、同時成立時は取消を先に選ぶ。


## ブロッキング

### 要求
spawn_blocking に委ねるのは、実行時間が短く、同時実行数に上限を置ける処理に限る。
project は、spawn_blocking に渡す処理の最大実行時間と permit 数を決定の記録に残す。
spawn_blocking は、Semaphore の permit を先に取得する共通 wrapper からだけ呼ぶ。
共通 wrapper の permit 待ちは、CancellationToken の取消を先頭に置いた biased な select! で、期限付きの permit 取得と競わせる。
permit 取得後にも CancellationToken を再確認し、取り消されていれば spawn_blocking を開始せず permit を解放する。
共通 wrapper の外から spawn_blocking を直接呼ぶことは、clippy の disallowed_methods と構造検査で拒否する。
長く走るブロッキング処理は、専用の process へ分離するか、取り消しを確認できる短い chunk に分ける。
開始済みのブロッキング処理は abort で停止できると扱わない。
開始済みの spawn_blocking の JoinHandle は、wrapper を含む所有者が完了まで保持して await し、wrapper の取消や drop で detach しない。
runtime の shutdown_timeout は待機を打ち切るだけで開始済みの blocking task を停止しないため、正常停止の完了条件へ使わない。
非同期のタスクの中で、同期の I/O を直接呼ばない。

### 根拠
非同期のタスクの中で同期の I/O を直接呼ぶと、実行のスレッドが塞がり、同じスレッドの他のタスクが進まない。
spawn_blocking に委ねれば、ブロッキングが専用のスレッドで走り、非同期の実行を塞がない。
共通 wrapper が permit を取得してから起動すれば、blocking pool の大きさとは独立に application が開始する処理数を制限できる。
permit 待ちを CancellationToken と競わせれば、親取消後に permit が空くか期限を迎えるまで待ち続けない。
permit 取得後に取消を再確認すれば、select! の完了直後に成立した取消で新しいブロッキング処理を始めない。
直接呼び出しを検査で拒否すれば、permit を経由しない経路を作れない。
開始済みの spawn_blocking は abort しても処理が続くため、停止の手段として使えない。
wrapper の Future を drop すると内部の JoinHandle も drop されるため、blocking task は背後で走り続け、非同期側の drain だけでは回収できなくなる。
長い処理を専用の process へ分けるか短い chunk にすれば、停止時に新しい仕事を止め、区切りで終了を判断できる。

### 完了条件
spawn_blocking の処理が、短く、同時実行数に上限を持っている。
最大実行時間と permit 数が、project の決定の記録に残されている。
全ての spawn_blocking が、permit を取得する共通 wrapper から呼ばれている。
共通 wrapper の permit 待ちが、CancellationToken の取消を先頭に置いた biased な select! で期限付き permit 取得と競わされている。
permit 取得後に CancellationToken が再確認され、取り消されていれば spawn_blocking が開始されず permit が解放されている。
共通 wrapper が開始する同時実行数が、記録した permit 数を超えないことを実行テストで確かめている。
処理が最大実行時間を超えないことを、計測テストとレビューで確かめている。
長いブロッキング処理が、専用の process または取り消しを確認する短い chunk に分離されている。
開始済みのブロッキング処理を、abort で停止できる前提にしていない。
開始済みの blocking task の JoinHandle が完了まで await され、共有資源の解放より先に終了が観測されている。
非同期のタスクの中で、同期の I/O を直接呼んでいない。

### 禁止事項
非同期のタスクの中で、同期の I/O を直接呼ぶこと。
共通 wrapper の外から、spawn_blocking を直接呼ぶこと。
決定の記録に残した permit 数を経由せず、ブロッキング処理を起動すること。
共通 wrapper の permit 待ちを期限だけで囲い、CancellationToken の取消と競わせないこと。
permit 取得後に CancellationToken を再確認せず、spawn_blocking を開始すること。
長く走る処理や同時実行数を制限できない処理を、spawn_blocking に渡すこと。
開始済みのブロッキング処理を、abort で停止できると扱うこと。
wrapper の取消、drop、runtime の shutdown_timeout を、開始済みの blocking task の停止とみなすこと。

### 行動
spawn_blocking に渡す処理の最大実行時間と permit 数を、project の決定の記録に残す。
Semaphore の permit を取得してから spawn_blocking を呼ぶ共通 wrapper を一つ作る。
共通 wrapper の permit 待ちは、CancellationToken の取消を先頭に置いた biased な select! で期限付き permit 取得と競わせる。
permit 取得後に CancellationToken を再確認し、取り消されていれば permit を解放して終了する。
共通 wrapper 内の呼び出しだけを局所的に許可し、それ以外は clippy の disallowed_methods と構造検査で拒否する。
共通 wrapper の同時実行数を実行テストで測り、記録した permit 数を超えないことを確かめる。
各処理の実行時間を計測テストで測り、記録した最大実行時間を超えないことを確かめる。
長く走る処理は専用の process へ分けるか、各 chunk の間で CancellationToken を確認する形へ分割する。
wrapper の所有者へ取消を合図として渡し、開始済みの JoinHandle の await は中断せず、blocking task の終了を回収する。


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

