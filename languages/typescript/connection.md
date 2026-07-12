# connection

## 概要
connection は、TypeScript で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect.md) が定める効果システムを、viewer・extension・host の軽い役割に合わせて満たす。
副作用は、環境と AbortSignal を受け ResultAsync を返す遅延した関数で表す。
[separation](../../principles/separation.md) の依存の向きと [dependency](../../concerns/dependency.md) の単方向性に従う。

## 効果を遅延した関数で表す

### 要求
副作用を伴う計算は、環境と AbortSignal を受け取り ResultAsync を返す遅延した関数で表す。
生成では実行せず、UI のイベント境界でだけ呼ぶ。
純粋な view の計算は、この関数で包まず純粋なままにする。

### 根拠
関数は呼ぶまで動かない遅延した値なので、合成し、取り消し、差し替えても、その時点では副作用が起きない。
環境を引数に受けると、計算が要求する能力が型に出て、テストで差し替えられる。
AbortSignal を通すと、取り消しを計算全体へ伝播できる。
実行を UI のイベント境界に集めると、どこで副作用が起きるかが一箇所で読める。
viewer・extension・host は server の効果と永続化を持たないので、重い効果型を作らず、この軽い形で足りる。

### 完了条件
副作用を伴う計算が、環境と AbortSignal を受け ResultAsync を返す遅延した関数になっている。
実行が、UI のイベント境界に集まっている。
純粋な view の計算が、効果の関数で包まれていない。

### 禁止事項
生成と同時に副作用を起動すること。
viewer・extension・host に、server 側の重い効果型を持ち込むこと。

### 行動
副作用を、環境と AbortSignal を受け ResultAsync を返す関数で表し、イベント境界で呼ぶ。

### 例
```typescript
// Promise は生成で即実行され、合成も取り消しもしにくい
const user = fetchUser(id);           // すぐ走る

// 遅延した効果。環境と signal を受け、ResultAsync を返す。実行は境界で
type Effect<Env, E, A> = (env: Env, signal: AbortSignal) => ResultAsync<A, E>;
const loadUser = (userId: UserId): Effect<HasUsers, LoadError, User> => (env, signal) => env.users.find(userId, signal);
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
```typescript
// 失敗を throw で表す。型に現れず、捕捉の漏れが起きる
async function find(id: Id): Promise<User> { throw new Error("not found"); }

// Result で返し、error を判別子つき union で分類する
type FindError = { kind: "notFound" } | { kind: "unavailable" };
function find(id: Id): ResultAsync<User, FindError> { /* ... */ }
```

## throw を欠陥として境界で分ける

### 要求
fetch・DOM・postMessage など throw を前提とする API は、`ResultAsync.fromPromise` で受けて Result へ変換する。
想定された失敗は Result に、回復できない欠陥は throw のまま残し、両者を混ぜない。
取り消し(AbortError)は想定内の失敗の型へ写さず、`errorFn` で識別して再 throw し、境界の殻が取り消しとして扱う。
変換の境界は薄く保ち、呼び出しの近くの一箇所に置く。

### 根拠
throw を前提とする API をそのまま使うと、失敗が型に現れず、捕捉の漏れが起きる。
`ResultAsync.fromPromise` の `errorFn` で境界に一度だけ通せば、以後は失敗が型で扱える。
回復できない欠陥は Result に混ぜず throw のまま残すと、想定された失敗と取り違えない。
AbortError は取り消しであって想定内の失敗でも回復不能な欠陥でもないので、Result の err に落とすと [effect](../../concerns/effect.md) が定める取り消しの終了と区別がつかなくなる。
`errorFn` で AbortError を検出して再 throw すれば、呼び出し元の catch や境界の殻が取り消しとして扱える。
変換の境界を薄く呼び出しの近くに置けば、変換の責務が一箇所に集まる。

### 完了条件
throw を前提とする API の想定された失敗が、Result へ変換されている。
回復できない欠陥が、Result に混ざらず throw のまま残っている。
AbortError が、Result の err へ変換されず、`errorFn` で再 throw されている。
変換の境界が薄く、呼び出しの近くの一箇所に置かれている。

### 禁止事項
回復できない欠陥を、想定された失敗の Result に混ぜること。
AbortError を、想定された失敗の Result の err に変換すること。
変換の境界を、各所に散らすこと。

### 行動
fetch・DOM・postMessage を `ResultAsync.fromPromise` で受け、想定された失敗を Result へ変換し、欠陥は throw のまま残す。
`errorFn` で AbortError を識別し、Result の err にせず再 throw する。

### 例
```typescript
// fetch の throw をそのまま素通しする
const response = await fetch(url);

// AbortError も他の失敗と同じく err へ落としてしまう
const naive = await ResultAsync.fromPromise(fetch(url, { signal }), (error) => ({ kind: "fetchFailed" as const, error }));

// errorFn で AbortError を識別し、Result の err にせず再 throw する。境界の殻が取り消しとして扱う
const toFetchError = (error: unknown): FetchError => {
  if (error instanceof DOMException && error.name === "AbortError") throw error; // 取り消しは Result に落とさない
  return { kind: "fetchFailed", error };
};
const result = await ResultAsync.fromPromise(fetch(url, { signal }), toFetchError);
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
```typescript
// module 最上位の可変 singleton と、核での生成
export const userGateway = new UserGateway();

// 環境で受け、host の能力は ui port で宣言する
interface HasUsers { users: UserGateway }
interface UiPort { notify(message: Message): void } // 実装は host の composition が注入
```

## 参照
効果システムは [effect](../../concerns/effect.md)、依存の向きは [dependency](../../concerns/dependency.md) に従う。
取り消しの AbortSignal は [coordination](./coordination.md)、状態は [retention](./retention.md) に従う。
