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
CancellationTokenSource.Cancel は停止要求であり、子の Task の完了待ちとは別に扱う。
CancellationTokenSource.Dispose は取り消し要求も子の完了待ちも行わないため、所有者が子へ合流した後に実行する。

### 根拠
.NET の取り消しは協調的で、listener に強制されない。
CancellationToken を境界から末端まで引数で渡せば、取り消しの合図が下流まで届く。
省略可能にして渡さないと、合図が途中で切れ、処理が止まらない。
時間切れを linked token に合流させれば、時間切れも取り消しとして同じ経路で伝わる。
`Deadline` を境界で一度だけ作って値のまま渡せば、hop が増えても時間枠の起点は動かない。
各 hop が同じ絶対時刻から remaining を計算すれば、通常処理の待機期限を引き直さずに済むが、取消後の drain がその期限内に終わる保証にはならない。
取り消し後の release または `DisposeAsync` へ CancellationToken を渡すと、後始末自体が中断され、資源を漏らす。
元の `Deadline` を保持すれば期限超過の診断情報を失わず、期限を理由に後始末を取り消さずに済む。
Cancel から戻ることや IsCancellationRequested が示すのは要求の状態であり、Task の終了やその finally の完了ではない。

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
処理の所属と終了順序は [concurrency](../../concerns/concurrency/structured-concurrency.md) の「構造化並行で寿命をスコープに束ねる」に従い、所有者が開始済みの Task を保持する。
Task を返すメソッドの呼び出しから登録を行い、開始途中の同期例外や入力の列挙失敗も、登録済みの Task を回収する終了経路へ接続する。
子の完了を Task.WhenAny で順に監視し、例外だけでなく返された業務結果も調べ、失敗を検知した時点で兄弟へ取り消しを伝える。
外部取消と子の取消も終了経路へ接続し、CancellationTokenSource.Cancel(false) が送出する callback の AggregateException を捕捉する。
開始、監視、Cancel の成否にかかわらず、finally に接続した回収経路で Task.WhenAll を await して全ての開始済みの子を drain する。
外部 token へ登録した取消 callback は CancellationTokenRegistration.Dispose で登録を外して実行中の callback の完了を待ち、callback の失敗を確定してから CTS を解放する。
drain 後に全 Task の業務結果、Task.Exception の全 InnerExceptions、callback の失敗を回収し、外部取消も最終結果に残す。
常駐処理は明示した host の長寿命の所有者が Task と CTS を保持し、停止時に同じ回収経路を実行してから依存資源を解放する。
並行して走らせる数は SemaphoreSlim で、一括処理は Parallel.ForEachAsync の MaxDegreeOfParallelism で上限を定める。
個別の job を実行する `RunAsync` は、SemaphoreSlim の permit を取得した後に開始し、permit を保持する間だけ走らせる。

### 根拠
Task を返すメソッドは await より先に実行を始め得るので、await の有無だけでは子の所属を管理できない。
Task は親の Task と自動的な寿命の木を作らないため、所有者が全ての開始済みの Task を保持して回収する必要がある。
Task.WhenAll は全てのタスクが完了するまで完了せず、自動的に兄弟を取り消さないため、失敗の早期検知には Task.WhenAny が要る。
Task<T> が正常完了しても値が業務の失敗を表すことがあり、IsFaulted だけではその失敗を検知できない。
CancellationTokenSource.Cancel(false) は callback の例外を集約して送出するため、例外の収集と drain を別の段にする。
WhenAll の Task は全例外を保持するが、await から送出された一つの例外だけを扱うと、他の失敗が失われる。
開始途中の例外も共通の終了経路で回収すれば、既に開始した子と、それが使う CTS や資源の寿命を保てる。
並行度を無制限にすると資源が枯渇し外部依存を圧迫するので、SemaphoreSlim や Parallel.ForEachAsync の MaxDegreeOfParallelism で上限を固定する。
SemaphoreSlim の待機だけを囲って job を外で開始すると、待機中の job も実行に入り、上限が実処理へ効かない。

### 完了条件
全ての開始済みの Task が所有者に保持され、長寿命の処理も host の停止経路へ接続されている。
開始途中の同期例外、入力の列挙失敗、監視の失敗でも、開始済みの子の drain が省かれていない。
Task.WhenAny の完了監視で、例外と業務結果の失敗の両方が検知され、残りの兄弟へ取消が伝わっている。
Cancel callback の AggregateException が収集され、Cancel の成否にかかわらず Task.WhenAll の drain が完了している。
drain 後に全 Task の業務結果と例外、callback の失敗、外部取消がそれぞれ観測されている。
子が使う CTS と依存資源が全ての子の drain より後に解放され、外部取消の callback も CTS の解放前に実行を終えている。
並行して走る数に、SemaphoreSlim または Parallel.ForEachAsync の MaxDegreeOfParallelism で上限が定められている。
個別の job が、SemaphoreSlim の permit を取得した後に開始され、permit の解放前に完了している。

### 禁止事項
Task を保持する長寿命の所有者を定めずに、要求の範囲を越えて処理を走らせること。
Task.WhenAll に、自動的な兄弟取消や失敗の早期検知があるとみなすこと。
Task<T> の IsFaulted だけを調べ、業務結果の失敗を見落とすこと。
最初の例外だけを伝え、兄弟、callback、後始末の失敗または同時に起きた外部取消を捨てること。
開始途中または Cancel callback の例外で、Task.WhenAll の drain を飛ばすこと。
SemaphoreSlim の permit を取得する前に、job の `RunAsync` を開始すること。

