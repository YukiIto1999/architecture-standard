# coordination

## 概要
coordination は、C# で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency/README.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、C# の機構で満たす。
取り消しは [effect](../../concerns/effect/README.md) の Canceled 終了を実現し、資源は失敗と取り消しの経路でも using と IAsyncDisposable で解放する。

## 非同期

### 要求
副作用の経路は async/await で書き、domain は同期の純粋な関数に保ち Task を返さない。
例外と取り消しを追えるよう、async void を使わない。
surface と host が公開する非同期 API は、呼び出し側が複数回 await しても同じ完了を観測できる Task または Task<T> を返す。
Effect の内部の Run と AcquireRelease の release は、内部で一度だけ await する ValueTask または ValueTask<T> を返す。
Task と ValueTask は、公開 host API と Effect 内部という観測可能な役割で一意に分ける。

### 根拠
副作用の経路を async/await で書けば、待ちがスレッドを塞がない。
domain を同期の純粋な関数に保てば、判断が非同期の足場から切れ、テストと合成がしやすい。
domain が Task を返すと、判断に非同期が侵入し、純粋さが失われる。
async void は Task を持たないので、例外が捕まえられず、待ち合わせもできない。
Task は複数回の await と完了の共有を契約にできるため、framework と利用側が観測する公開 host API に合う。
ValueTask は一度だけ await する内部経路に閉じれば、複数回 await や保存を許すかという契約を公開面へ持ち出さずに済む。

### 完了条件
副作用の経路が、async/await で書かれている。
domain が同期の純粋な関数で、Task を返していない。
async void が、使われていない。
surface と host が公開する非同期 API が、Task または Task<T> を返している。
Effect の内部の Run と AcquireRelease の release が、ValueTask または ValueTask<T> を返している。
公開 host API に ValueTask がなく、Effect 内部に Task が混在していない。

### 禁止事項
domain の純粋な判断に、Task を持ち込むこと。
async void で、例外と取り消しを追えなくすること。
surface または host の公開 API から、ValueTask または ValueTask<T> を返すこと。
Effect の内部の Run または AcquireRelease の release から、Task または Task<T> を返すこと。

### 行動
副作用の経路を async/await で書き、domain は同期の純粋な関数に保つ。
公開する host API は Task または Task<T> を返す。
Effect の内部の Run と release は ValueTask または ValueTask<T> を返す。

## 取り消し

### 要求
CancellationToken を非取消の後始末を除く全ての非同期 API に下流まで渡し、取り消しを受けた処理は協調して止まる。
CancellationToken を省略可能にして渡さない形にせず、時間切れは linked token で内部の token に合流させて下流へ伝える。
時間の上限は `Deadline` carrier の絶対時刻で表し、request、message、job の境界で TimeProvider から一度だけ生成する。
境界より内側の非同期 API は、`AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` という非取消の後始末を除き、同じ `Deadline` と CancellationToken を必須の引数として受け取り下流へ渡す。
非取消の後始末でも元の `Deadline` を保持する。
`AcquireRelease` の release は同じ `Deadline` を引数で受け、`IAsyncDisposable.DisposeAsync` の呼出側は同じ `Deadline` を後始末の scope に保持するが、どちらにも CancellationToken を渡さない。
各 hop は TimeProvider の現在時刻から `Deadline` までの remaining を計算し、その remaining から局所の CancellationTokenSource を作る。
局所の token は親の CancellationToken と linked token に合流させ、同じ絶対期限とともに下流へ渡す。

### 根拠
.NET の取り消しは協調的で、listener に強制されない。
CancellationToken を境界から末端まで引数で渡せば、取り消しの合図が下流まで届く。
省略可能にして渡さないと、合図が途中で切れ、処理が止まらない。
時間切れを linked token に合流させれば、時間切れも取り消しとして同じ経路で伝わる。
`Deadline` を境界で一度だけ作って値のまま渡せば、hop が増えても時間枠の起点は動かない。
各 hop が同じ絶対時刻から remaining を計算すれば、局所の待ちを打ち切りながら全体の時間上限を越えない。
取り消し後の release または `DisposeAsync` へ CancellationToken を渡すと、後始末自体が中断され、資源を漏らす。
元の `Deadline` を保持すれば期限超過の診断情報を失わず、期限を理由に後始末を取り消さずに済む。

