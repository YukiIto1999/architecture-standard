# ts-results-es

用途は、viewer・extension・host の軽い役割に見合う、副作用と想定内失敗を型で表す機構である。
採用は、TypeScript は ts-results-es である。
判断基準は、軽量な Result 型を提供して要求チャネル・依存注入・fiber runtime を持ち込まず、同期の throw と Promise の rejection を同じ一箇所で Result へ写し、error mapper が再送出した欠陥を元の error のまま呼出側へ伝えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 効果を遅延した関数で表す

### 要求
副作用を伴う計算は、環境、AbortSignal、wall-clock の絶対期限を受け取り AsyncResult を返す遅延した関数で表す。
Effect は、`unique symbol` の nominal brand を持つ callable な値にする。
Effect の brand は、`deferEffect` だけが構築する。
全ての公開 Effect factory は、共通の `deferEffect` constructor に実行用の関数リテラルを渡す。
公開 Effect factory の parameter は、default parameter と destructuring の binding initializer を持たない。
公開 Effect factory の本体は、副作用を実行せず `deferEffect` への委譲だけを行う。
生成では実行せず、製品の code では実行境界でだけ呼ぶ。
実行境界は、host や runtime が呼び出す入口の関数である。
実行境界の関数は、project が構造検査の設定に列挙した形で判定する。
列挙する形は、関数を渡す登録 API の呼出し(symbol と引数の位置)、object を渡す登録 API の呼出し(symbol と引数の位置と method 名)、JSX の属性(属性名)、host が名前で呼ぶ export 関数(entry の file と関数名)である。
`withDeadlineEffect` を呼ぶのは、製品の code の、列挙した実行境界の関数の内側に限る。
製品の code の Effect の内側(`deferEffect` に渡す関数リテラルの内側)では、`withDeadlineEffect` を呼ばず、受け取った signal と期限で動く。
典型の実行境界は、UI の event handler と JSX の `on` 属性、remote の読み口の createMemo の compute、extension と host の command・message・event の listener、provider の method、host が名前で呼ぶ activate と deactivate である。
remote の読み口の compute は、[solidjs](./solidjs.md) の「remote の規律」に従う。
純粋な view の計算は、この関数で包まず純粋なままにする。

### 根拠
関数は呼ぶまで動かない遅延した値なので、合成し、取り消し、差し替えても、その時点では副作用が起きない。
関数型だけでは、factory の本体が Effect を返す前に副作用を起動していないことを保証できない。
構造だけが同じ関数から Effect を区別するには、callee の型に固有の nominal brand が要る。
Effect の呼出結果は AsyncResult なので、call expression の戻り値だけでは Effect の呼出かを判定できない。
default parameter と destructuring の binding initializer は、factory 本体へ入る前に評価される。
全ての公開 factory を `deferEffect` へ限定すれば、副作用を開始できる箇所を実行用の関数リテラルの内側へ集約できる。
環境を引数に受けると、計算が要求する能力が型に出て、テストで差し替えられる。
AbortSignal を通すと、取り消しを計算全体へ伝播できる。
wall-clock の絶対期限を通すと、[coordination](./coordination.md) の Effect 専用 `withDeadlineEffect` が定める期限の権威を下流へ渡せる。
実行を実行境界に集めると、どこで副作用が起きるかが一箇所で読める。
実行境界は、callback の外にある契機で host や runtime が呼び出す入口である。
UI の event と、remote の読み口の入力の変化は、登録された関数を呼び出す契機になる。
extension と host は、command と message に限らず、action や storage の変更や navigation などの event の listener を呼び出す。
host は、設定や task を返す provider を object として受け取ってその method を呼び出し、拡張の起動では entry の file が export する関数を名前で呼ぶ。
provider の method と名前で呼ばれる export 関数は、関数を渡す登録の形に当たらないので、object を渡す登録 API の symbol と引数の位置と method 名、および entry の export 名を別の形として設定に列挙する。
JSX の属性は、呼出しの引数でなく属性名で関数を受けるので、属性名を設定に列挙する。
入口を設定に列挙すれば、host や library が増えても、`withDeadlineEffect` の呼出位置を構文から検査できる。
列挙した登録 API が本当に入口かは、構文から判定できないので、レビューで確かめる。
`withDeadlineEffect` を Effect の内側で入れ子にしない理由は、[coordination](./coordination.md) の「取り消し」に従う。
`withDeadlineEffect` の契約は、test が境界の外から直接実行して確かめるので、呼出位置の限定は製品の code に課し、test の file には課さない。
viewer・extension・host は server の効果と永続化を持たないので、重い効果型を作らず、この軽い形で足りる。

