# coordination

## 概要
coordination は、TypeScript で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency/README.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、TypeScript の機構で満たす。
共有可変状態の回避は、connection が定める module 最上位の可変な singleton の禁止と、[solidjs](./solidjs.md) が持つ状態の機構の規律で満たす。
取り消しは AbortSignal で計算全体へ伝播し、[effect](../../concerns/effect/README.md) の取り消しの終了を実現する。
期限を設けた `withDeadlineEffect` は自身の期限の超過を想定内の失敗として受け取り、親の取り消しは取り消しのまま通す。
資源は範囲の終わりで解放する。

## 非同期

### 要求
非同期は、コールバックの入れ子より追いやすい逐次の形で書く。
これを async/await で満たす。

### 根拠
async/await は非同期の流れを逐次の形で書け、コールバックの入れ子や Promise の連鎖より追いやすい。

### 完了条件
非同期が、async/await で書かれている。

### 禁止事項
非同期の流れを、コールバックの入れ子で表すこと。

### 行動
非同期を async/await で書く。

## 取り消し

### 要求
取り消しは AbortSignal を渡して協調し、fetch には signal を渡す。
wall-clock の絶対期限を時刻値として権威にし、境界から全ての下流へ渡す。
期限を設ける Effect 専用の `withDeadlineEffect(env, effect, deadlineAt, parentSignal, resumeSource)` は、製品の code では、実行境界の関数の内側でだけ呼び、Effect の内側では呼ばない。
Effect の内側の外部 I/O、待機、下流 Effect の呼出は、受け取った signal と絶対期限を渡し、新しい期限を作らない。
adapter が依存先の呼び出しに設ける上限は期限ではなく、受け取った signal と合成して短い方を採る。
製品の code の外部 I/O、待機、下流 Effect の呼出は、Effect の内側と `withDeadlineEffect` の実装の内側に限る。
test の file は、[inspection](./inspection.md) の「構造」が定める集合であり、これらの呼出位置の制限の対象にしない。
外部 I/O と待機の symbol は、TypeScript compiler API による AST 構造検査の設定に列挙する。
下流 Effect の呼出は、callee expression の型が Effect の nominal brand を持つか、branded Effect へ代入可能かで識別する。
Effect の内側は、期限 signal の abort を取り消しとして受け、rejection で終える。
Effect の内側は、期限 signal の abort を、`E` の failure や `DeadlineExceeded` へ写さない。
期限を越えた後は、abort 済みの signal を受けた外部 I/O と下流 Effect が、新しい外部効果を始めない。
`withDeadlineEffect` は、host ごとの `ResumeSource` capability を受け取り、operation の開始の直前と終了の直後と host の再開時に `Date.now() >= deadlineAt` を確認する。
直前の確認で期限を越えていれば operation を開始せず、再開時の確認では期限用 controller を abort して実行中の operation へ取り消しを伝える。
直後の確認は、確定した終了を変えず、期限超過を診断 metadata または log へ記録する。
browser adapter は `pageshow` と表示再開時の `visibilitychange` を `ResumeSource` へ写す。
extension と IDE の adapter は host の再開通知を `ResumeSource` へ写す。
DOM を持たない host は、その host が提供する再開通知を `ResumeSource` へ写す。
`withDeadlineEffect` は、`AbortSignal.timeout`、親の signal、期限用の controller を `AbortSignal.any` で合成する。
期限確認の後に合成した signal が aborted なら、operation を開始せず、`throwIfAborted` で送出して下の判定に回す。
`withDeadlineEffect` は、絶対期限と合成した signal を operation へ渡す。
operation とその下流は、受け取った絶対期限を時刻値のまま伝播する。
`withDeadlineEffect` は `AsyncResult<T, E | DeadlineExceeded>` を返し、自身が設けた期限の超過を想定内の失敗 `DeadlineExceeded` として受け取る。
`withDeadlineEffect` は、operation の Result または rejection を捕捉し、`ResumeSource` の購読を解除してから期限と返却結果を判定する。
operation の解決(`Ok`、`Err`、rejection)が終了を確定し、解決の後に観測した期限超過と親の取消は、その終了を書き換えない。
operation が解決した `Err<E>` は、期限を越えていても元の failure を優先して返し、期限超過を診断 metadata または log へ記録する。
operation が解決した `Ok` は、期限を越えていても値のまま返し、期限超過を診断 metadata または log へ記録する。
中断で終えたかは、operation に渡した signal が判定の時点で aborted で、rejection の `name` が `AbortError` か `TimeoutError` であることで識別する。
adapter が自身の上限の signal を受け取った signal と合成して operation に渡す場合、operation に渡した signal の状態は、受け取った signal か自身の上限の signal のどちらかが aborted かで決まる。
signal を abort するときに reason を与える場合は、`AbortError` か `TimeoutError` の DOMException に限り、独自の値を reason にしない。
中断の原因は、判定の時点の signal の状態で決め、`name` や reason の値から推測しない。
中断で終えた rejection を捕捉した時点で親 signal が aborted なら、期限の超過が併存していても取り消しとし、rejection をそのまま送出する。
中断で終えた rejection を捕捉した時点で親 signal が aborted でなく、期限用 controller の signal か `AbortSignal.timeout` の signal が aborted なら、`DeadlineExceeded` へ写し、rejection をその cause に持たせる。
中断でない rejection は欠陥であり、期限の超過や取り消しが併存しても置き換えず、元の error のまま再送出し、期限を越えていれば期限超過を診断 metadata または log へ記録する。
上限を設けない内側の層は、中断と識別した rejection をそのまま送出する。
上限を設ける adapter の mapper は、受け取った signal と自身の上限の signal を受け、中断と識別した rejection を、受け取った signal が aborted ならそのまま送出し、そうでなく自身の上限の signal が aborted なら自身の想定内の失敗へ写す。
transport は、自身が設けた timeout や自身の取り消しで終えた要求を、`AbortError` と `TimeoutError` 以外の `name` を持つ自身の error 型で reject する。
期限超過を記録する診断境界は、error を送出しない。