### 行動
所有者が保持する Task の集合を子の開始ごとに更新し、開始と監視を共通の回収経路へ接続する。
子の失敗、取消、外部取消で Cancel(false) を呼び、callback の AggregateException を収集する。
Task.WhenAll を取消済みの token による待機の打ち切りで包まず、全ての開始済みの子の drain を完了する。
全 Task の業務結果と Task.Exception を回収し、最初の失敗と追加の失敗を区別して境界へ渡す。
外部取消だけなら OperationCanceledException を送出し、例外と同時なら集約へ OperationCanceledException を含める。
長寿命の所有者は停止時にも同じ回収を実行し、完了を確認してから CTS と依存資源を解放する。
個別の並行は SemaphoreSlim で、一括処理は Parallel.ForEachAsync の MaxDegreeOfParallelism で並行度の上限を定める。
SemaphoreSlim の permit を取得した後に job の `RunAsync` を開始し、`finally` で permit を解放する。


## blocking 禁止

### 要求
async の経路で .Result・.Wait()・GetAwaiter().GetResult() を呼ばない。
禁止した呼び出しは、banned API の lint で検出する。
同期のブロッキング処理を Task.Run に移しても、開始済みの処理が token だけで中断されるとは扱わない。
停止を要する同期処理には token を確認する短い区切りか、停止を管理できる process の境界を設け、開始済みの処理の完了まで所有者に保持させる。

### 根拠
async のメソッドを同期に待つと、呼び出し元のスレッドが完了まで塞がり、context を捕まえたまま待つ経路では同じスレッドを取り合ってデッドロックを招く。
sync-over-async はスレッドプールの枯渇も招き、他の非同期処理の実行を遅らせる。
禁止した呼び出しを banned API として lint で検出すれば、レビューを待たずビルドで止められる。
Task.Run の token は開始前の取消には使えるが、既に動く delegate の停止には delegate 自身の協調が要る。

### 完了条件
async の経路に、.Result・.Wait()・GetAwaiter().GetResult() の呼び出しがない。
禁止した呼び出しが、banned API の lint で検出されている。
ブロッキング処理の停止点と完了待ちが、所有者の停止経路へ接続されている。

### 禁止事項
async の経路で、.Result・.Wait()・GetAwaiter().GetResult() を呼ぶこと。
Task.Run または待機の timeout を、開始済みの同期処理の強制停止とみなすこと。

### 行動
async の経路は最後まで await でつなぎ、.Result・.Wait()・GetAwaiter().GetResult() を BannedSymbols.txt に登録して Microsoft.CodeAnalysis.BannedApiAnalyzers で検出する。
同期処理の token の確認点と停止限界を明示し、待機を打ち切っても実処理の追跡を捨てない。

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
子が使う資源の using または await using の範囲は、子の drain の外側に置き、drain が終わる前に抜けない。
Dispose または DisposeAsync が失敗する経路では、元の処理の終了理由と解放の失敗をともに保持し、他の必要な解放を続ける。

### 根拠
`using`/`await using` は、例外や早期リターンでスコープを抜けるときも `IDisposable`/`IAsyncDisposable` の `Dispose`/`DisposeAsync` を呼ぶ言語機構である。
`await using` は `IAsyncDisposable` を要求するので、`IDisposable` にしか対応しない資源へ付けると CS8410 になる。
Effect の中で確保した資源は、`AcquireRelease` が成功・失敗・取り消しのいずれでも一度だけ解放するので、coordination がそこへ委ねれば機構が二重にならない。
非取消の後始末にすれば、取り消しを受けた後でも解放処理を中断せず、資源の漏れを防げる。
`IAsyncDisposable.DisposeAsync()` は引数を持たないため、`await using` は取り消し済みの token を解放へ渡さない。
using と await using は資源の解放を呼ぶが、別に開始した Task の完了待ちや、処理の失敗と解放例外の集約は行わない。

### 完了条件
coordination が扱う資源が、`IDisposable` は `using`、`IAsyncDisposable` は `await using` で確保されている。
Effect の中の資源取得と解放が、connection の `AcquireRelease` に委ねられている。
`AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` が非取消で完了し、元の `Deadline` が後始末の範囲に保持されている。
子の drain が using または await using の終了より先に完了し、処理と解放の両方が失敗してもどちらの失敗も観測されている。

### 禁止事項
資源を、`using` も `await using` も無いまま持ち回ること。
Effect の中の資源解放を、`AcquireRelease` を介さず手で書くこと。
release または `DisposeAsync` へ CancellationToken を渡し、後始末を中断可能にすること。
using または await using だけで、子の完了待ちと全失敗の回収を保証できるとみなすこと。

### 行動
coordination が直接扱う資源は、`IDisposable` なら `using`、`IAsyncDisposable` なら `await using` で確保する。
Effect の中で取得する資源は connection の `AcquireRelease` に委ねる。
release と `DisposeAsync` は、元の `Deadline` を保持する非取消の後始末として完了まで待つ。
子の drain を資源の範囲内で完了し、処理と解放の両方が失敗する場合の集約を所有者の終了経路で行う。

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