### 完了条件
副作用を伴う計算が、環境、AbortSignal、wall-clock の絶対期限を受け AsyncResult を返す遅延した関数になっている。
Effect の callable な型が、`unique symbol` の nominal brand を持っている。
`deferEffect` だけが、Effect の brand を持つ値を構築している。
全ての公開 Effect factory が、副作用を実行しない本体から実行用の関数リテラルを `deferEffect` へ渡している。
全ての公開 Effect factory の parameter に、default parameter と destructuring の binding initializer が無い。
`deferEffect` が、返した Effect の呼出前に実行用の関数リテラルを呼ばず、呼出後にだけ開始することが実行テストで確認されている。
全ての公開 Effect factory の委譲が、TypeScript compiler API による AST 構造検査で確認されている。
実行が、host や runtime が呼び出す入口の関数に集まっている。
実行境界の形が、関数を渡す登録 API の呼出しの symbol と引数の位置、object を渡す登録 API の呼出しの symbol と引数の位置と method 名、JSX の属性名、host が名前で呼ぶ export 関数の名前と entry の file として、project の構造検査の設定に列挙されている。
列挙した登録 API と関数名が、host や runtime が呼び出す入口であることが、レビューで確認されている。
製品の code の `withDeadlineEffect` の呼出しが、列挙した実行境界の関数の内側にある。
製品の code の `deferEffect` に渡す関数リテラルの内側に、`withDeadlineEffect` の呼出しが無い。
`withDeadlineEffect` の呼出位置が、TypeScript compiler API による AST 構造検査で確認されている。
純粋な view の計算が、効果の関数で包まれていない。

### 禁止事項
生成と同時に副作用を起動すること。
`deferEffect` の外で、Effect の brand を構築または型変換で偽装すること。
公開 Effect factory から、`deferEffect` を介さず Effect を返すこと。
公開 Effect factory の parameter に、default parameter を置くこと。
公開 Effect factory の destructuring parameter に、binding initializer を置くこと。
公開 Effect factory の本体で、副作用を伴う API を呼ぶこと。
viewer・extension・host に、server 側の重い効果型を持ち込むこと。
製品の code で、列挙した実行境界の関数の外から、`withDeadlineEffect` を呼ぶこと。
製品の code で、`deferEffect` に渡す関数リテラルの内側から `withDeadlineEffect` を呼ぶこと。
実行境界の形を設定に列挙せず、`withDeadlineEffect` の呼出位置を人の判断だけで許すこと。
host や runtime が呼び出す入口でない関数を、実行境界として列挙すること。

### 行動
副作用を、環境、AbortSignal、wall-clock の絶対期限を受け AsyncResult を返す実行用の関数リテラルにする。
Effect の callable な型へ `unique symbol` の brand を加える。
Effect の brand は、`deferEffect` の実装内だけで構築する。
TypeScript compiler API による AST 構造検査で、brand の値参照と Effect への type assertion を `deferEffect` の実装内へ限定する。
公開 Effect factory の parameter から、default parameter と destructuring の binding initializer を除く。
全ての公開 Effect factory から、その関数リテラルを共通の `deferEffect` へ渡す。
TypeScript compiler API による AST 構造検査で、全ての公開 Effect factory に parameter initializer が無く、本体が副作用を実行せず `deferEffect` へ委譲することを検査する。
実行テストでは `deferEffect` 自体を構築し、返した Effect の呼出前は副作用が0件で、呼出後にだけ開始することを確認する。
製品の code では、Effect を実行境界の関数の内側で `withDeadlineEffect` から呼ぶ。
実行境界の形を、関数を渡す登録 API の呼出しの symbol と引数の位置、object を渡す登録 API の呼出しの symbol と引数の位置と method 名、JSX の属性名、host が名前で呼ぶ export 関数の名前と entry の file として、構造検査の設定に列挙し、列挙が入口であることをレビューで確かめる。
製品の code の Effect の内側では `withDeadlineEffect` を呼ばず、受け取った signal と期限で動く。
製品の code の外部 I/O を要する helper は、`deferEffect` で Effect を返す形にする。
TypeScript compiler API による AST 構造検査で、製品の code の `withDeadlineEffect` の呼出しが、列挙した実行境界の関数の内側にあり、`deferEffect` に渡す関数リテラルの内側に無いことを検査する。
test の file は、[inspection](./inspection.md) の「構造」が定める集合であり、この検査の対象に含めない。

### 例
生の `Promise` は生成と同時に実行が始まる。

```typescript
const user = fetchUser(id);
```