### 根拠
JavaScript の Promise は作成時に実行が始まり、それ自体は止められない。
取り消しは AbortSignal を渡して協調で行い、abort で下流の操作を止める。
fetch に signal を渡せば、abort で通信が止まる。
abort 済みの signal を渡された fetch は、通信を始めずにその abort reason で拒否する。
相対時間だけを下流へ渡すと、call ごとに時間枠が再設定され、全体の期限を越える。
wall-clock の絶対期限を時刻値で渡せば、call を重ねても期限の起点が動かない。
adapter が依存先の呼び出しに設ける上限は、[resilience](../../concerns/resilience/dependency-call-control.md) の「外部依存の呼び出しを制御する層に置く」が定める port 層の上限であり、受け取った signal と合成して短い方を採るので、期限の起点を引き直さない。
`AbortSignal.timeout` は active time の相対時間を数え、suspend 中は進まないため、wall-clock の期限を単独では強制できない。
suspend をまたいだ実行中の operation を再開後に止める手段は、再開通知で期限用 controller を abort することだけである。
fetch は signal の abort reason で拒否し、DOM は reason を与えない abort に `AbortError`、`AbortSignal.timeout` に `TimeoutError` の DOMException を与えるので、reason を DOMException に限れば、中断は signal の状態と rejection の `name` で識別できる。
operation の開始の直前と実行環境の再開時に `Date.now()` で確認すれば、suspend 中に期限を越えた仕事を再開後に始めない。
期限を越えた仕事を続行しないとは新しい外部効果を始めないことであり、完了した結果を変えることではない。
operation が `Ok` を返した時点で外部効果は起きており、後から期限を越えたと観測して `Err(DeadlineExceeded)` へ書き換えると、成功した書き込みが失敗として報告され、呼び出し側が重複した再実行を始める。
期限の超過は、期限を設けた側にとって応答や再試行を決める必要のある結果であり、結果を要らなくなった親の取消とは扱いが異なる。
期限 signal の abort が operation に伝えるのは、期限を設けた側が結果を待たなくなったことだけなので、operation は取り消しで終える。
中断で終えた rejection は、期限用の signal が aborted なら期限の超過に続く終了なので、`DeadlineExceeded` への写像は書き換えではなく、期限を設けた側による期限の受け取りである。
期限は実行境界で一度だけ作られ、下流には同じ絶対期限が渡る。
wrapper を Effect の内側で入れ子にすると、各 wrapper が自身の期限用 controller と timeout を持つので、内側の wrapper が先に期限を観測すれば内側の処理が `DeadlineExceeded` の失敗を受け取り、外側の signal が先に abort すれば同じ原因が取り消しになり、終了の種類が timer の順で変わる。
期限を設ける側を実行境界の wrapper だけにすれば、内側の処理は期限の超過を取り消しで終え、内側で期限の超過から回復する経路ができない。
内側が受け取った signal を外部 I/O と下流 Effect へ渡せば、期限の超過と親の取消がどちらも同じ signal の abort として届き、新しい外部効果は abort 済みの signal で始まらない。
期限処理を実行境界の `withDeadlineEffect` に集めれば、期限の timer と controller と親の signal の合成が一つに定まる。
外部 I/O と待機の symbol を検査設定に列挙し、callee expression の型に Effect の nominal brand があるかを調べれば、Effect の外の直接呼出を構文から判定できる。
test の file を呼出位置の制限から除く理由は、[inspection](./inspection.md) の「構造」に従う。
operation へ絶対期限を渡せば、下流でも局所の timeout signal が止まる環境に wall-clock の権威を失わない。
親の signal、active time の timeout signal、期限用の controller を `AbortSignal.any` で合成すれば、親の取消と局所の待ちの打ち切りを同じ下流の signal へ伝えられる。
解決済みの `Err` を Promise の成功とみなして期限 error へ置き換えると、契約で宣言した failure を失う。
期限判定を `finally` から送出すると、operation の failure または defect を期限 error で上書きする。
中断の `name` は親の取り消しと期限の超過のどちらでも `AbortError` か `TimeoutError` になるので、中断の原因は `name` でなく判定の時点の signal の状態で決める。
識別が合成した signal の reason の値や cause chain に依らないので、実行環境が合成 signal の reason を決める時期の違いに左右されない。
transport が自身の timeout や取り消しを `AbortError` と `TimeoutError` 以外の自身の error 型で reject すれば、adapter はそれを中断と取り違えず、通信の不成立として識別できる。
結果を待つ側が取り消した後には、期限の超過を受け取って応答や再試行を決める側がいないので、判定の時点で親の取消が成り立っていれば取り消しを優先する。