### 完了条件
CancellationToken が、非取消の後始末を除く全ての非同期 API に渡されている。
取り消しを受けた処理が、協調して止まる。
CancellationToken が、省略されずに渡されている。
絶対時刻の `Deadline` が、request、message、job の境界で TimeProvider から一度だけ生成されている。
境界より内側の非同期 API が、`AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` を除いて、同じ `Deadline` と CancellationToken を必須の引数として受け取り下流へ渡している。
非取消の後始末が元の `Deadline` を保持し、release と `DisposeAsync` のどちらにも CancellationToken が渡されていない。
各 hop の局所 timeout が、TimeProvider の現在時刻から同じ `Deadline` までの remaining から作られている。
局所 timeout の token と親の CancellationToken が linked token に合流し、下流へ伝播している。

### 禁止事項
CancellationToken を省略可能にして、渡さずに済ませること。
hop ごとに相対 timeout を引き直し、新しい時間枠を始めること。
絶対期限を remaining に置き換え、下流へ相対値だけを渡すこと。
非取消の後始末でないのに、`Deadline` または CancellationToken を受け取らない非同期 API を境界より内側に作ること。
`AcquireRelease` の release または `IAsyncDisposable.DisposeAsync` へ CancellationToken を足し、取り消し可能にすること。

### 行動
CancellationToken を非取消の後始末を除いて末端まで渡し、ThrowIfCancellationRequested で止める。
境界で TimeProvider から `Deadline` を一度だけ生成し、全ての内側の非同期 API に同じ値を渡す。
各 hop で `deadline.Remaining(timeProvider)` を計算し、その値だけを局所の CancellationTokenSource に使う。
時間切れは linked token で親の token に合流させ、下流へは remaining でなく元の `Deadline` を渡す。
`AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` は非取消の後始末として実行し、元の `Deadline` を保持したまま CancellationToken を渡さない。

### 例
取り消し token を渡さないと、合図が下流まで届かない。

```csharp
public async Task Process(Order order) { await _client.SendAsync(order); }
```

絶対期限は host の request 境界で一度だけ生成する。非取消の後始末を除き、下流の非同期 API は同じ期限と token を受け取る。

```csharp
public readonly record struct Deadline(DateTimeOffset At)
{
    public static Deadline FromBudget(TimeProvider timeProvider, TimeSpan budget) =>
        new(timeProvider.GetUtcNow() + budget);

    public TimeSpan Remaining(TimeProvider timeProvider) => At - timeProvider.GetUtcNow();
}

public Task<Receipt> Process(Order order, CancellationToken cancellationToken)
{
    var deadline = Deadline.FromBudget(_timeProvider, RequestBudget);
    return ProcessCore(order, deadline, cancellationToken);
}

private async Task<Receipt> ProcessCore(
    Order order,
    Deadline deadline,
    CancellationToken cancellationToken)
{
    cancellationToken.ThrowIfCancellationRequested();
    var remaining = deadline.Remaining(_timeProvider);
    if (remaining <= TimeSpan.Zero) throw new OperationCanceledException("deadline exceeded");

    using var timeoutCts = new CancellationTokenSource(remaining, _timeProvider);
    using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
        cancellationToken,
        timeoutCts.Token);
    return await _client.SendAsync(
        order,
        deadline,
        linkedCts.Token);
}
```

## 並行の組

### 要求
並行のタスクは範囲の中で開始し、完了と失敗を範囲の終わりで待ち合わせて回収する。
範囲を抜けたタスクを残さない。
子の完了を Task.WhenAny で監視し、失敗を検知した時点で兄弟を取り消す。
CancellationTokenSource.Cancel が送出する callback の AggregateException を捕捉し、callback の失敗を収集する。
Cancel の成否にかかわらず、Task.WhenAll で全ての兄弟を drain する。
drain 後に task の失敗と cancel callback の失敗を集約する。
外部の CancellationToken が取り消されていた場合は、その取消も最終結果に残す。
並行して走らせる数は SemaphoreSlim で、一括処理は Parallel.ForEachAsync の MaxDegreeOfParallelism で上限を定める。
個別の job を実行する `RunAsync` は、SemaphoreSlim の permit を取得した後に開始し、permit を保持する間だけ走らせる。

