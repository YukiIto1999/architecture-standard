# connection

## 概要
connection は、TypeScript で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect/README.md) が定める効果システムを、viewer・extension・host の軽い役割に合わせて満たす。
効果の表現と Result の規律は [ts-results-es](./ts-results-es.md) が持つ。
[separation](../../principles/separation/README.md) の依存の向きと [dependency](../../concerns/dependency/inward-dependencies.md) の「依存を内側へ一方向に向ける」の規律に従う。

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
    new AsyncResult(
      Result.wrapAsync<LoginResponse, unknown>(
        () => env.bff.login(body, signal, deadlineAt),
      ).then((received) => received.mapErr(toLoginError)),
    ));
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
const session = createMemo(() =>
  withDeadlineEffect(
    env,
    loadSession(),
    deadlinePolicy.createAt(),
    parentSignal,
    resumeSource,
  ));
```

## 生成型を型としてのみ使い、通信を port に通す

### 要求
viewer は contracts/generated の型を型としてだけ import し、生成した client を import しない。
viewer の通信は ui port を通して行う。
生成した client を使うのは、ui port を実装する host の adapters に限る。

### 根拠
viewer が生成した client を import すると、UI が通信の実装に縛られ、host ごとに別の実装へ差し替えられなくなる。
型としてだけ使えば、viewer は契約の型の境界に留まる。
通信を port に通せば、UI は通信の実装から切り離される。
生成した client の利用を host の adapters に集めれば、transport の判断が host の側に揃う。

### 完了条件
viewer で、生成型が型としてのみ import されている。
viewer が、生成した client を import していない。
viewer の通信が、ui port を通っている。
生成した client の import が、ui port を実装する host の adapters に限られている。

### 禁止事項
viewer で、生成型を runtime の値として使うこと。
viewer から、生成した client を import すること。
通信を、ui port の外で行うこと。

### 行動
viewer では生成型を `import type` で取り込み、通信は ui port を通す。
生成した client は、host の adapters が ui port の実装として使う。

## 参照
効果システムは [effect](../../concerns/effect/README.md)、依存の向きは [dependency](../../concerns/dependency/README.md) に従う。
取り消しの AbortSignal は [coordination](./coordination.md)、状態は [solidjs](./solidjs.md) に従う。