### 完了条件
取り消しが、AbortSignal で協調して伝えられている。
fetch に、signal が渡されている。
wall-clock の絶対期限が、時刻値として境界から全ての下流へ渡されている。
製品の code で、`withDeadlineEffect` が、実行境界の関数の内側でだけ呼ばれ、Effect の内側で呼ばれていない。
Effect の内側の外部 I/O、待機、下流 Effect の呼出が、受け取った signal と絶対期限を渡している。
adapter が依存先の呼び出しに設ける上限が、期限から作られず、受け取った signal と合成されて短い方が採られている。
製品の code の外部 I/O、待機、下流 Effect の呼出が、Effect の内側と `withDeadlineEffect` の実装の内側にだけある。
外部 I/O と待機の symbol が、TypeScript compiler API による AST 構造検査の設定に列挙されている。
下流 Effect の呼出が、callee expression の nominal brand と branded Effect への代入可能性で識別されている。
`withDeadlineEffect` が host ごとの `ResumeSource` を受け、operation の開始の直前と終了の直後と host の再開時に絶対期限を確認している。
直前の確認が期限を越えた operation を始めさせず、直後の確認が確定した終了を変えずに期限超過を記録している。
再開通知の時点で期限を越えていれば、期限用 controller が abort され、実行中の operation の signal が abort されている。
browser、extension、IDE、DOM を持たない host が、それぞれの再開通知を adapter で `ResumeSource` へ写している。
`withDeadlineEffect` が、active time の timeout signal、親の signal、期限用の controller を `AbortSignal.any` で合成している。
期限確認の後に合成した signal が aborted の場合に、operation が開始されず、`throwIfAborted` で送出されている。
`withDeadlineEffect` が、絶対期限と合成した signal を operation へ渡している。
`withDeadlineEffect` が `AsyncResult<T, E | DeadlineExceeded>` を返し、自身が設けた期限の超過を `DeadlineExceeded` として受け取っている。
Effect の内側が、期限 signal の abort を rejection で終え、failure や `DeadlineExceeded` へ写していない。
operation とその下流が、受け取った絶対期限を時刻値のまま伝播している。
製品の code の、Effect の内側と `withDeadlineEffect` の実装の外にある外部 I/O、待機、下流 Effect の呼出と、Effect の内側の `withDeadlineEffect` の呼出が、TypeScript compiler API による AST 構造検査で禁止されている。
test の file が、この検査の対象に含まれていない。
operation の Result または rejection が捕捉され、`ResumeSource` の購読解除後に期限と返却結果が判定されている。
解決済みの `Err<E>` が元の failure のまま返され、期限超過が非送出の診断 metadata または log に記録されている。
operation が解決した `Ok` が、期限を越えていても値のまま返され、期限超過が非送出の診断 metadata または log に記録されている。
中断で終えた rejection が、親 signal が aborted でなく、期限用 controller の signal か `AbortSignal.timeout` の signal が aborted のとき、`DeadlineExceeded` へ写され、rejection がその cause に持たされている。
中断の識別が、operation に渡した signal の状態と rejection の `name` で行われ、中断の原因が判定の時点の signal の状態で決められている。
signal を abort するときの reason が、`AbortError` か `TimeoutError` の `DOMException` である。
判定の時点で親 signal が aborted の場合は、期限の超過が併存していても、中断で終えた rejection が `DeadlineExceeded` へ写されず、そのまま送出されている。
中断でない rejection が、期限超過や取り消しが併存しても置き換えられず、元の error のまま再送出され、期限を越えていれば期限超過が診断 metadata または log に記録されている。
上限を設けない内側の層が、中断と識別した rejection をそのまま送出している。
上限を設ける adapter の mapper が、中断と識別した rejection を、受け取った signal が aborted ならそのまま送出し、そうでなく自身の上限の signal が aborted なら自身の想定内の失敗へ写している。
transport が、自身が設けた timeout や自身の取り消しで終えた要求を、`AbortError` と `TimeoutError` 以外の `name` を持つ自身の error 型で reject している。
期限超過を記録する診断境界が、error を送出していない。
operation の解決の後に観測した期限超過と親の取消が、`Ok`・`Err`・rejection を別の終了へ書き換えていない。

### 禁止事項
Promise 自体を、止められると見なすこと。
fetch に signal を渡さず、通信を止められなくすること。
境界の期限から、call ごとに相対の timeout 値を引き直すこと。
`AbortSignal.timeout` を、絶対時刻を保持する signal とみなすこと。
独自の値を reason にして signal を abort すること。
中断の原因を、判定の時点の signal の状態でなく `name` や reason の値から推測すること。
suspend 中に `AbortSignal.timeout` が進まない限界を隠すこと。
絶対期限を相対時間へ置き換えて、下流へ渡すこと。
製品の code で、Effect の内側と `withDeadlineEffect` の実装の外から、外部 I/O、待機、下流 Effect を直接呼ぶこと。
製品の code で、Effect の内側で `withDeadlineEffect` を呼び、期限用 controller と timeout を入れ子にすること。
Effect の内側で、受け取った signal と絶対期限を渡さずに、外部 I/O、待機、下流 Effect を呼ぶこと。
`withDeadlineEffect` から `window` または `document` を直接参照すること。
非同期境界の前後または実行環境の再開時に、期限切れの仕事を続行すること。
listener の cleanup と送出を同じ `finally` で行い、operation の error を期限 error で上書きすること。
解決済みの `Ok`・`Err` を、期限超過だけを理由に `DeadlineExceeded` へ置き換えること。
期限超過の診断記録から error を送出し、元の failure または defect を上書きすること。
operation の解決の後に観測した期限超過または親の取消で、確定した終了を別の終了へ書き換えること。
自身が設けた期限の超過を、`DeadlineExceeded` へ写さず取り消しのまま再送出すること。
判定の時点で親 signal が aborted の取り消しを、期限の超過が併存することを理由に `DeadlineExceeded` へ写すこと。
Effect の内側で、期限 signal の abort を failure の `Err` や `DeadlineExceeded` へ写すこと。
中断でない rejection を、期限超過や取り消しへ置き換えること。

