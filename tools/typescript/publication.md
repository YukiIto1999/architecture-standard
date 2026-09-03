# publication

## 概要
publication は、TypeScript で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization.md) が定める入口での評価・[security](../../concerns/security.md) が定める攻撃面の最小化を、TypeScript の機構で満たす。
surface ごとの規律は、[solidjs](./solidjs.md)・[tailwind](./tailwind.md)・[opentelemetry-js](./opentelemetry-js.md)・[vite](./vite.md)・[vscode](./vscode.md)・[vscode-jsonrpc](./vscode-jsonrpc.md) が持つ。

## extension

### 要求
extension の surface は host 非依存に組み、host の能力は port で受け取る。

### 根拠
surface が host を直接呼ばず port 越しに会話すれば、host から切れて単体で動かせる。

### 完了条件
extension の surface が、host 非依存に組まれている。
host の能力が、port で受け取られている。

### 禁止事項
surface から、host の API を直接呼ぶこと。

### 行動
surface を port にだけ依存させ、host の能力を port で受ける。
adapter が host 固有を変換し、composition が注入する。

### 例
surface が host API を直接呼ぶと、host に縛られて単体で動かせない。

```typescript
import * as vscode from "vscode";
```

surface は port にだけ依存し、adapter が host の API を port に写す。

```typescript
interface FileSystemPort { read(path: string): Promise<string>; }
interface MessagingPort { notify(text: string): void; }
async function showDoc(path: string, fileSystem: FileSystemPort, messaging: MessagingPort) { messaging.notify(await fileSystem.read(path)); }
```

## 可視性

### 要求
package の公開面は exports で閉じ、exports に無い path を外から import させない。

### 根拠
exports で公開面を限定すれば、宣言した入口の外が閉じられ、内部の path への import が止まる。
ただし exports は強い隠蔽ではないので、秘匿は exports だけに頼らない。

### 完了条件
package の公開面が、exports で閉じている。
exports に無い path が、外から import されていない。

### 禁止事項
exports に無い path を、外から import すること。

### 行動
package の公開面を exports で宣言し、内部の path を外へ出さない。

### 例
公開面を `exports` で宣言し、内部 path を外へ出さない。

```jsonc
{ "exports": { ".": "./dist/index.js", "./ports": "./dist/ports/index.js" } }
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

## 参照
境界と依存の向きは [separation](../../principles/separation.md)、入口での評価は [authorization](../../concerns/authorization.md)、攻撃面の最小化は [security](../../concerns/security.md) に従う。
配置は [structure/surfaces/viewer](../../structure/surfaces/viewer/layout.md)・[structure/surfaces/extension](../../structure/surfaces/extension/layout.md)・[structure/runtimes](../../structure/runtimes/) に従う。