公開 factory は、実行用の関数リテラルを共通 constructor へ渡す。

```typescript
const effectBrand: unique symbol = Symbol("Effect");
type Effect<Env, E, A> = {
  (env: Env, signal: AbortSignal, deadlineAt: number): AsyncResult<A, E>;
  readonly [effectBrand]: true;
};
const deferEffect = <Env, E, A>(
  run: (env: Env, signal: AbortSignal, deadlineAt: number) => AsyncResult<A, E>,
): Effect<Env, E, A> => {
  const effect = (env: Env, signal: AbortSignal, deadlineAt: number) =>
    run(env, signal, deadlineAt);
  return Object.defineProperty(effect, effectBrand, { value: true }) as Effect<Env, E, A>;
};
```

default parameter は factory 本体より前に評価される。

```typescript
export const eagerLoad = (
  userId: UserId = readCurrentUserId(),
): Effect<HasUsers, LoadError, User> =>
  deferEffect((env, signal, deadlineAt) => env.users.find(userId, signal, deadlineAt));
```

destructuring の binding initializer も、factory 本体より前に評価される。

```typescript
export const eagerDestructuredLoad = (
  { userId = readCurrentUserId() }: LoadInput,
): Effect<HasUsers, LoadError, User> =>
  deferEffect((env, signal, deadlineAt) => env.users.find(userId, signal, deadlineAt));
```

initializer の無い parameter と `deferEffect` に渡す関数リテラルだけで factory を構成する。

```typescript
export const loadUser = (userId: UserId): Effect<HasUsers, LoadError, User> =>
  deferEffect((env, signal, deadlineAt) => env.users.find(userId, signal, deadlineAt));
```

外部 I/O を要する helper が Effect でなく関数として port を呼ぶと、Effect の内側と期限 wrapper の実装の外から外部 I/O が起きる。

```typescript
export const findNow = (env: HasUsers, userId: UserId, signal: AbortSignal, deadlineAt: number) =>
  env.users.find(userId, signal, deadlineAt);
```

外部 I/O を要する helper は `deferEffect` で Effect を返し、Effect の内側では受け取った signal と期限を渡して下流 Effect を直接呼ぶ。

```typescript
export const loadUserName = (userId: UserId): Effect<HasUsers, LoadError, string> =>
  deferEffect((env, signal, deadlineAt) =>
    loadUser(userId)(env, signal, deadlineAt).map((user) => user.name));
```

Effect の内側で `withDeadlineEffect` を呼ぶと、期限を設ける呼出しが入れ子になり、取り消しで終えるべき内側の処理が期限の超過を失敗として返す。

```typescript
export const loadUserNameNested = (userId: UserId): Effect<HasUsers, LoadError | DeadlineExceeded, string> =>
  deferEffect((env, signal, deadlineAt) =>
    withDeadlineEffect(env, loadUser(userId), deadlineAt, signal, resumeSource).map((user) => user.name));
```

実行境界の関数の外の関数が Effect を実行すると、どの入口から副作用が起きるかが読めず、呼出位置の検査も通らない。

```typescript
export const loginNow = (body: LoginBody) =>
  withDeadlineEffect(env, submitLogin(body), deadlinePolicy.createAt(), parentSignal, resumeSource);
```

UI の event は、JSX の `on` 属性に渡す関数の内側で Effect を実行する。

```tsx
<button
  onClick={() =>
    withDeadlineEffect(env, submitLogin(body), deadlinePolicy.createAt(), parentSignal, resumeSource)}
>
  Login
</button>;
```

extension の command は登録する関数の内側で、provider は登録 API に渡す object の列挙した method の内側で、Effect を実行する。
host が名前で呼ぶ export 関数は、entry の file と名前を設定に列挙すれば、その本体が実行境界になる。

```typescript
export async function activate(context: ExtensionContext) {
  context.subscriptions.push(
    commands.registerCommand("example.login", () =>
      withDeadlineEffect(env, submitLogin(body), deadlinePolicy.createAt(), parentSignal, resumeSource)),
    tasks.registerTaskProvider("example", {
      provideTasks: async () => {
        const listed = await withDeadlineEffect(env, listTasks(), deadlinePolicy.createAt(), parentSignal, resumeSource);
        return listed.isOk() ? listed.value : [];
      },
      resolveTask: () => undefined,
    }),
  );
}
```

remote の読み口の compute で実行する形は、[solidjs](./solidjs.md) の「remote の規律」の例に従う。

## 想定内失敗を Result で返す