### 行動
AbortSignal を fetch や処理に渡し、abort で止める。
境界で wall-clock の絶対期限を作り、時刻値のまま全ての下流へ渡す。
製品の code の実行境界の関数で、Effect を共通の `withDeadlineEffect` から呼び、Effect の内側では `withDeadlineEffect` を呼ばない。
Effect の内側では、外部 I/O、待機、下流 Effect へ、受け取った signal と絶対期限を渡す。
adapter が依存先の呼び出しに設ける上限は、受け取った signal と合成して短い方を採る。
外部 I/O と待機の symbol を、TypeScript compiler API による AST 構造検査の設定に列挙する。
下流 Effect は、call expression の戻り値ではなく callee expression の型にある nominal brand と Effect への代入可能性で識別する。
`withDeadlineEffect` へ、host adapter が実装した `ResumeSource` を注入する。
browser adapter は `pageshow` と表示再開時の `visibilitychange` を、extension と IDE の adapter は host の再開通知を、DOM を持たない host は利用可能な host の再開通知を `ResumeSource` へ写す。
`withDeadlineEffect` で operation の開始の直前と終了の直後と `ResumeSource` の通知時に絶対期限を確認する。
直前の確認は期限を越えた operation を始めさせず、再開の通知では期限用 controller を abort して実行中の operation へ取り消しを伝え、直後の確認は確定した終了を変えずに期限超過を記録する。
`withDeadlineEffect` で現在の残り時間だけを `AbortSignal.timeout` に渡し、親の signal と期限用の controller を `AbortSignal.any` で合成する。
期限確認の後に合成した signal が aborted なら、`throwIfAborted` で operation を開始せず送出する。
`withDeadlineEffect` から operation へ、合成した signal と絶対期限を渡す。
TypeScript compiler API による AST 構造検査で、製品の code の、Effect の内側と `withDeadlineEffect` の実装の外にある外部 I/O、待機、下流 Effect の呼出と、Effect の内側の `withDeadlineEffect` の呼出と、wrapper 内の `window`・`document` の参照を禁止する。
test の file は、この検査の対象に含めない。
`withDeadlineEffect` で operation の Result または rejection を捕捉し、`ResumeSource` の購読を解除してから期限と返却結果を判定する。
解決済みの `Err` は元の failure のまま返し、`Ok` は期限を越えていても値のまま返し、期限超過を非送出の診断境界へ記録する。
中断で終えた rejection は、判定の時点で親 signal が aborted なら、期限の超過が併存していても、そのまま送出する。
中断で終えた rejection は、親 signal が aborted でなく、期限用 controller の signal か `AbortSignal.timeout` の signal が aborted なら、`DeadlineExceeded` へ写し、rejection を cause に持たせる。
中断でない rejection は期限超過や取り消しへ置き換えず元の error を再送出し、期限を越えていれば期限超過を非送出の診断境界へ記録する。
中断は operation に渡した signal の状態と rejection の `name` で識別し、中断の原因は signal の状態で決める。
signal を abort するときに reason を与える場合は、`AbortError` か `TimeoutError` の DOMException に限る。
上限を設けない内側の層は、中断と識別した rejection をそのまま送出する。
上限を設ける adapter の mapper は、受け取った signal と自身の上限の signal を受け、中断と識別した rejection を、受け取った signal が aborted ならそのまま送出し、そうでなく自身の上限の signal が aborted なら自身の想定内の失敗へ写す。
transport は、自身が設けた timeout や自身の取り消しで終えた要求を、`AbortError` と `TimeoutError` 以外の `name` を持つ自身の error 型で reject する。

### 例
実行境界が Effect を共通 wrapper の外から呼ぶと、期限と取り消しの手順を迂回する。

```typescript
const deadlineAt = Date.now() + 5_000;
const effect = loadUser(userId);

const directResult = await effect(env, parentSignal, deadlineAt);
```

Effect の内側で wrapper を呼ぶと、期限用 controller と timeout が入れ子になり、内側の処理が期限の超過を `DeadlineExceeded` の失敗として受け取る。

```typescript
const loadStatus = (url: URL): Effect<HasHttp, RequestError | DeadlineExceeded, number> =>
  deferEffect((env, signal, deadlineAt) =>
    withDeadlineEffect(env, requestUrl(url), deadlineAt, signal, resumeSource)
      .map((response) => response.status));
```

Effect の内側は、受け取った signal と絶対期限を下流 Effect へ渡し、期限の超過を取り消しとして受ける。

```typescript
const loadStatus = (url: URL): Effect<HasHttp, RequestError, number> =>
  deferEffect((env, signal, deadlineAt) =>
    requestUrl(url)(env, signal, deadlineAt).map((response) => response.status));
```

共通 wrapper は `ResumeSource` を受け、signal の状態と rejection の `name` で中断を識別し、期限超過と取り消しを signal の状態で判定する。
解決済みの `Ok`・`Err` と、中断でない rejection は、期限 error で上書きしない。

