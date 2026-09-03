# coordination

## 概要
coordination は、TypeScript で非同期・並行・取り消しの実行を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める副作用の境界と、concerns の [concurrency](../../concerns/concurrency.md) が定める構造化された並行・取り消しの協調・共有可変状態の回避を、TypeScript の機構で満たす。
共有可変状態の回避は、connection が定める module 最上位の可変な singleton の禁止と、[solidjs](./solidjs.md) が持つ状態の機構の規律で満たす。
取り消しは AbortSignal で計算全体へ伝播し、[effect](../../concerns/effect.md) の取り消しの終了を実現する。
資源は範囲の終わりで解放する。

## 非同期

### 要求
非同期は、コールバックの入れ子より追いやすい逐次の形で書く。これを async/await で満たす。

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
外部 I/O、待機、下流 Effect の非同期境界は、共通の Effect 専用 `withDeadlineEffect(env, effect, deadlineAt, parentSignal, resumeSource)` からだけ呼ぶ。
外部 I/O と待機の symbol は、TypeScript compiler API による AST 構造検査の設定に列挙する。
下流 Effect の呼出は、callee expression の型が Effect の nominal brand を持つか、branded Effect へ代入可能かで識別する。
`withDeadlineEffect` は、host ごとの `ResumeSource` capability を受け取り、非同期境界の直前と直後と host の再開時に `Date.now() >= deadlineAt` を確認する。
browser adapter は `pageshow` と表示再開時の `visibilitychange` を `ResumeSource` へ写す。
extension と IDE の adapter は host の再開通知を `ResumeSource` へ写す。
DOM を持たない host は、その host が提供する再開通知を `ResumeSource` へ写す。
`withDeadlineEffect` は、現在の残り時間を扱う `AbortSignal.timeout`、親の signal、期限用の controller を `AbortSignal.any` で合成する。
親の signal は `AbortSignal.any` の iterable の先頭に置く。
wrapper の開始前に親の取消と期限超過がともに成立している場合は、合成した signal が選んだ親の reason を優先する。
期限確認で期限用 controller を abort した後は、合成した signal の `throwIfAborted` を呼び、実際に選ばれた reason を送出する。
`withDeadlineEffect` は、絶対期限と合成した signal を operation へ渡す。
operation とその下流は、受け取った絶対期限を時刻値のまま伝播する。
`withDeadlineEffect` は `ResultAsync<T, E | DeadlineExceeded>` を返す。
`withDeadlineEffect` は、operation の Result または rejection を捕捉し、`ResumeSource` の購読を解除してから期限と返却結果を判定する。
operation が解決した `Err<E>` は、期限を越えていても元の failure を優先して返し、期限超過を診断 metadata または log へ記録する。
operation の rejection が期限 signal の reason と同一か、その reason を cause chain に持つなら、`DeadlineExceeded` へ写す。
cause chain を安全に読めない場合は正規化せず、operation の元の rejection を保持する。
共通 wrapper が呼ぶ operation は、取消 error に signal の reason を同一値または cause として保持する。
期限 signal が取消元かは、その signal が aborted であり、合成した signal の reason がその signal の reason と一致することで判定する。
合成した signal の reason が親 signal の reason と一致する場合は、期限 signal より親 signal を取消元として優先する。
operation の rejection が別の defect なら、期限を越えていても元の error を優先して再送出する。
別の defect と期限超過が併存した場合は、元の error を変えずに期限超過を診断 metadata または log へ記録する。
期限超過を記録する診断境界は、error を送出しない。
operation が `Ok` を返した後に期限超過を確認した場合は、値を返さず `Err(DeadlineExceeded)` を返す。