### 根拠
範囲の外でタスクを開始すると、孤児のタスクが残り、失敗も取り消しも追えない。
範囲の中で開始し範囲の終わりで待ち合わせれば、孤児が残らず、失敗が範囲の中で扱える。
Task.WhenAll は全てのタスクが完了するまで完了しないため、それだけでは子の失敗を早期に検知して兄弟を取り消せない。
Task.WhenAny で最初の完了から順に状態を調べれば、失敗を検知した時点で兄弟用の CancellationTokenSource を取り消せる。
CancellationTokenSource.Cancel は登録された callback の失敗を AggregateException で送出するため、無防備に呼ぶと drain へ到達しない。
Cancel の例外を収集してから Task.WhenAll で全兄弟を drain すれば、孤児を残さず task と callback の失敗をまとめられる。
外部取消を集約へ含めれば、task や callback の失敗と同時に起きても取消の事実が失われない。
並行度を無制限にすると資源が枯渇し外部依存を圧迫するので、SemaphoreSlim や Parallel.ForEachAsync の MaxDegreeOfParallelism で上限を固定する。
SemaphoreSlim の待機だけを囲って job を外で開始すると、待機中の job も実行に入り、上限が実処理へ効かない。

### 完了条件
並行のタスクが、範囲の中で開始され、範囲の終わりで回収されている。
範囲を抜けたタスクが、残っていない。
子の失敗が、Task.WhenAny による完了監視で早期に検知されている。
子の失敗を検知したとき、CancellationTokenSource で残りの兄弟が取り消されている。
Cancel callback の AggregateException が捕捉され、callback の失敗が収集されている。
Cancel が例外を送出しても、全ての兄弟が Task.WhenAll で drain されている。
task と cancel callback の失敗が、drain 後に集約されている。
外部の CancellationToken の取消が、最終結果に残っている。
並行して走る数に、SemaphoreSlim または Parallel.ForEachAsync の MaxDegreeOfParallelism で上限が定められている。
個別の job が、SemaphoreSlim の permit を取得した後に開始され、permit の解放前に完了している。

### 禁止事項
範囲の外へ、タスクを投げっぱなしにすること。
子の失敗を、兄弟を取り消さずに走らせたまま放置すること。
Task.WhenAll だけで、子の失敗を早期に検知できるとみなすこと。
最初の失敗だけを伝え、兄弟の失敗を捨てること。
Cancel callback の AggregateException で、Task.WhenAll の drain を飛ばすこと。
task の失敗を伝えるときに、同時に起きた外部取消を捨てること。
SemaphoreSlim の permit を取得する前に、job の `RunAsync` を開始すること。

### 行動
並行のタスクを範囲の中で開始し、Task.WhenAny で完了を順に監視する。
子の失敗または外部取消を検知したら、Cancel の AggregateException を収集する共通経路で兄弟へ取消を伝える。
Cancel の成否にかかわらず、Task.WhenAll で全ての兄弟を drain する。
drain 後に task と cancel callback の失敗を集約する。
外部取消だけなら OperationCanceledException を送出し、他の失敗と同時なら集約へ OperationCanceledException を含める。
個別の並行は SemaphoreSlim で、一括処理は Parallel.ForEachAsync の MaxDegreeOfParallelism で並行度の上限を定める。
SemaphoreSlim の permit を取得した後に job の `RunAsync` を開始し、`finally` で permit を解放する。

### 例
投げっぱなしの task は範囲外へ残り、失敗と取り消しを追跡できない。

```csharp
foreach (var job in jobs) _ = RunAsync(job);
```