```typescript
class DeadlineExceeded extends Error {
  constructor(cause?: unknown) {
    super("deadline exceeded", { cause });
  }
}
function abortIfExpired(deadlineAt: number, controller: AbortController): void {
  if (Date.now() >= deadlineAt && !controller.signal.aborted) {
    controller.abort(new DOMException("deadline exceeded", "TimeoutError"));
  }
}
function assertWithinDeadline(
  deadlineAt: number,
  controller: AbortController,
  combinedSignal: AbortSignal,
): void {
  abortIfExpired(deadlineAt, controller);
  combinedSignal.throwIfAborted();
}
function isInterrupted(error: unknown, signal: AbortSignal | undefined): boolean {
  return (
    signal?.aborted === true &&
    error instanceof Error &&
    (error.name === "AbortError" || error.name === "TimeoutError")
  );
}
interface ResumeSource {
  subscribe(listener: () => void): () => void;
}
type OperationOutcome<A, E> =
  | { kind: "result"; result: Result<A, E> }
  | { kind: "rejection"; error: unknown };
function withDeadlineEffect<Env, E, A>(
  env: Env,
  effect: Effect<Env, E, A>,
  deadlineAt: number,
  parentSignal: AbortSignal,
  resumeSource: ResumeSource,
): AsyncResult<A, E | DeadlineExceeded> {
  return new AsyncResult((async (): Promise<Result<A, E | DeadlineExceeded>> => {
    const deadlineController = new AbortController();
    let combinedSignal: AbortSignal | undefined;
    let timeoutSignal: AbortSignal | undefined;
    let outcome: OperationOutcome<A, E>;
    const onResume = () => abortIfExpired(deadlineAt, deadlineController);
    const unsubscribeResume = resumeSource.subscribe(onResume);
    try {
      abortIfExpired(deadlineAt, deadlineController);
      const remainingMs = Math.max(0, deadlineAt - Date.now());
      timeoutSignal = AbortSignal.timeout(remainingMs);
      combinedSignal = AbortSignal.any([
        parentSignal,
        deadlineController.signal,
        timeoutSignal,
      ]);
      assertWithinDeadline(deadlineAt, deadlineController, combinedSignal);
      outcome = { kind: "result", result: await effect(env, combinedSignal, deadlineAt) };
    } catch (error) {
      outcome = { kind: "rejection", error };
    }

    unsubscribeResume();

    const observedAt = Date.now();
    if (outcome.kind === "rejection") {
      const interrupted = isInterrupted(outcome.error, combinedSignal);
      if (
        interrupted &&
        !parentSignal.aborted &&
        (deadlineController.signal.aborted || timeoutSignal?.aborted)
      ) {
        return Err(new DeadlineExceeded(outcome.error));
      }
      if (observedAt >= deadlineAt) {
        deadlineDiagnostics.annotateOverrun({ deadlineAt, observedAt, error: outcome.error });
      }
      throw outcome.error;
    }
    if (outcome.result.isErr()) {
      if (observedAt >= deadlineAt) {
        deadlineDiagnostics.annotateOverrun({ deadlineAt, observedAt, error: outcome.result.error });
      }
      return Err(outcome.result.error);
    }
    if (observedAt >= deadlineAt) {
      deadlineDiagnostics.annotateOverrun({ deadlineAt, observedAt });
    }
    return Ok(outcome.result.value);
  })());
}
```

browser、extension、IDE、DOM を持たない host は、それぞれの再開通知を capability へ写す。
wrapper 自体は DOM を参照せず、capability と絶対期限を使う。

```typescript
const browserResumeSource = resumeSourceFromBrowserEvents(window, document);
const extensionResumeSource = resumeSourceFromHostEvents(extensionHost);
const processResumeSource = resumeSourceFromHostEvents(processHost);

const boundedResult = await withDeadlineEffect(
  env,
  effect,
  deadlineAt,
  parentSignal,
  browserResumeSource,
);
```

operation が `Err` で解決した後に期限を超えても、同じ failure を返して overrun だけを記録する。

```typescript
const preservedFailure = await withDeadlineEffect(
  env,
  effectReturningErrAfterDeadline,
  deadlineAt,
  parentSignal,
  processResumeSource,
);
expect(preservedFailure.isErr() && preservedFailure.error).toBe(failure);
expect(deadlineDiagnostics.last()).toMatchObject({ deadlineAt, error: failure });
```

operation が `Ok` で解決した後に期限を超えても、`Ok` を値のまま返して overrun だけを記録する。

```typescript
const preservedValue = await withDeadlineEffect(
  env,
  effectReturningOkAfterDeadline,
  deadlineAt,
  parentSignal,
  processResumeSource,
);
expect(preservedValue).toEqual(Ok(value));
expect(deadlineDiagnostics.last()).toMatchObject({ deadlineAt });
```

期限 signal の abort で終えた operation は `DeadlineExceeded` の `Err` になり、親の signal の abort で終えた operation は親の reason の rejection のままになる。

```typescript
const settlesOnAbort = deferEffect((_env, signal: AbortSignal) => {
  const { promise, reject } = Promise.withResolvers<never>();
  signal.addEventListener("abort", () => reject(signal.reason), { once: true });
  return new AsyncResult(promise);
});

const exceeded = await withDeadlineEffect(
  env,
  settlesOnAbort,
  Date.now() + 10,
  parentSignal,
  processResumeSource,
);
expect(exceeded.isErr() && exceeded.error instanceof DeadlineExceeded).toBe(true);

const parent = new AbortController();
const parentCanceled = new DOMException("parent canceled", "AbortError");
const awaitingParent = withDeadlineEffect(
  env,
  settlesOnAbort,
  Date.now() + 60_000,
  parent.signal,
  processResumeSource,
);
parent.abort(parentCanceled);
await expect(awaitingParent).rejects.toBe(parentCanceled);
```

