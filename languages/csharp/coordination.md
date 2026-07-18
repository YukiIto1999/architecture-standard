# coordination

## 概要
coordination は、C# で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、C# の機構で満たす。
取り消しは [effect](../../concerns/effect.md) の Canceled 終了を実現し、資源は失敗と取り消しの経路でも using と IAsyncDisposable で解放する。

## 非同期

### 要求
副作用の経路は async/await で書き、domain は同期の純粋な関数に保ち Task を返さない。
例外と取り消しを追えるよう、async void を使わない。

### 根拠
副作用の経路を async/await で書けば、待ちがスレッドを塞がない。
domain を同期の純粋な関数に保てば、判断が非同期の足場から切れ、テストと合成がしやすい。
domain が Task を返すと、判断に非同期が侵入し、純粋さが失われる。
async void は Task を持たないので、例外が捕まえられず、待ち合わせもできない。

### 完了条件
副作用の経路が、async/await で書かれている。
domain が同期の純粋な関数で、Task を返していない。
async void が、使われていない。

### 禁止事項
domain の純粋な判断に、Task を持ち込むこと。
async void で、例外と取り消しを追えなくすること。

### 行動
副作用の経路を async/await で書き、domain は同期の純粋な関数に保つ。
非同期のメソッドは Task・Task<T> を返す。

## 取り消し

### 要求
CancellationToken を全ての非同期の API に下流まで渡し、取り消しを受けた処理は協調して止まる。
CancellationToken を省略可能にして渡さない形にせず、時間切れは linked token で内部の token に合流させて下流へ伝える。
絶対期限を文脈として伝播する機構は、標準が固定せず、project が単一の採用を ADR に明記する。

### 根拠
.NET の取り消しは協調的で、listener に強制されない。
CancellationToken を境界から末端まで引数で渡せば、取り消しの合図が下流まで届く。
省略可能にして渡さないと、合図が途中で切れ、処理が止まらない。
時間切れを linked token に合流させれば、時間切れも取り消しとして同じ経路で伝わる。

### 完了条件
CancellationToken が、全ての非同期の API に渡されている。
取り消しを受けた処理が、協調して止まる。
CancellationToken が、省略されずに渡されている。

### 禁止事項
CancellationToken を省略可能にして、渡さずに済ませること。

### 行動
CancellationToken を引数で末端まで渡し、ThrowIfCancellationRequested で止める。
時間切れは linked token で内部の token に合流させ、下流へ伝える。

### 例
```csharp
// token を渡さず、取り消しの合図が途中で切れる
public async Task Process(Order order) { await _client.SendAsync(order); }

// CancellationToken を末端まで渡す
public async Task Process(Order order, CancellationToken cancellationToken)
{
    cancellationToken.ThrowIfCancellationRequested();
    await _client.SendAsync(order, cancellationToken);   // 下流へも渡す
}
```

## 並行の組

### 要求
並行のタスクは範囲の中で開始し、完了と失敗を範囲の終わりで待ち合わせて回収する。
範囲を抜けたタスクを残さない。
子が一つ失敗したら、linked CancellationTokenSource で残りの兄弟へ取り消しを伝え、全ての完了を待ってから失敗を伝える。
並行して走らせる数は SemaphoreSlim で、一括処理は Parallel.ForEachAsync の MaxDegreeOfParallelism で上限を定める。

### 根拠
範囲の外でタスクを開始すると、孤児のタスクが残り、失敗も取り消しも追えない。
範囲の中で開始し範囲の終わりで待ち合わせれば、孤児が残らず、失敗が範囲の中で扱える。
Task.WhenAll で待ち合わせれば、失敗が表に出る。
ただし Task.WhenAll は最初の例外を表に出すだけで、待ち合わせている他のタスクを取り消さず、走らせたまま残す。
linked CancellationTokenSource で兄弟へ取り消しを伝えれば、無駄な実行を早く止められ、全ての完了を待ってから失敗を伝えれば、孤児を残さない。
並行度を無制限にすると資源が枯渇し外部依存を圧迫するので、SemaphoreSlim や Parallel.ForEachAsync の MaxDegreeOfParallelism で上限を固定する。

### 完了条件
並行のタスクが、範囲の中で開始され、範囲の終わりで回収されている。
範囲を抜けたタスクが、残っていない。
子の一つが失敗したとき、残りの兄弟が取り消され、全ての完了を待ってから失敗が伝えられている。
並行して走る数に、SemaphoreSlim または Parallel.ForEachAsync の MaxDegreeOfParallelism で上限が定められている。

### 禁止事項
範囲の外へ、タスクを投げっぱなしにすること。
子の失敗を、兄弟を取り消さずに走らせたまま放置すること。

### 行動
並行のタスクを範囲の中で開始し、Task.WhenAll で待ち合わせて回収する。
子の失敗を検知したら、linked CancellationTokenSource で兄弟へ取り消しを伝え、全ての完了を待ってから失敗を rethrow する。
個別の並行は SemaphoreSlim で、一括処理は Parallel.ForEachAsync の MaxDegreeOfParallelism で並行度の上限を定める。

### 例
```csharp
// 投げっぱなし。孤児のタスクが残り、失敗も取り消しも追えない
foreach (var job in jobs) _ = RunAsync(job);

// 範囲の中で開始し、一つの失敗で兄弟を取り消し、全ての完了を待ってから伝える
using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
var tasks = jobs.Select(job => RunAsync(job, linkedCts.Token)).ToArray();
try { await Task.WhenAll(tasks); }
catch
{
    linkedCts.Cancel();                                                  // 兄弟へ取り消しを伝える
    await Task.WhenAll(tasks.Select(t => t.ContinueWith(_ => { })));     // 全ての完了を待つ
    throw;                                                               // 待ってから失敗を伝える
}
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

### 根拠
`using`/`await using` は、例外や早期リターンでスコープを抜けるときも `IDisposable`/`IAsyncDisposable` の `Dispose`/`DisposeAsync` を呼ぶ言語機構である。
`await using` は `IAsyncDisposable` を要求するので、`IDisposable` にしか対応しない資源へ付けると CS8410 になる。
Effect の中で確保した資源は、`AcquireRelease` が成功・失敗・取り消しのいずれでも一度だけ解放するので、coordination がそこへ委ねれば機構が二重にならない。

### 完了条件
coordination が扱う資源が、`IDisposable` は `using`、`IAsyncDisposable` は `await using` で確保されている。
Effect の中の資源取得と解放が、connection の `AcquireRelease` に委ねられている。

### 禁止事項
資源を、`using` も `await using` も無いまま持ち回ること。
Effect の中の資源解放を、`AcquireRelease` を介さず手で書くこと。

### 行動
coordination が直接扱う資源は、`IDisposable` なら `using`、`IAsyncDisposable` なら `await using` で確保する。
Effect の中で取得する資源は connection の `AcquireRelease` に委ねる。

### 例
```csharp
// 資源を手動で閉じる。例外の経路で Dispose が呼ばれない
var subscription = source.Subscribe(handler);
DoWork(); subscription.Dispose();

// using で確保し、例外や早期リターンでも解放する
using var subscription = source.Subscribe(handler);   // IObservable.Subscribe は IDisposable を返す。IAsyncDisposable でないため await using は CS8410 になる
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency.md)、副作用を境界に集める原則は [separation](../../principles/separation.md)、効果の取り消しと資源は [effect](../../concerns/effect.md)、停止の合図と優雅な終了は [lifecycle](../../concerns/lifecycle.md) に従う。
Effect の中の資源解放は [connection](./connection.md) の `AcquireRelease` に従う。