### 要求
想定された失敗は ts-results-es の Result・AsyncResult で返し、error は判別子つきの union で分類する。
error の判別子による分岐の網羅は、[formation](./formation.md) の「不正な状態を構築できなくする」に従う。
Result の `unwrap`・`expect`・`unwrapErr`・`expectErr` は、test の file の外で呼ばない。
test の file は、[inspection](./inspection.md) の「構造」が定める集合である。
Err の扱いは、`isOk`・`isErr` で絞った後の `value`・`error` の参照、`mapErr`、`unwrapOr`・`unwrapOrElse` などで書く。

### 根拠
想定された失敗を Result にすれば、失敗が型に現れ、呼び出し側が扱いを強制される。
error を判別子つきの union にすれば、失敗の種別を網羅で扱える。
`unwrap`・`expect` は Err のとき、`unwrapErr`・`expectErr` は Ok のときに送出するので、呼び出し側が Result の型に現れた失敗を欠陥として送出できてしまう。
ts-results-es の文書は、`unwrap` が送出し得るので使用を推奨せず、判定で絞った後は `value` を使うよう示す。

### 完了条件
想定された失敗が、Result・AsyncResult で返されている。
error が、判別子つきの union で分類されている。
error の判別子による分岐が、formation の完了条件を満たしている。
Result の `unwrap`・`expect`・`unwrapErr`・`expectErr` の呼出しが、test の file の外に無い。

### 禁止事項
想定された失敗を、throw で表すこと。
error を、種別の判別できない単一の型で表すこと。
Result の `unwrap`・`expect`・`unwrapErr`・`expectErr` で、想定された失敗を送出すること。

### 行動
想定された失敗を Result・AsyncResult にし、error を判別子つきの union で分類する。
error の判別子による分岐を、formation に従って switch で書く。
Result の `unwrap`・`expect`・`unwrapErr`・`expectErr` の呼出しを、TypeScript compiler API の構造検査で test の file の外から拒否する。

### 例
想定内失敗を throw すると型に現れず、呼び出し側の捕捉も強制されない。

```typescript
async function find(id: Id): Promise<User> { throw new Error("not found"); }
```

`Result` で返し、error を判別子つき union で分類する。

```typescript
type FindError = { kind: "notFound" } | { kind: "unavailable" };
function find(id: Id): AsyncResult<User, FindError> { /* ... */ }
```

`unwrap` は Err のとき送出し、想定内の失敗が欠陥になる。

```typescript
const user = (await find(id)).unwrap();
```

Err を判定で扱い、error の種別は formation に従って switch で網羅する。

```typescript
async function show(id: Id): Promise<View> {
  const found = await find(id);
  if (found.isErr()) {
    switch (found.error.kind) {
      case "notFound": return renderNotFound();
      case "unavailable": return renderUnavailable();
    }
  }
  return renderUser(found.value);
}
```

## 非同期 API の送出を AsyncResult へ変換する

### 要求
Promise を返し、Promise を返す前にも同期で throw し得る API は、呼出式を関数リテラルに入れて `Result.wrapAsync` へ渡す。
`Result.wrapAsync` が返す Promise へ `mapErr` を繋ぎ、同期の throw と Promise の rejection を同じ一箇所で変換する。
その Promise を `new AsyncResult` で包み、AsyncResult として返す。
`Result.wrapAsync` の error の型引数は `unknown` のままにし、判別子つきの error は `mapErr` だけが与える。
想定された失敗だけを error mapper で判別子つきの error へ写し、回復できない欠陥は再 throw する。
中断の識別と、取り消しと上限の超過の層ごとの扱いは、[coordination](./coordination.md) の「取り消し」に従う。

### 根拠
`Result.wrapAsync` は関数リテラルの呼出しを内側で行い、同期の throw と返された Promise の rejection の両方を同じ Err へ集める。
呼出式を関数リテラルの外で評価すると、Promise を返す前の同期の throw が変換境界を抜ける。
`mapErr` は Err のときだけ mapper を呼ぶので、成功値は素通りし、失敗だけが判別子つきの error になる。
mapper が再送出した欠陥は包んだ Promise の rejection になり、AsyncResult を待つ呼出側へ元の error のまま届く。
`Result.wrapAsync` は捕捉した値を error の型引数へ無検査で当てるため、`unknown` 以外を与えると型が実体と食い違う。
想定された失敗だけを error にすれば、欠陥と取り消しを業務上の失敗として回復しない。