期限 signal の abort の後、operation が終える前に親が取り消した場合は、期限の超過が併存していても `DeadlineExceeded` へ写されず、中断の rejection のまま送出される。

```typescript
const settlesLateOnAbort = deferEffect((_env, signal: AbortSignal) => {
  const { promise, reject } = Promise.withResolvers<never>();
  signal.addEventListener("abort", () => setTimeout(() => reject(signal.reason), 30), { once: true });
  return new AsyncResult(promise);
});

const parentAfterDeadline = new AbortController();
const awaitingBoth = withDeadlineEffect(
  env,
  settlesLateOnAbort,
  Date.now() + 10,
  parentAfterDeadline.signal,
  processResumeSource,
);
setTimeout(() => parentAfterDeadline.abort(), 20);
await expect(awaitingBoth).rejects.toSatisfy(
  (error: unknown) =>
    !(error instanceof DeadlineExceeded) && isInterrupted(error, parentAfterDeadline.signal),
);
```

期限 signal の abort の後に中断でない rejection で終えた operation は、`DeadlineExceeded` へ写されず、欠陥のまま再送出される。

```typescript
const contractViolation = new TypeError("response violates contract");
const defectsOnAbort = deferEffect((_env, signal: AbortSignal) => {
  const { promise, reject } = Promise.withResolvers<never>();
  signal.addEventListener("abort", () => reject(contractViolation), { once: true });
  return new AsyncResult(promise);
});

await expect(withDeadlineEffect(
  env,
  defectsOnAbort,
  Date.now() + 10,
  parentSignal,
  processResumeSource,
)).rejects.toBe(contractViolation);
```

再開通知の時点で期限を越えていれば、実行中の operation の signal が abort され、`DeadlineExceeded` の `Err` になる。

```typescript
let notifyResume = () => {};
const resumeSource: ResumeSource = {
  subscribe: (listener) => {
    notifyResume = listener;
    return () => {
      notifyResume = () => {};
    };
  },
};

vi.useFakeTimers({ toFake: ["Date"] });
const running = withDeadlineEffect(
  env,
  settlesOnAbort,
  Date.now() + 60_000,
  parentSignal,
  resumeSource,
);
vi.setSystemTime(Date.now() + 120_000);
notifyResume();
const resumed = await running;
expect(resumed.isErr() && resumed.error instanceof DeadlineExceeded).toBe(true);
```

wrapper の開始前から親の取り消しと期限超過がともに成立していても、operation は開始されず、中断の rejection が送出される。

```typescript
const parentBeforeStart = new AbortController();
const parentReason = new DOMException("parent canceled", "AbortError");
parentBeforeStart.abort(parentReason);
let operationStarted = false;
const notStarted = deferEffect(() => {
  operationStarted = true;
  return Ok(undefined).toAsyncResult();
});
await expect(withDeadlineEffect(
  env,
  notStarted,
  Date.now(),
  parentBeforeStart.signal,
  processResumeSource,
)).rejects.toBe(parentReason);
expect(operationStarted).toBe(false);
```

## 並行の組

### 要求
並行の組は、Effect の内側で一つの AbortController に束ね、子 Effect を、受け取った signal と controller の signal を `AbortSignal.any` で合成した signal と絶対期限を渡して直接呼ぶ。
製品の code の並行の組の内側で `withDeadlineEffect` を呼ばない。
各 task が返す Result を観測し、最初の `Err` でも controller で残りの兄弟を abort する。
task の rejection も観測し、最初の defect で残りの兄弟を abort する。
abort 後も、各 task の Result と rejection を観測する Promise に `Promise.allSettled` で合流する。
task の rejection は、子へ渡した signal が aborted で `name` が `AbortError` か `TimeoutError` なら中断として失敗に `aborted` で残し、そうでなければ defect として残す。
全兄弟への合流後に、defect で終えた子があれば、最初の defect を cause に持つ全ての失敗を伴う AggregateError を送出する。
defect が無く、判定の時点で受け取った signal が aborted で、中断で終えた子があれば、取り消しで終え、子の失敗を診断に残す。
それ以外は、組が自ら中断させた子を除く子の結果から決め、`Err` があれば最初の `Err` を primary とする全ての失敗を伴う Result の err を返し、無ければ成功値を返す。
全ての子が結果を返して終えた場合は、受け取った signal が aborted でも結果を書き換えない。
並行度の上限を固定する機構は、標準が固定せず project が単一の採用を決定の記録に明記する。
各 Effect は、決定の記録で固定した単一の limiter が需要枠を与えた callback の内側で開始する。

### 根拠
AsyncResult の `Err` は Promise の解決値なので、task 自体を Promise.all に渡すだけでは兄弟を abort できない。
各 task の Result と rejection を観測する Promise を置けば、`Err` と defect のどちらでも残りの兄弟へ取消を早く伝えられる。
abort 後に観測用 Promise へ Promise.allSettled で合流すれば、未完了の兄弟を範囲の外へ残さない。
子の rejection を子へ渡した signal の状態と `name` で識別すれば、最初の失敗の結果として起きる兄弟の中断を、新しい defect と取り違えない。
まとめる順序と、結果を返した後に書き換えない理由は、[失敗と欠陥と取り消しを分ける](../../concerns/effect/failure-defect-cancellation.md)に従う。
取り消しで終えた子の値は無いので、成功値の配列に穴を残したまま成功として返すと、完了していない処理を成功として報告する。
最初の `Err` が起こした兄弟の中断は、結果を要らなくなった側の取り消しではないので、受け取った signal が aborted でなければ取り消しとせず、`Err` で終える。
並行の組の内側で `withDeadlineEffect` を呼ぶと、子ごとに期限用 controller と timeout が入れ子になり、子が期限の超過を想定内の失敗として受け取る。
JavaScript の標準実行環境は並行度を上限で絞る組み込みの機構を持たないので、上限を固定する具体の機構は project の決定の記録に単一採用を明記させる。
Effect の生成と開始を分け、limiter の callback 内で子 Effect を呼べば、需要枠を得る前に外部 I/O を開始しない。