### 根拠
JavaScript の Promise は作成時に実行が始まり、それ自体は止められない。
取り消しは AbortSignal を渡して協調で行い、abort で下流の操作を止める。
fetch に signal を渡せば、abort で通信が止まる。
相対時間だけを下流へ渡すと、call ごとに時間枠が再設定され、全体の期限を越える。
wall-clock の絶対期限を時刻値で渡せば、call を重ねても期限の起点が動かない。
`AbortSignal.timeout` は active time の相対時間を数え、suspend 中は進まないため、wall-clock の期限を単独では強制できない。
`AbortSignal.timeout` の reason は TimeoutError なので、AbortError という名前では期限由来かを判定できない。
非同期境界の前後と実行環境の再開時に `Date.now()` で確認すれば、suspend 中に期限を越えた仕事を再開後に続行しない。
期限処理を `withDeadlineEffect` に集めれば、外部 I/O、待機、下流 Effect で確認と signal 合成の手順がずれない。
外部 I/O と待機の symbol を検査設定に列挙し、callee expression の型に Effect の nominal brand があるかを調べれば、直接呼出を構文から判定できる。
operation へ絶対期限を渡せば、下流でも局所の timeout signal が止まる環境に wall-clock の権威を失わない。
親の signal、active time の timeout signal、期限用の controller を `AbortSignal.any` で合成すれば、親の取消と局所の待ちの打ち切りを同じ下流の signal へ伝えられる。
複数の入力が合成前から abort 済みなら、`AbortSignal.any` は iterable で先に現れる abort 済み signal の reason を選ぶ。
期限確認後に期限用 signal の reason を直接送出すると、合成した signal が選んだ親の reason を上書きする。
解決済みの `Err` を Promise の成功とみなして期限 error へ置き換えると、契約で宣言した failure を失う。
期限判定を `finally` から送出すると、operation の failure または defect を期限 error で上書きする。
operation の rejection と期限 signal の reason を同一性または cause chain で照合すれば、期限由来の取消だけを `DeadlineExceeded` に写し、別の defect を保持できる。
親 signal の reason を先に照合すれば、親取消と期限取消が競合しても親由来の error を期限 error に誤変換しない。

### 完了条件
取り消しが、AbortSignal で協調して伝えられている。
fetch に、signal が渡されている。
wall-clock の絶対期限が、時刻値として境界から全ての下流へ渡されている。
外部 I/O、待機、下流 Effect が、`withDeadlineEffect` から呼ばれている。
外部 I/O と待機の symbol が、TypeScript compiler API による AST 構造検査の設定に列挙されている。
下流 Effect の呼出が、callee expression の nominal brand と branded Effect への代入可能性で識別されている。
`withDeadlineEffect` が host ごとの `ResumeSource` を受け、非同期境界の直前と直後と host の再開時に絶対期限を確認している。
browser、extension、IDE、DOM を持たない host が、それぞれの再開通知を adapter で `ResumeSource` へ写している。
`withDeadlineEffect` が、active time の timeout signal、親の signal、期限用の controller を `AbortSignal.any` で合成している。
親の signal が `AbortSignal.any` の iterable の先頭にあり、wrapper の開始前に親の取消と期限超過がともに成立している場合も、合成した signal の親 reason が保持されている。
期限確認で期限用 controller を abort した後に、合成した signal の `throwIfAborted` から実際に選ばれた reason が送出されている。
`withDeadlineEffect` が、絶対期限と合成した signal を operation へ渡している。
`withDeadlineEffect` が `ResultAsync<T, E | DeadlineExceeded>` を返している。
operation とその下流が、受け取った絶対期限を時刻値のまま伝播している。
外部 I/O、待機、下流 Effect の直接呼出が、TypeScript compiler API による AST 構造検査で禁止されている。
operation の Result または rejection が捕捉され、`ResumeSource` の購読解除後に期限と返却結果が判定されている。
解決済みの `Err<E>` が元の failure のまま返され、期限超過が非送出の診断 metadata または log に記録されている。
operation の rejection が期限 signal の reason と同一か、その reason を cause chain に持つ場合だけ、`DeadlineExceeded` へ写されている。
cause chain を安全に読めない場合は、operation の元の rejection が保持されている。
operation の取消 error が、signal の reason を同一値または cause として保持している。
期限 signal が aborted であり、合成した signal の reason がその signal の reason と一致するときだけ、期限 signal を取消元と判定している。
合成した signal の reason が親 signal の reason と一致する場合は、親 signal が取消元として優先されている。
別の defect が期限 error で上書きされず、期限超過が診断 metadata または log に記録されている。
期限超過を記録する診断境界が、error を送出していない。
operation の `Ok` 後に期限を越えていた場合は、値の代わりに `Err(DeadlineExceeded)` が返されている。