各 job を範囲内で開始し、最初の失敗で兄弟を取り消す。cancel callback の失敗も収集し、すべての task へ合流してから結果を決める。

```csharp
using var siblingCts = new CancellationTokenSource();
var cancelCallbackFailures = new ConcurrentQueue<Exception>();
void CancelSiblings()
{
    try
    {
        siblingCts.Cancel(throwOnFirstException: false);
    }
    catch (AggregateException exception)
    {
        foreach (var failure in exception.Flatten().InnerExceptions)
            cancelCallbackFailures.Enqueue(failure);
    }
}

using var externalRegistration = cancellationToken.Register(CancelSiblings);
using var limiter = new SemaphoreSlim(MaxConcurrentJobs);
async Task RunBoundedAsync(
    Job job,
    Deadline jobDeadline,
    CancellationToken jobCancellationToken)
{
    var remaining = jobDeadline.Remaining(_timeProvider);
    if (remaining <= TimeSpan.Zero) throw new OperationCanceledException("deadline exceeded");
    using var timeoutCts = new CancellationTokenSource(remaining, _timeProvider);
    using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
        jobCancellationToken,
        timeoutCts.Token);

    await limiter.WaitAsync(linkedCts.Token);
    try
    {
        await RunAsync(job, jobDeadline, linkedCts.Token);
    }
    finally
    {
        limiter.Release();
    }
}
var tasks = jobs
    .Select(job => RunBoundedAsync(job, deadline, siblingCts.Token))
    .ToArray();
var pending = tasks.ToHashSet();
while (pending.Count > 0)
{
    var completed = await Task.WhenAny(pending);
    pending.Remove(completed);
    if (!completed.IsFaulted) continue;
    CancelSiblings();
    break;
}

try
{
    await Task.WhenAll(tasks);
}
catch
{
    // ここでは再送出しない。全 task の失敗を失わず一度に返すため
}

externalRegistration.Dispose();
var failures = tasks
    .Where(task => task.Exception is not null)
    .SelectMany(task => task.Exception!.Flatten().InnerExceptions)
    .Concat(cancelCallbackFailures)
    .ToList();
var externalCancellation = cancellationToken.IsCancellationRequested
    ? new OperationCanceledException(cancellationToken)
    : null;
if (externalCancellation is not null && failures.Count > 0) failures.Add(externalCancellation);
if (failures.Count > 0) throw new AggregateException(failures);
if (externalCancellation is not null) throw externalCancellation;
if (tasks.Any(task => task.IsCanceled)) throw new OperationCanceledException("子タスクが取り消された");
```

## blocking 禁止

### 要求
async の経路で .Result・.Wait()・GetAwaiter().GetResult() を呼ばない。
禁止した呼び出しは、banned API の lint で検出する。

### 根拠
async のメソッドを同期に待つと、呼び出し元のスレッドが完了まで塞がり、context を捕まえたまま待つ経路では同じスレッドを取り合ってデッドロックを招く。
sync-over-async はスレッドプールの枯渇も招き、他の非同期処理の実行を遅らせる。
禁止した呼び出しを banned API として lint で検出すれば、レビューを待たずビルドで止められる。

### 完了条件
async の経路に、.Result・.Wait()・GetAwaiter().GetResult() の呼び出しがない。
禁止した呼び出しが、banned API の lint で検出されている。

### 禁止事項
async の経路で、.Result・.Wait()・GetAwaiter().GetResult() を呼ぶこと。

### 行動
async の経路は最後まで await でつなぎ、.Result・.Wait()・GetAwaiter().GetResult() を BannedSymbols.txt に登録して Microsoft.CodeAnalysis.BannedApiAnalyzers で検出する。

## 共有状態

### 要求
生産と消費は System.Threading.Channels で結び、可変の状態は channel を読む単一の消費の実行に閉じ込める。

### 根拠
可変の状態を複数の実行から触ると、競合で壊れる。
channel で生産と消費を結び、可変の状態を単一の消費に閉じ込めれば、状態を触るのが一つの実行だけになる。
bounded な channel は、生産が消費を追い越したときに背圧をかける。

