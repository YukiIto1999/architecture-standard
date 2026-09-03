# retention

## 概要
retention は、TypeScript で永続化と共有される状態を扱う実現軸である。
TypeScript は viewer・extension・web と ide の host の面を担い業務データの正本を持たないので、状態を権威の所在と local での寿命・共有範囲に分けて扱い、認証の秘密を保持しない。
principles の [data](../../principles/data.md) が定める一つの事実を一箇所に置く形と、concerns の [security](../../concerns/security.md) が定める境界の不信を、viewer は [structure/surfaces/viewer/state](../../structure/surfaces/viewer/state.md) の4分離で、extension は host の状態 API との切り分けで満たす。

## 状態の機構

### 要求
状態は、権威が server にある remote と、権威が実行中の surface または host にある local に分ける。
remote の状態は、createResource で扱う。
local の状態は寿命と共有範囲で URL、横断 UI、一時 UI に分ける。
URL の状態は、router の params と search params で扱う。
横断 UI の状態は、createStore と Context で扱う。
一時 UI の状態は、createSignal で扱う。
派生の値は createMemo で表す。

### 根拠
権威の所在を先に分けると、server が正本の値を local の正本として複製しない。
remote は server が権威で、createResource が取得、loading、error、再取得をまとめる。
URL は遷移と共有で寿命が決まり、router が params と search params で持つ。
横断 UI は複数の UI 範囲が共有し、createStore と Context が細かい反応性で配る。
一時 UI は一つの UI 範囲の寿命に閉じるので、createSignal で足りる。
横断 UI は local 状態の共有範囲による下位分類であり、[structure/surfaces/viewer/layout](../../structure/surfaces/viewer/layout.md) が定める shared 層(host 非依存の primitive と ui port を置く層)とは別の概念である。
派生の値を createMemo にすれば、元の状態から一意に導かれ、二重に持たない。

### 完了条件
状態が、権威の所在で remote と local に分かれている。
remote が、createResource で扱われている。
local が、寿命と共有範囲で URL、横断 UI、一時 UI に分かれている。
URL が、router で扱われている。
横断 UI が、createStore と Context で扱われている。
一時 UI が、createSignal で扱われている。
派生の値が、createMemo で表されている。

### 禁止事項
remote と local を、寿命だけで分類すること。
URL、横断 UI、一時 UI を、remote と並ぶ権威の分類として扱うこと。

### 行動
状態を権威の所在で remote と local に分ける。
local を寿命と共有範囲で URL、横断 UI、一時 UI に分ける。
remote は createResource、URL は router、横断 UI は createStore と Context、一時 UI は createSignal で扱う。
派生は createMemo で表す。

### 例
一時 UI は `createSignal` の範囲に閉じ、server が権威を持つ remote は `createResource` で取得する。`loadUser` は branded Effect を返す。派生値は `createMemo` で元の値から導く。

```typescript
const [count, setCount] = createSignal(0);
const [user] = createResource(userId, (id) =>
  withDeadlineEffect(
    env,
    loadUser(id),
    deadlinePolicy.createAt(),
    parentSignal,
    resumeSource,
  ));
const total = createMemo(() => items().reduce(sum, 0));
```

## remote の規律

### 要求
remote の状態は cache、再取得、無効化を createResource の単位で扱う。
remote の値を、local の横断 UI store へ複製しない。

### 根拠
remote の値を local の横断 UI store へ複製すると、server から再取得した値と local の複製がずれる。
remote の client-side の読み口を createResource に限れば、cache、再取得、無効化が一箇所で揃う。

### 完了条件
remote の cache、再取得、無効化が、createResource の単位で扱われている。
remote の値が、local の横断 UI store へ複製されていない。

### 禁止事項
remote の値を、local の横断 UI store へ複製すること。

### 行動
remote の client-side の読み口を createResource に限り、無効化は refetch で行う。

### 例

remote の値を store へ複製すると、再取得した値とずれて二重の真実になる。

```typescript
const [user] = createResource(userId, (id) =>
  withDeadlineEffect(env, loadUser(id), deadlinePolicy.createAt(), parentSignal, resumeSource));
createEffect(() => setAppState("user", user()));
```

remote の client-side の読み口を `createResource` に限り、branded Effect を期限 wrapper から実行する。無効化には `refetch` を使う。