### 禁止事項
Promise 自体を、止められると見なすこと。
fetch に signal を渡さず、通信を止められなくすること。
相対の timeout 値を、call ごとに引き直すこと。
`AbortSignal.timeout` を、絶対時刻を保持する signal とみなすこと。
AbortError という名前だけで、operation の error を期限由来と判定すること。
cause chain の読取 error で、operation の元の error を上書きすること。
suspend 中に `AbortSignal.timeout` が進まない限界を隠すこと。
絶対期限を相対時間へ置き換えて、下流へ渡すこと。
外部 I/O、待機、下流 Effect を、`withDeadlineEffect` の operation の外から直接呼ぶこと。
`withDeadlineEffect` から `window` または `document` を直接参照すること。
非同期境界の前後または実行環境の再開時に、期限切れの仕事を続行すること。
listener の cleanup と送出を同じ `finally` で行い、operation の error を期限 error で上書きすること。
解決済みの `Err`、または期限と無関係な defect を、期限超過だけを理由に `DeadlineExceeded` へ置き換えること。
期限超過の診断記録から error を送出し、元の failure または defect を上書きすること。
operation が `Ok` を返した後に期限を越えている値を返すこと。
期限確認後に期限用 signal の reason を直接送出し、合成した signal が選んだ親の reason を上書きすること。

### 行動
AbortSignal を fetch や処理に渡し、abort で止める。
境界で wall-clock の絶対期限を作り、時刻値のまま全ての下流へ渡す。
外部 I/O、待機、下流 Effect を、共通の `withDeadlineEffect` の operation から呼ぶ。
外部 I/O と待機の symbol を、TypeScript compiler API による AST 構造検査の設定に列挙する。
下流 Effect は、call expression の戻り値ではなく callee expression の型にある nominal brand と Effect への代入可能性で識別する。
`withDeadlineEffect` へ、host adapter が実装した `ResumeSource` を注入する。
browser adapter は `pageshow` と表示再開時の `visibilitychange` を、extension と IDE の adapter は host の再開通知を、DOM を持たない host は利用可能な host の再開通知を `ResumeSource` へ写す。
`withDeadlineEffect` で非同期境界の直前と直後と `ResumeSource` の通知時に絶対期限を確認する。
`withDeadlineEffect` で現在の残り時間だけを `AbortSignal.timeout` に渡し、親の signal と期限用の controller を `AbortSignal.any` で合成する。
親の signal を `AbortSignal.any` の iterable の先頭に置く。
期限確認で期限用 controller を abort した後は、合成した signal の `throwIfAborted` を呼ぶ。
`withDeadlineEffect` から operation へ、合成した signal と絶対期限を渡す。
TypeScript compiler API による AST 構造検査で、`withDeadlineEffect` の operation の外にある外部 I/O、待機、下流 Effect の直接呼出と、wrapper 内の `window`・`document` の参照を禁止する。
`withDeadlineEffect` で operation の Result または rejection を捕捉し、`ResumeSource` の購読を解除してから期限と返却結果を判定する。
解決済みの `Err` は元の failure のまま返し、期限超過を非送出の診断境界へ記録する。
operation の rejection と期限 signal の reason が同一か、rejection の cause chain にその reason がある場合だけ `DeadlineExceeded` へ写す。
cause chain の読取に失敗した場合は、正規化せず operation の元の rejection を再送出する。
operation の取消 error に、signal の reason を同一値または cause として保持する。
親 signal の reason を先に照合し、期限用 controller と timeout signal の reason を順に照合して取消元を判定する。
別の defect は元の error を再送出し、期限超過を非送出の診断境界へ記録する。
operation が `Ok` を返しても購読解除後に期限を再確認し、期限を越えていたら `Err(DeadlineExceeded)` を返す。

