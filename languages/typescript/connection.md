# connection

## 概要
connection は、TypeScript で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect.md) が定める効果システムを、viewer・extension・host の軽い役割に合わせて満たす。
副作用は、環境、AbortSignal、wall-clock の絶対期限を受け ResultAsync を返す遅延した関数で表す。
[separation](../../principles/separation.md) の依存の向きと [dependency](../../concerns/dependency.md) の「依存を内側へ一方向に向ける」の規律に従う。

## 効果を遅延した関数で表す

### 要求
副作用を伴う計算は、環境、AbortSignal、wall-clock の絶対期限を受け取り ResultAsync を返す遅延した関数で表す。
Effect は、`unique symbol` の nominal brand を持つ callable な値にする。
Effect の brand は、`deferEffect` だけが構築する。
全ての公開 Effect factory は、共通の `deferEffect` constructor に実行用の関数リテラルを渡す。
公開 Effect factory の parameter は、default parameter と destructuring の binding initializer を持たない。
公開 Effect factory の本体は、副作用を実行せず `deferEffect` への委譲だけを行う。
生成では実行せず、UI のイベント境界でだけ呼ぶ。
純粋な view の計算は、この関数で包まず純粋なままにする。

### 根拠
関数は呼ぶまで動かない遅延した値なので、合成し、取り消し、差し替えても、その時点では副作用が起きない。
関数型だけでは、factory の本体が Effect を返す前に副作用を起動していないことを保証できない。
構造だけが同じ関数から Effect を区別するには、callee の型に固有の nominal brand が要る。
Effect の呼出結果は ResultAsync なので、call expression の戻り値だけでは Effect の呼出かを判定できない。
default parameter と destructuring の binding initializer は、factory 本体へ入る前に評価される。
全ての公開 factory を `deferEffect` へ限定すれば、副作用を開始できる箇所を実行用の関数リテラルの内側へ集約できる。
環境を引数に受けると、計算が要求する能力が型に出て、テストで差し替えられる。
AbortSignal を通すと、取り消しを計算全体へ伝播できる。
wall-clock の絶対期限を通すと、[coordination](./coordination.md) の Effect 専用 `withDeadlineEffect` が定める期限の権威を下流へ渡せる。
実行を UI のイベント境界に集めると、どこで副作用が起きるかが一箇所で読める。
viewer・extension・host は server の効果と永続化を持たないので、重い効果型を作らず、この軽い形で足りる。

### 完了条件
副作用を伴う計算が、環境、AbortSignal、wall-clock の絶対期限を受け ResultAsync を返す遅延した関数になっている。
Effect の callable な型が、`unique symbol` の nominal brand を持っている。
`deferEffect` だけが、Effect の brand を持つ値を構築している。
全ての公開 Effect factory が、副作用を実行しない本体から実行用の関数リテラルを `deferEffect` へ渡している。
全ての公開 Effect factory の parameter に、default parameter と destructuring の binding initializer が無い。
`deferEffect` が、返した Effect の呼出前に実行用の関数リテラルを呼ばず、呼出後にだけ開始することが実行テストで確認されている。
全ての公開 Effect factory の委譲が、TypeScript compiler API による AST 構造検査で確認されている。
実行が、UI のイベント境界に集まっている。
純粋な view の計算が、効果の関数で包まれていない。

### 禁止事項
生成と同時に副作用を起動すること。
`deferEffect` の外で、Effect の brand を構築または型変換で偽装すること。
公開 Effect factory から、`deferEffect` を介さず Effect を返すこと。
公開 Effect factory の parameter に、default parameter を置くこと。
公開 Effect factory の destructuring parameter に、binding initializer を置くこと。
公開 Effect factory の本体で、副作用を伴う API を呼ぶこと。
viewer・extension・host に、server 側の重い効果型を持ち込むこと。