### 完了条件
Promise を返す境界 API の呼出式が、`Result.wrapAsync` に渡す関数リテラルの内側にある。
同期の throw と Promise の rejection が、同じ error mapper で想定された失敗へ変換されている。
`Result.wrapAsync` の結果に `mapErr` が繋がり、`new AsyncResult` で包まれた AsyncResult が返されている。
`Result.wrapAsync` の error の型引数が `unknown` である。
回復できない欠陥が、AsyncResult の error に混ざらず元の error のまま再 throw されている。
中断が、[coordination](./coordination.md) の「取り消し」の層の規則どおりに扱われている。

### 禁止事項
境界 API の呼出式を、`Result.wrapAsync` の関数リテラルの外で評価すること。
`Result.wrapAsync` の結果に `mapErr` を繋がず、`unknown` の error を持つ Result を境界の外へ出すこと。
`Result.wrapAsync` の error の型引数に、`unknown` 以外を与えること。
回復できない欠陥または取り消しを、想定された失敗の error へ変換すること。

### 行動
Promise を返す API 呼出しを、`new AsyncResult(Result.wrapAsync(() => operation()).then((received) => received.mapErr(mapper)))` の形で AsyncResult へ変換する。
mapper は、想定された失敗だけを変換し、欠陥を再 throw し、中断は [coordination](./coordination.md) の「取り消し」の層の規則に従って扱う。

### 例
呼出式を関数リテラルの外で評価すると、同期の throw が変換境界を抜ける。

```typescript
const promise = operation();
const unsafe = new AsyncResult(
  Result.wrapAsync<Response, unknown>(() => promise).then((received) => received.mapErr(mapper)),
);
```

上限を設けない層の error mapper は、中断をそのまま送出し、想定内失敗だけを変換する。
`isInterrupted` は、[coordination](./coordination.md) の「取り消し」の例の関数である。

```typescript
const toRequestError = (signal: AbortSignal, error: unknown): RequestError => {
  if (isInterrupted(error, signal)) throw error;
  if (error instanceof TransportUnavailable) {
    return { kind: "transportUnavailable", cause: error };
  }
  throw error;
};
```

関数リテラルの呼出しと `Promise` の完了を同じ境界で受け、mapper へ operation に渡した signal を渡す。

```typescript
const result = await new AsyncResult(
  Result.wrapAsync<Response, unknown>(() => operation()).then(
    (received) => received.mapErr((error) => toRequestError(signal, error)),
  ),
);
```

## 同期 API の送出を Result へ変換する

### 要求
同期で完了し throw し得る DOM API と postMessage は、呼出式を関数リテラルに入れて `Result.wrap` へ渡す。
`Result.wrap` が返す Result へ `mapErr` を繋ぎ、想定された失敗だけを判別子つきの error へ写す。
`Result.wrap` の error の型引数は `unknown` のままにする。
回復できない欠陥は再 throw する。

### 根拠
同期 API は Promise を返さないので、AsyncResult で非同期の形へ変える必要がない。
`Result.wrap` は関数リテラルを内側で呼び、同期の戻り値と throw を Result の二経路へ分ける。
`mapErr` は Err のときだけ同期で mapper を呼ぶので、mapper が再送出した欠陥はその場で呼出側へ伝わる。
`Result.wrap` は捕捉した値を error の型引数へ無検査で当てるため、`unknown` 以外を与えると型が実体と食い違う。
同期と非同期の境界を分けると、戻り値の実体と検査する送出経路が一致する。

### 完了条件
throw し得る同期 DOM API と postMessage の呼出式が、`Result.wrap` に渡す関数リテラルの内側にある。
`Result.wrap` の結果に `mapErr` が繋がり、判別子つきの error を持つ Result が返されている。
`Result.wrap` の error の型引数が `unknown` である。
想定された失敗だけが Result の error へ変換され、回復できない欠陥が元の error のまま再 throw されている。

### 禁止事項
同期 DOM API または postMessage を、`Result.wrapAsync` で受けること。
同期 API を Promise で包み、同期の throw の変換を非同期境界へ先送りすること。
`Result.wrap` の結果に `mapErr` を繋がず、`unknown` の error を持つ Result を境界の外へ出すこと。
`Result.wrap` の error の型引数に、`unknown` 以外を与えること。
回復できない欠陥を、想定された失敗の error へ変換すること。

### 行動
同期 API 呼出しを、`Result.wrap(() => operation()).mapErr(mapper)` の形で Result へ変換する。
DOM API と postMessage の mapper は想定された DOMException だけを変換し、それ以外を再 throw する。

### 例
```typescript
const element = Result.wrap<Element | null, unknown>(
  () => document.querySelector(selector),
).mapErr(toSelectorError);

const posted = Result.wrap<void, unknown>(
  () => targetWindow.postMessage(message, targetOrigin),
).mapErr(toPostMessageError);
```