### 例
下流 Effect を共通 wrapper の外から呼ぶと、期限と取り消しの手順を迂回する。

```typescript
const deadlineAt = Date.now() + 5_000;
const effect = loadUser(userId);

const directResult = await effect(env, parentSignal, deadlineAt);
```

共通 wrapper は `ResumeSource` を受け、期限超過と取り消しの理由を判定する。解決済みの `Err` と独立した defect は期限 error で上書きしない。

```typescript
class DeadlineExceeded extends Error {
  constructor(cause?: unknown) {
    super("deadline exceeded", { cause });
  }
}
function abortIfExpired(deadlineAt: number, controller: AbortController): void {
  if (Date.now() >= deadlineAt && !controller.signal.aborted) {
    controller.abort(new DeadlineExceeded());
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
function hasCause(error: unknown, expected: unknown): boolean {
  let current = error;
  const visited = new Set<unknown>();
  while (!visited.has(current)) {
    if (Object.is(current, expected)) return true;
    if (typeof current !== "object" || current === null) return false;
    visited.add(current);
    try {
      if (!("cause" in current)) return false;
      current = current.cause;
    } catch {
      return false;
    }
  }
  return false;
}
function findDeadlineSource(
  combinedSignal: AbortSignal | undefined,
  parentSignal: AbortSignal,
  deadlineSignal: AbortSignal,
  timeoutSignal: AbortSignal | undefined,
): { reason: unknown } | undefined {
  if (combinedSignal?.aborted !== true) return undefined;
  if (parentSignal.aborted && Object.is(combinedSignal.reason, parentSignal.reason)) return undefined;
  if (deadlineSignal.aborted && Object.is(combinedSignal.reason, deadlineSignal.reason)) {
    return { reason: deadlineSignal.reason };
  }
  if (timeoutSignal?.aborted === true && Object.is(combinedSignal.reason, timeoutSignal.reason)) {
    return { reason: timeoutSignal.reason };
  }
  return undefined;
}
interface ResumeSource {
  subscribe(listener: () => void): () => void;
}
type OperationOutcome<A, E> =
  | { kind: "result"; result: Result<A, E> }
  | { kind: "rejection"; error: unknown; deadlineSource: { reason: unknown } | undefined };
function withDeadlineEffect<Env, E, A>(
  env: Env,
  effect: Effect<Env, E, A>,
  deadlineAt: number,
  parentSignal: AbortSignal,
  resumeSource: ResumeSource,
): ResultAsync<A, E | DeadlineExceeded> {
  return new ResultAsync((async (): Promise<Result<A, E | DeadlineExceeded>> => {
    const deadlineController = new AbortController();
    let timeoutSignal: AbortSignal | undefined;
    let combinedSignal: AbortSignal | undefined;
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
      outcome = {
        kind: "rejection",
        error,
        deadlineSource: findDeadlineSource(
          combinedSignal,
          parentSignal,
          deadlineController.signal,
          timeoutSignal,
        ),
      };
    }

    unsubscribeResume();

    const observedAt = Date.now();
    if (outcome.kind === "rejection") {
      if (outcome.deadlineSource &&
          (Object.is(outcome.error, outcome.deadlineSource.reason) ||
           hasCause(outcome.error, outcome.deadlineSource.reason))) {
        return err(new DeadlineExceeded(outcome.error));
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
      return err(outcome.result.error);
    }
    if (observedAt >= deadlineAt) {
      return err(new DeadlineExceeded());
    }
    return ok(outcome.result.value);
  })());
}
```