### 完了条件
並行の組が、Effect の内側で一つの AbortController に束ねられ、子 Effect が合成した signal と絶対期限を受けて直接呼ばれている。
製品の code の並行の組の内側で、`withDeadlineEffect` が呼ばれていない。
各 task の Result が観測され、最初の `Err` で残りの兄弟が abort されている。
task の rejection が観測され、最初の defect で残りの兄弟が abort されている。
abort 後も、Result と rejection の観測用 Promise が Promise.allSettled で全ての兄弟へ合流している。
task の rejection が、子へ渡した signal の状態と `name` で、中断としての `aborted` と defect に分けて失敗に残されている。
全兄弟への合流後に、defect で終えた子があれば AggregateError が送出され、defect が無く判定の時点で受け取った signal が aborted で中断で終えた子があれば取り消しで終えられ、子の失敗が診断に残され、成功値の配列に穴を残した `Ok` が返されていない。
それ以外は組が自ら中断させた子を除く子の結果から決められ、`Err` があれば最初の `Err` を primary とする全ての失敗を伴う Result の err が返されている。
全ての子が結果を返して終えた場合に、受け取った signal が aborted でも、結果が書き換えられていない。
並行度の上限を固定する機構が、project の決定の記録に明記されている。
全ての Effect が、決定の記録で固定した単一の limiter の需要枠内で開始されている。

### 禁止事項
一つが失敗しても、束ねた残りの実行を走らせ続けること。
AsyncResult の `Err` を Promise の成功だけとみなし、兄弟を走らせ続けること。
最初の `Err` または rejection を伝播し、兄弟への合流を飛ばすこと。
中断と識別できる rejection を、独立した defect とみなすこと。
子の defect を、同時に成り立つ取り消しで置き換えること。
中断で終えた子があり受け取った signal が aborted なのに、成功値の配列に穴を残して `Ok` を返すこと。
全ての子が結果を返して終えた並行の組を、後から観測した受け取った signal の取り消しで書き換えること。
最初の失敗だけを残し、他の失敗を捨てること。
製品の code で、並行の組の内側で `withDeadlineEffect` を呼び、子ごとに期限を入れ子にすること。
limiter の需要枠を得る前に子 Effect を呼び、開始すること。

### 行動
並行の組を、Effect の内側で一つの AbortController に束ねる。
子 Effect へ、受け取った signal と controller の signal を `AbortSignal.any` で合成した signal と、受け取った絶対期限を渡して直接呼ぶ。
各 task の Result と rejection を観測し、最初の `Err` または rejection で controller から残りを abort する。
合流後に、defect があれば最初の defect を cause に持つ AggregateError を送出し、defect が無く判定の時点で受け取った signal が aborted で中断で終えた子があれば、子の失敗を診断へ残して取り消しで終える。
それ以外は組が自ら中断させた子を除く子の結果から決め、全ての子が結果を返して終えた場合は、受け取った signal の状態で書き換えない。
各失敗の task の識別、種類と元の値を保持し、`Err` なら最初の `Err` を primary とする全てを伴う Result の err を返す。
project の決定の記録で固定した単一の limiter を使い、その callback の内側で子 Effect を呼ぶ。

### 例
通信を branded Effect として遅延する。
error mapper へは、operation に渡した signal を渡す。

```typescript
const requestUrl = (url: URL): Effect<HasHttp, RequestError, Response> =>
  deferEffect((env, signal, deadlineAt) =>
    new AsyncResult(
      Result.wrapAsync<Response, unknown>(
        () => env.http.fetch(url, { signal, deadlineAt }),
      ).then((received) => received.mapErr((error) => toRequestError(signal, error))),
    ));
```

並行の組は Effect として書き、期限の wrapper は実行境界で一度だけ呼ぶ。
最初の `Err` または rejection で abort し、全兄弟へ合流してから結果を決め、失敗を全て保持する。
defect があれば AggregateError を送出し、defect が無く判定の時点で受け取った signal が aborted で中断で終えた子があれば、失敗を診断に残して中断の rejection のまま送出する。
limiter は project の決定の記録で一つに固定し、その需要枠の内側で初めて子 Effect を呼ぶ。