### 行動
副作用を、環境、AbortSignal、wall-clock の絶対期限を受け ResultAsync を返す実行用の関数リテラルにする。
Effect の callable な型へ `unique symbol` の brand を加える。
Effect の brand は、`deferEffect` の実装内だけで構築する。
TypeScript compiler API による AST 構造検査で、brand の値参照と Effect への type assertion を `deferEffect` の実装内へ限定する。
公開 Effect factory の parameter から、default parameter と destructuring の binding initializer を除く。
全ての公開 Effect factory から、その関数リテラルを共通の `deferEffect` へ渡す。
TypeScript compiler API による AST 構造検査で、全ての公開 Effect factory に parameter initializer が無く、本体が副作用を実行せず `deferEffect` へ委譲することを検査する。
実行テストでは `deferEffect` 自体を構築し、返した Effect の呼出前は副作用が0件で、呼出後にだけ開始することを確認する。
Effect は、イベント境界で呼ぶ。

### 例
生の `Promise` は生成と同時に実行が始まる。

```typescript
const user = fetchUser(id);
```

公開 factory は、実行用の関数リテラルを共通 constructor へ渡す。

```typescript
const effectBrand: unique symbol = Symbol("Effect");
type Effect<Env, E, A> = {
  (env: Env, signal: AbortSignal, deadlineAt: number): ResultAsync<A, E>;
  readonly [effectBrand]: true;
};
const deferEffect = <Env, E, A>(
  run: (env: Env, signal: AbortSignal, deadlineAt: number) => ResultAsync<A, E>,
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

## 想定内失敗を Result で返す

### 要求
想定された失敗は neverthrow の Result・ResultAsync で返し、error は判別子つきの union で分類する。

### 根拠
想定された失敗を Result にすれば、失敗が型に現れ、呼び出し側が扱いを強制される。
error を判別子つきの union にすれば、失敗の種別を網羅で扱える。

### 完了条件
想定された失敗が、Result・ResultAsync で返されている。
error が、判別子つきの union で分類されている。

### 禁止事項
想定された失敗を、throw で表すこと。
error を、種別の判別できない単一の型で表すこと。

### 行動
想定された失敗を Result・ResultAsync にし、error を判別子つきの union で分類する。

### 例
想定内失敗を throw すると型に現れず、呼び出し側の捕捉も強制されない。

```typescript
async function find(id: Id): Promise<User> { throw new Error("not found"); }
```

`Result` で返し、error を判別子つき union で分類する。

```typescript
type FindError = { kind: "notFound" } | { kind: "unavailable" };
function find(id: Id): ResultAsync<User, FindError> { /* ... */ }
```

## 非同期 API の送出を ResultAsync へ変換する

### 要求
Promise を返し、Promise を返す前にも同期で throw し得る API は、呼出式を関数リテラルに入れて `ResultAsync.fromThrowable` で受ける。
`ResultAsync.fromThrowable` が返す関数を呼び、同期の throw と Promise の rejection を同じ一箇所で変換する。
想定された失敗だけを error mapper で判別子つきの error へ写し、回復できない欠陥は再 throw する。
取り消しの AbortError は error へ写さず再 throw し、境界の殻が取り消しとして扱う。

### 根拠
`ResultAsync.fromPromise(operation(), mapper)` は `operation()` を先に評価するため、Promise を返す前の同期の throw を捕捉しない。
`ResultAsync.fromThrowable` は関数の呼出しを内側で行い、同期の throw と返された Promise の rejection の両方を ResultAsync の error mapper へ渡す。
想定された失敗だけを error にすれば、欠陥と取り消しを業務上の失敗として回復しない。

### 完了条件
Promise を返す境界 API の呼出式が、`ResultAsync.fromThrowable` に渡す関数リテラルの内側にある。
同期の throw と Promise の rejection が、同じ error mapper で想定された失敗へ変換されている。
`ResultAsync.fromThrowable` が返した関数が呼ばれ、ResultAsync が返されている。
回復できない欠陥と AbortError が、ResultAsync の error に混ざらず再 throw されている。

### 禁止事項
同期で throw し得る関数の呼出結果を、`ResultAsync.fromPromise` の第一引数へ直接渡すこと。
`ResultAsync.fromThrowable` が返す関数を呼ばず、関数自体を ResultAsync とみなすこと。
回復できない欠陥または AbortError を、想定された失敗の error へ変換すること。

### 行動
Promise を返す API 呼出しを、`ResultAsync.fromThrowable(() => operation(), mapper)()` の形で ResultAsync へ変換する。
mapper は想定された失敗だけを変換し、欠陥と AbortError を再 throw する。

### 例
呼出式を `ResultAsync.fromPromise` の引数に直接置くと、同期の throw が変換境界を抜ける。

```typescript
const unsafe = ResultAsync.fromPromise(operation(), mapper);
```

error mapper は想定内失敗だけを変換する。

```typescript
const toRequestError = (error: unknown): RequestError => {
  if (error instanceof DOMException && error.name === "AbortError") throw error;
  if (error instanceof TransportUnavailable) {
    return { kind: "transportUnavailable", cause: error };
  }
  throw error;
};
```

関数リテラルの呼出しと `Promise` の完了を同じ境界で受ける。

```typescript
const result = await ResultAsync.fromThrowable(
  () => operation(),
  toRequestError,
)();
```

## 同期 API の送出を Result へ変換する

### 要求
同期で完了し throw し得る DOM API と postMessage は、呼出式を関数リテラルに入れて `Result.fromThrowable` で受ける。
想定された失敗だけを error mapper で判別子つきの error へ写し、回復できない欠陥は再 throw する。

### 根拠
同期 API は Promise を返さないので、ResultAsync で非同期の形へ変える必要がない。
`Result.fromThrowable` が返す関数を呼べば、同期の戻り値と throw を Result の二経路へ変換できる。
同期と非同期の境界を分けると、戻り値の実体と検査する送出経路が一致する。

### 完了条件
throw し得る同期 DOM API と postMessage の呼出式が、`Result.fromThrowable` に渡す関数リテラルの内側にある。
`Result.fromThrowable` が返した関数が呼ばれ、Result が返されている。
想定された失敗だけが Result の error へ変換され、回復できない欠陥が再 throw されている。

### 禁止事項
同期 DOM API または postMessage を、`ResultAsync.fromPromise` で受けること。
同期 API を Promise で包み、同期の throw の変換を非同期境界へ先送りすること。
回復できない欠陥を、想定された失敗の error へ変換すること。

### 行動
同期 API 呼出しを、`Result.fromThrowable(() => operation(), mapper)()` の形で Result へ変換する。
DOM API と postMessage の mapper は想定された DOMException だけを変換し、それ以外を再 throw する。

### 例
```typescript
const element = Result.fromThrowable(
  () => document.querySelector(selector),
  toSelectorError,
)();