### 完了条件
生産と消費が、System.Threading.Channels で結ばれている。
可変の状態が、channel を読む単一の消費の実行に閉じ込められている。

### 禁止事項
可変の状態を、複数の実行から直接触ること。

### 行動
生産と消費を Channels で結び、可変の状態を単一の消費に閉じ込める。

## ライブラリの作法

### 要求
再利用するライブラリのコードでは、ConfigureAwait(false) を付ける。
context を要するコードでは、付けない。

### 根拠
await の完了時に既定で実行の context を捕まえて再開するが、ライブラリのコードは context を要さない。
ConfigureAwait(false) を付ければ、context を捕まえず、context と blocking の衝突によるデッドロックを避け、再開が速くなる。

### 完了条件
再利用するライブラリのコードに、ConfigureAwait(false) が付いている。

### 禁止事項
context を要さない再利用のコードで、context を捕まえたまま再開すること。

### 行動
再利用するライブラリのコードに ConfigureAwait(false) を付ける。

## 資源解放

### 要求
coordination が扱う購読・channel・timer などの資源は、`IDisposable` を `using` で、`IAsyncDisposable` を `await using` で確保し、範囲の終わりだけでなく失敗や取り消しの経路でも解放する。
Effect の中で取得する資源の解放は、connection の `AcquireRelease` に委ね、ここで別の機構を重ねない。
`AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` は、取り消し後も完了まで実行する非取消の後始末にする。
後始末は元の `Deadline` を保持するが、CancellationToken を受け取らない。

### 根拠
`using`/`await using` は、例外や早期リターンでスコープを抜けるときも `IDisposable`/`IAsyncDisposable` の `Dispose`/`DisposeAsync` を呼ぶ言語機構である。
`await using` は `IAsyncDisposable` を要求するので、`IDisposable` にしか対応しない資源へ付けると CS8410 になる。
Effect の中で確保した資源は、`AcquireRelease` が成功・失敗・取り消しのいずれでも一度だけ解放するので、coordination がそこへ委ねれば機構が二重にならない。
非取消の後始末にすれば、取り消しを受けた後でも解放処理を中断せず、資源の漏れを防げる。
`IAsyncDisposable.DisposeAsync()` は引数を持たないため、`await using` は取り消し済みの token を解放へ渡さない。

### 完了条件
coordination が扱う資源が、`IDisposable` は `using`、`IAsyncDisposable` は `await using` で確保されている。
Effect の中の資源取得と解放が、connection の `AcquireRelease` に委ねられている。
`AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` が非取消で完了し、元の `Deadline` が後始末の範囲に保持されている。

### 禁止事項
資源を、`using` も `await using` も無いまま持ち回ること。
Effect の中の資源解放を、`AcquireRelease` を介さず手で書くこと。
release または `DisposeAsync` へ CancellationToken を渡し、後始末を中断可能にすること。

### 行動
coordination が直接扱う資源は、`IDisposable` なら `using`、`IAsyncDisposable` なら `await using` で確保する。
Effect の中で取得する資源は connection の `AcquireRelease` に委ねる。
release と `DisposeAsync` は、元の `Deadline` を保持する非取消の後始末として完了まで待つ。

### 例
手動の解放は例外経路で抜ける。

```csharp
var subscription = source.Subscribe(handler);
DoWork(); subscription.Dispose();
```

同期資源は `using`、非同期資源は `await using` の scope で解放する。`IObservable.Subscribe` が返すのは `IDisposable` なので `await using` は使えない。非同期の後始末は取得時の期限を保持し、token を受けずに完了まで待つ。

```csharp
using var subscription = source.Subscribe(handler);

await using var lease = await OpenLeaseAsync(deadline, cancellationToken);
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency/README.md)、副作用を境界に集める原則は [separation](../../principles/separation/README.md)、効果の取り消しと資源は [effect](../../concerns/effect/README.md)、停止の合図と優雅な終了は [lifecycle](../../concerns/lifecycle/README.md) に従う。
Effect の中の資源解放は [connection](./connection.md) の `AcquireRelease` に従う。