browser、extension、IDE、DOM を持たない host は、それぞれの再開通知を capability へ写す。wrapper 自体は DOM を参照せず、capability と絶対期限を使う。

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
expect(preservedFailure).toEqual(err(failure));
expect(deadlineDiagnostics.last()).toMatchObject({ deadlineAt, error: failure });
```

wrapper の開始前から親の取り消しと期限超過がともに成立していても、`AbortSignal.any` が選んだ親の reason を保持する。

```typescript
const parentBeforeStart = new AbortController();
const parentReason = new Error("parent canceled");
parentBeforeStart.abort(parentReason);
let operationStarted = false;
const notStarted = deferEffect(() => {
  operationStarted = true;
  return okAsync(undefined);
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
並行の組は、一つの AbortController に束ねる。
各 task が返す Result を観測し、最初の `Err` でも controller で残りの兄弟を abort する。
task の rejection も観測し、最初の defect で残りの兄弟を abort する。
abort 後も、各 task の Result と rejection を観測する Promise に `Promise.allSettled` で合流する。
controller の abort が兄弟に生じさせた rejection は、独立した defect として数えない。
全兄弟への合流後に独立した rejection defect があれば、`Err` より優先して最初の defect を送出する。
独立した rejection defect が無ければ、最初に観測した `Err` を Result のまま返す。
`Err` と独立した rejection が同時に成立した場合も、観測順にかかわらず rejection defect を優先する。
並行度の上限を固定する機構は、標準が固定せず project が単一の採用を ADR に明記する。
各 Effect は、ADR で固定した単一の limiter が需要枠を与えた callback の内側で開始する。

### 根拠
ResultAsync の `Err` は Promise の解決値なので、task 自体を Promise.all に渡すだけでは兄弟を abort できない。
各 task の Result と rejection を観測する Promise を置けば、`Err` と defect のどちらでも残りの兄弟へ取消を早く伝えられる。
abort 後に観測用 Promise へ Promise.allSettled で合流すれば、未完了の兄弟を範囲の外へ残さない。
controller 由来の rejection を除外すれば、`Err` による sibling abort を新しい defect と取り違えない。
独立した rejection defect を `Err` より優先すれば、回復不能な欠陥を想定内失敗として返さない。
JavaScript の標準実行環境は並行度を上限で絞る組み込みの機構を持たないので、上限を固定する具体の機構は project の ADR に単一採用を明記させる。
Effect の生成と開始を分け、limiter の callback 内で `withDeadlineEffect` を呼べば、需要枠を得る前に外部 I/O を開始しない。

### 完了条件
並行の組が、一つの AbortController に束ねられている。
各 task の Result が観測され、最初の `Err` で残りの兄弟が abort されている。
task の rejection が観測され、最初の defect で残りの兄弟が abort されている。
abort 後も、Result と rejection の観測用 Promise が Promise.allSettled で全ての兄弟へ合流している。
controller 由来の sibling cancellation rejection が、独立した defect から除外されている。
全兄弟への合流後に独立した rejection defect があれば、最初の `Err` より優先して最初の defect が送出されている。
独立した rejection defect が無ければ、最初に観測した `Err` が Result として返されている。
`Err` と独立した rejection が同時に成立した場合も、rejection defect が優先されている。
並行度の上限を固定する機構が、project の ADR に明記されている。
全ての Effect が、ADR で固定した単一の limiter の需要枠内で開始されている。

### 禁止事項
一つが失敗しても、束ねた残りの実行を走らせ続けること。
ResultAsync の `Err` を Promise の成功だけとみなし、兄弟を走らせ続けること。
最初の `Err` または rejection を伝播し、兄弟への合流を飛ばすこと。
`Err` による controller の abort が生じさせた rejection を独立した defect とみなすこと。
独立した rejection defect を `Err` で隠すこと。
limiter の需要枠を得る前に `withDeadlineEffect` を呼び、Effect を開始すること。

### 行動
並行の組を一つの AbortController に束ねる。
各 task の Result と rejection を観測し、最初の `Err` または rejection で controller から残りを abort する。
controller 由来の sibling cancellation rejection を独立した defect から除外する。
観測用 Promise に Promise.allSettled で合流してから、独立した rejection defect、最初に観測した `Err`、成功値の順に結果を決める。
`Err` と独立した rejection が同時に成立した場合は、観測順にかかわらず rejection defect を優先する。
project の ADR で固定した単一の limiter を使い、その callback の内側で `withDeadlineEffect` を呼ぶ。

### 例
通信を branded Effect として遅延し、期限 wrapper の内側だけで開始する。

```typescript
const requestUrl = (url: URL): Effect<HasHttp, RequestError, Response> =>
  deferEffect((env, signal, deadlineAt) =>
    ResultAsync.fromThrowable(
      () => env.http.fetch(url, { signal, deadlineAt }),
      toRequestError,
    )());
```

最初の `Err` または rejection で abort し、全兄弟へ合流してから結果を決める。limiter は project の ADR で一つに固定し、その需要枠の内側で初めて Effect を開始する。

```typescript
const controller = new AbortController();
const signal = AbortSignal.any([parentSignal, controller.signal]);
const tasks = urls
  .map(requestUrl)
  .map((effect) => limiter.run(() =>
    withDeadlineEffect(
      env,
      effect,
      deadlineAt,
      signal,
      resumeSource,
    )));
const combinedResult = await (async (): Promise<Result<readonly Response[], RequestError | DeadlineExceeded>> => {
  const responses = new Array<Response>(tasks.length);
  let firstFailure: { error: RequestError | DeadlineExceeded } | undefined;
  let firstDefect: { error: unknown } | undefined;
  const abortSiblings = (trigger: unknown): void => {
    if (!controller.signal.aborted) {
      controller.abort(new Error("sibling canceled", { cause: trigger }));
    }
  };

  const observations = tasks.map(async (task, index) => {
    try {
      const result = await task;
      if (result.isErr()) {
        firstFailure ??= { error: result.error };
        abortSiblings(result.error);
        return;
      }
      responses[index] = result.value;
    } catch (error) {
      const causedBySiblingAbort = controller.signal.aborted &&
        (Object.is(error, controller.signal.reason) ||
         hasCause(error, controller.signal.reason));
      if (causedBySiblingAbort) return;
      firstDefect ??= { error };
      abortSiblings(error);
    }
  });

  await Promise.allSettled(observations);
  if (firstDefect) throw firstDefect.error;
  if (firstFailure) return err(firstFailure.error);
  return ok(responses);
})();
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

### 根拠
購読と資源を解除の手立てなく確保すると、範囲を抜けても残り、漏れる。
解除を返す形で確保すれば、範囲の終わりで確実に解放できる。
viewer は SolidJS の反応の範囲の終わりを onCleanup が持ち、extension は host が Disposable の集合を終了時に一括で解放する。

### 完了条件
購読と資源が、解除の手立てを返す形で確保されている。
viewer の購読と資源が、onCleanup で範囲の終わりに解放されている。
extension の購読と資源が、host の Disposable として host の購読管理に登録されている。

### 禁止事項
購読と資源を、解除の手立てなく確保すること。

### 行動
viewer は購読の解除を onCleanup に登録する。
extension は購読と資源を Disposable にし、host の購読管理へ登録する。

### 例

viewer は反応の範囲が終わるときに `onCleanup` から購読を解除する。extension は購読を `Disposable` として host の購読管理へ登録し、終了時に一括して解放する。

```typescript
const unsubscribe = source.subscribe(handler);
onCleanup(unsubscribe);

const disposable = watcher.onDidChange(handler);
context.subscriptions.push(disposable);
```

## 参照
並行の規律は [concurrency](../../concerns/concurrency.md)、副作用を境界に集める原則は [separation](../../principles/separation.md)、効果の取り消しと資源は [effect](../../concerns/effect.md) に従う。