const posted = Result.fromThrowable(
  () => targetWindow.postMessage(message, targetOrigin),
  toPostMessageError,
)();
```

## 依存を環境で受け、host の能力を port で宣言する

### 要求
効果が要求する依存は環境で受け取り、module の最上位に可変な singleton を作らない。
host に求める能力は ui port の型で宣言し、実装は host の composition が注入する。
本番とテストで、環境の実装を差し替える。

### 根拠
依存を環境で受ければ、計算が要求する能力が型に出て、組立点だけが具象を知る。
module の最上位の可変な singleton は、隠れた共有状態になり、差し替えとテストを阻む。
host の能力を ui port の型で宣言すれば、実装に縛られず host の composition が差し込める。
本番とテストで環境を差し替えると、host の能力をテストで制御できる。

### 完了条件
効果が要求する依存が、環境で受け取られている。
module の最上位に、可変な singleton がない。
host に求める能力が ui port の型で宣言され、host の composition が注入している。

### 禁止事項
module の最上位に、可変な singleton を作ること。
業務の核で、依存を直接生成すること。

### 行動
依存を環境で受け、host の能力を ui port の型で宣言し、host の composition が注入する。
本番とテストで、環境の実装を差し替える。

### 例
モジュール最上位の可変 singleton は、隠れた共有状態になる。

```typescript
export const userGateway = new UserGateway();
```

依存を環境で受け、host の能力を ui port で宣言する。

```typescript
interface HasUsers { users: UserGateway }
interface UiPort { notify(message: Message): void }
```

## 参照
効果システムは [effect](../../concerns/effect.md)、依存の向きは [dependency](../../concerns/dependency.md) に従う。
取り消しの AbortSignal は [coordination](./coordination.md)、状態は [retention](./retention.md) に従う。