```typescript
const [user, { refetch }] = createResource(userId, (id) =>
  withDeadlineEffect(env, loadUser(id), deadlinePolicy.createAt(), parentSignal, resumeSource));
```

## 保存の禁止

### 要求
認証の token を localStorage・sessionStorage・メモリの store に置かない。
API の呼び出しは、session cookie と、状態を変える要求の CSRF token の専用 header だけを送る。
CSRF token は、専用 header で返すためだけに保持し、localStorage・sessionStorage に置かない。

### 根拠
localStorage・sessionStorage・メモリの store はいずれも JavaScript から読めるので、XSS で token が持ち出される。
CSRF token は応答で受け取り header で返す設計なので JavaScript から扱うが、永続の保管に置くと有効な期間が session を越えて残る。
Web BFF が token をブラウザへ公開しない理由と、CSRF の方式は [structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う。

### 完了条件
認証の token が、localStorage・sessionStorage・メモリの store に置かれていない。
API の呼び出しが、session cookie と CSRF token の専用 header だけを送っている。
CSRF token が、localStorage・sessionStorage に置かれていない。

### 禁止事項
認証の token を、localStorage・sessionStorage・メモリの store に置くこと。
CSRF token を、localStorage・sessionStorage に置くこと。

### 行動
認証の token をブラウザの store に置かず、API の呼び出しを session cookie と CSRF token の header だけにする。
Web BFF の token・session・CSRF の規律は [structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う。

### 例
token を web storage に置くと、XSS から読み取れる。

```typescript
localStorage.setItem("access_token", response.accessToken);
```

通信は branded Effect に遅延し、BFF adapter が session cookie と CSRF header を扱う。

```typescript
const submitLogin = (body: LoginBody): Effect<HasBff, LoginError, Session> =>
  deferEffect((env, signal, deadlineAt) =>
    ResultAsync.fromThrowable(
      () => env.bff.login(body, signal, deadlineAt),
      toLoginError,
    )());
const loginResult = await withDeadlineEffect(
  env,
  submitLogin(body),
  deadlinePolicy.createAt(),
  parentSignal,
  resumeSource,
);
```

以後の remote 読み出しも Effect を期限 wrapper から実行する。

```typescript
const [session] = createResource(() =>
  withDeadlineEffect(
    env,
    loadSession(),
    deadlinePolicy.createAt(),
    parentSignal,
    resumeSource,
  ));
```

## extension の保持状態

### 要求
extension の状態は、秘密を含まない値に限り host の Memento(globalState・workspaceState)に置く。
秘密は host の secret storage に委ね、Memento に置かない。
surface は状態を state port で受け取り、host の状態 API を直接呼ばない。

### 根拠
Memento は host の実装で永続化されるが平文で保存されるので、秘密を置くと漏れる。
host の secret storage は暗号化して保持するので、秘密の置き場はそちらに限る。
surface が host の状態 API を直接呼ぶと、publication が定める host 非依存の境界が崩れる。

### 完了条件
extension の状態が、秘密を含まない値に限り host の Memento に置かれている。
秘密が、host の secret storage に置かれ Memento に無い。
surface が、状態を state port で受け取り host の状態 API を直接呼んでいない。

### 禁止事項
秘密を、host の Memento に置くこと。
surface から、host の状態 API を直接呼ぶこと。

### 行動
状態を秘密と非秘密に分け、非秘密は state port 経由で host の Memento に、秘密は host の secret storage に置く。
adapter が host 固有の Memento・secret storage の API を実装し、surface は port にだけ依存する。

### 例
surface が host の Memento を直接呼ぶと、host に縛られる。

```typescript
context.globalState.update("draftCount", count);
```

surface は port にだけ依存し、adapter が host の Memento と secret storage を使い分ける。

```typescript
interface StatePort { getDraftCount(): number; setDraftCount(count: number): Promise<void>; }
interface SecretPort { getToken(): Promise<string | undefined>; }
```

## 参照
一つの事実を一箇所に置く形は [data](../../principles/data.md)、境界の不信は [security](../../concerns/security.md)、Web BFF が token をブラウザへ公開しない規律は [structure/surfaces/server/layout](../../structure/surfaces/server/layout.md)、状態の4分離は [structure/surfaces/viewer/state](../../structure/surfaces/viewer/state.md)、extension の host 非依存の境界は [publication](./publication.md) に従う。