```typescript
type ChildFailure =
  | { readonly index: number; readonly kind: "expected"; readonly error: RequestError }
  | { readonly index: number; readonly kind: "defect"; readonly error: unknown }
  | { readonly index: number; readonly kind: "aborted"; readonly error: unknown };
type ParallelFailure = {
  readonly primary: RequestError;
  readonly failures: readonly ChildFailure[];
};

const loadAll = (
  urls: readonly URL[],
): Effect<HasHttp & HasLimiter, ParallelFailure, readonly Response[]> =>
  deferEffect((env, signal, deadlineAt) =>
    new AsyncResult((async (): Promise<Result<readonly Response[], ParallelFailure>> => {
      const controller = new AbortController();
      const groupSignal = AbortSignal.any([signal, controller.signal]);
      const tasks = urls.map((url) =>
        env.limiter.run(() => requestUrl(url)(env, groupSignal, deadlineAt)));
      const responses = new Array<Response>(tasks.length);
      const failures: ChildFailure[] = [];

      const observations = tasks.map(async (task, index) => {
        try {
          const result = await task;
          if (result.isErr()) {
            failures.push({ index, kind: "expected", error: result.error });
            controller.abort();
            return;
          }
          responses[index] = result.value;
        } catch (error) {
          const kind = isInterrupted(error, groupSignal) ? "aborted" : "defect";
          failures.push({ index, kind, error });
          controller.abort();
        }
      });

      await Promise.allSettled(observations);
      const firstDefect = failures.find((failure) => failure.kind === "defect");
      if (firstDefect) {
        throw new AggregateError(failures, "parallel operation failed", { cause: firstDefect.error });
      }
      const firstInterrupted = failures.find((failure) => failure.kind === "aborted");
      if (signal.aborted && firstInterrupted) {
        groupDiagnostics.record(failures);
        throw firstInterrupted.error;
      }
      const firstExpected = failures.find((failure) => failure.kind === "expected");
      if (firstExpected) return Err({ primary: firstExpected.error, failures });
      return Ok(responses);
    })()));

const loaded = await withDeadlineEffect(
  env,
  loadAll(urls),
  deadlineAt,
  parentSignal,
  resumeSource,
);
```

## メインスレッドを塞がない

### 要求
重い同期の計算を、viewer のメインスレッドと extension の host のイベント処理で実行しない。
重い同期計算は、Web Worker へ退避する。

### 根拠
browser の実行は単一スレッドで、同期の計算が続く間は描画も入力も止まる。
extension の host も単一のイベントループで、塞ぐと editor の応答が止まる。
Worker へ退避すれば、メインスレッドはイベントの処理へ戻れる。
非同期の見た目に包んだだけの同期計算は、待ちを分割するだけで、実行の間はやはりスレッドを塞ぐ。

### 完了条件
メインスレッドを塞ぐ重い同期計算が、Worker へ退避されている。
退避した計算との受け渡しが、値のメッセージで行われている。

### 禁止事項
重い同期計算を、イベントの処理の中で実行すること。
非同期の見た目に包んだだけの同期計算で、退避を済ませたと称すること。

### 行動
入力から描画までを塞ぐ処理を計測で特定し、Worker へ移す。
Worker との境界は、値のメッセージで受け渡す。

## 後始末

### 要求
購読と資源は解除の手立てを返す形で確保し、範囲の終わりで解放する。
viewer は解除を onCleanup に委ね、extension は購読と資源を host の Disposable として host の購読管理に委ねる。
createMemo の run が始めた通信、timer、購読は、compute 自身の同期の本体で、解除を `onCleanup` へ登録する。

### 根拠
購読と資源を解除の手立てなく確保すると、範囲を抜けても残り、漏れる。
解除を返す形で確保すれば、範囲の終わりで確実に解放できる。
viewer は SolidJS の反応の範囲の終わりを onCleanup が持ち、extension は host が Disposable の集合を終了時に一括で解放する。
Solid は置き換えた run の結果を捨てるが、その run が始めた通信、timer、購読は run 自身が止めない限り続く。
画面に出る前に置き換えられた run の onCleanup は、置き換えの時点で走る。
画面に出ている run の onCleanup は、置き換えが commit される時点で走る。
owner が破棄されるときは、画面に出ている run と通信中の run の onCleanup が破棄の時点で走る。
`AsyncResult` の method へ渡す関数の中で呼んだ `onCleanup` は、run の後始末として走らない。
`await` の後で呼んだ `onCleanup` も、run の後始末として走らない。

### 完了条件
購読と資源が、解除の手立てを返す形で確保されている。
viewer の購読と資源が、onCleanup で範囲の終わりに解放されている。
extension の購読と資源が、host の Disposable として host の購読管理に登録されている。
createMemo の run が始めた通信、timer、購読の解除が、compute 自身の同期の本体で `onCleanup` へ登録されている。
`AsyncResult` の method へ渡す関数の中に、`onCleanup` の呼出しが無い。
画面に出る前に置き換えられた run の解除が置き換えの時点で、owner の破棄で終わる run の解除が破棄の時点で、走っている。

### 禁止事項
購読と資源を、解除の手立てなく確保すること。
`AsyncResult` の method へ渡す関数の中や `await` の後で、run の解除を `onCleanup` へ登録すること。

### 行動
viewer は購読の解除を onCleanup に登録する。
extension は購読と資源を Disposable にし、host の購読管理へ登録する。
createMemo の run は、始める通信、timer、購読の解除を、compute 自身の同期の本体で `onCleanup` に登録する。
run が始める remote の通信は、[solidjs](./solidjs.md) の「remote の規律」に従って取消に結ぶ。

### 例

viewer は反応の範囲が終わるときに `onCleanup` から購読を解除する。
extension は購読を `Disposable` として host の購読管理へ登録し、終了時に一括して解放する。

```typescript
const unsubscribe = source.subscribe(handler);
onCleanup(unsubscribe);

const disposable = watcher.onDidChange(handler);
context.subscriptions.push(disposable);
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency/README.md)、副作用を境界に集める原則は [separation](../../principles/separation/README.md)、効果の取り消しと資源は [effect](../../concerns/effect/README.md) に従う。
