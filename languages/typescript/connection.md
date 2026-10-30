# connection

## 概要
connection は、TypeScript で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect/README.md) が定める効果システムを、viewer・extension・host の軽い役割に合わせて満たす。
効果の表現と Result の規律は [ts-results-es](./ts-results-es.md) が持つ。
[separation](../../principles/separation/README.md) の依存の向きと [dependency](../../concerns/dependency/inward-dependencies.md) の「依存を内側へ一方向に向ける」の規律に従う。
資格情報の取得、保管、限定した保持、発行・交換応答は [secrets](../../concerns/secrets/README.md) の共通契約に従う。
Web BFF frontend の token 非公開はこの軸で扱い、Chromium host の資格情報と認証付き通信の具体的な機構は [chromium](./chromium.md)、IDE host の機構は [vscode](./vscode.md) が定める。

## 依存を環境で受け、host の能力を port で宣言する

### 要求
効果が要求する依存は環境で受け取り、module の最上位に可変な singleton を作らない。
現在時刻・乱数・ネットワーク通信の host API(`Date.now()`、`Math.random()`、`crypto.getRandomValues()`、`fetch` など)は、製品の code では、port を実装する host の adapters と `withDeadlineEffect` の実装の中だけで呼ぶ。
test の file は、[inspection](./inspection.md) の「構造」が定める集合であり、この制限の対象にしない。
host API の集合は、時刻・乱数・ネットワーク通信の global API だけを持ち、[coordination](./coordination.md) の「取り消し」が定める外部 I/O と待機の symbol の集合と、同じ symbol を重ねて持たない。
Effect の本体と業務の核は、時刻・乱数・ネットワーク通信を環境の port から受ける。
host に求める能力は viewer の ui port または extension の host port の型で宣言し、実装は host の composition が注入する。
本番とテストで、環境の実装を差し替える。

### 根拠
依存を環境で受ければ、計算が要求する能力が型に出て、組立点だけが具象を知る。
module の最上位の可変な singleton は、隠れた共有状態になり、差し替えとテストを阻む。
host の能力を viewer の ui port または extension の host port の型で宣言すれば、実装に縛られず host の composition が差し込める。
本番とテストで環境を差し替えると、host の能力をテストで制御できる。
環境の型は宣言した能力しか示さないので、本体が時刻・乱数・ネットワーク通信の host API を直接呼んでも型検査は通り、環境を差し替えてもその呼出しをテストで制御できない。
呼出位置を host の adapters と期限 wrapper に限れば、本体が使う時刻・乱数・通信が環境の port の型に現れる。
global の `fetch` は host API の集合だけに入るので adapters の中でだけ呼べる。
Effect の本体が呼ぶ外部 I/O は port の method であり外部 I/O の symbol の集合だけに入り、その呼出しは、[inspection](./inspection.md) の「構造」が定める Effect の内側と期限 wrapper の実装の内側に限られる。
そのため、一つの symbol を呼べる位置は一つに決まる。
test の file は時刻の計測や乱数の固定のように host API を直接呼ぶ検証を持つので、製品の code の制限から外す。
oxlint の override は規則の option を併合せず置き換えるので、adapters・期限 wrapper・test の file の override が host API の項目だけを除いて残りの禁止項目を再掲しなければ、Web storage などの他の禁止項目が外れる。
lint は設定に列挙した property と global の参照だけを拒否するので、引数なしの `new Date()` と列挙に無い host API による迂回はレビューで確かめる。

### 完了条件
効果が要求する依存が、環境で受け取られている。
module の最上位に、可変な singleton がない。
host に求める能力が viewer の ui port または extension の host port の型で宣言され、host の composition が注入している。
製品の code の時刻・乱数・ネットワーク通信の host API の呼出しが、host の adapters と `withDeadlineEffect` の実装に限られている。
host API の集合と外部 I/O と待機の symbol の集合が、共通の symbol を持たない。
adapters・期限 wrapper・test の file の override が、host API の項目を除いた全ての禁止項目を再掲している。

### 禁止事項
module の最上位に、可変な singleton を作ること。
業務の核で、依存を直接生成すること。
製品の code で、時刻・乱数・ネットワーク通信の host API を、host の adapters と `withDeadlineEffect` の実装の外で呼ぶこと。
host API の symbol を、外部 I/O と待機の symbol の集合にも入れること。
override で、host API の項目と一緒に他の禁止項目を外すこと。

### 行動
依存を環境で受け、host の能力を viewer の ui port または extension の host port の型で宣言し、host の composition が注入する。
時刻・乱数・ネットワーク通信を環境の port で宣言し、host の adapters がその実装で host API を呼ぶ。
時刻・乱数・ネットワーク通信の host API を oxlint の no-restricted-properties と no-restricted-globals に列挙する。
host の adapters・`withDeadlineEffect` の実装・test の file の override には、host API の項目を除いた全ての禁止項目を再掲する。
本番とテストで、環境の実装を差し替える。

### 例
モジュール最上位の可変 singleton は、隠れた共有状態になる。

```typescript
export const userGateway = new UserGateway();
```

viewer の例では、依存を環境で受け、host の能力を ui port で宣言する。

```typescript
interface HasUsers { users: UserGateway }
interface UiPort { notify(message: Message): void }
```

Effect の本体が時刻を直接取得すると、環境の型に現れない依存になる。

```typescript
export const isExpired = (tokenId: TokenId): Effect<HasTokens, LoadError, boolean> =>
  deferEffect((env, signal, deadlineAt) =>
    env.tokens.find(tokenId, signal, deadlineAt).map((token) => token.expiresAt < Date.now()));
```

時刻を環境の port から受ければ、要求が型に現れ、テストで時刻を固定できる。

```typescript
interface HasClock { clock: Clock }
export const isExpired = (tokenId: TokenId): Effect<HasTokens & HasClock, LoadError, boolean> =>
  deferEffect((env, signal, deadlineAt) =>
    env.tokens.find(tokenId, signal, deadlineAt).map((token) => token.expiresAt < env.clock.now()));
```

時刻の host API は、port を実装する adapter だけが呼ぶ。

```typescript
export const systemClock: Clock = { now: () => Date.now() };
```

## Web BFF frontend に認証 token を公開しない

### 要求
Web BFF を利用する通常の Web frontend は、認証の token を受け取らず、localStorage、sessionStorage、IndexedDB、メモリの store に置かない。
Web BFF への API の呼び出しは、ブラウザが送る session cookie と、状態を変える要求の CSRF token の専用 header を認証と CSRF の経路にする。
CSRF token は、専用 header で返すためだけに保持し、localStorage、sessionStorage、IndexedDB に置かない。
資格情報の取得と認証付き通信を所有する別の host の adapter には、この Web frontend 向けの token 非公開を一律に適用せず、[secrets](../../concerns/secrets/README.md) の保管と保持の契約、および host ごとの機構を適用する。

### 根拠
Web frontend が JavaScript から読める token を持つと、XSS によって token を持ち出される経路が生まれる。
CSRF token は応答で受け取り header で返す設計なので JavaScript から扱うが、Web storage へ複製すると session の更新と失効に伴う破棄を一つの所有者に閉じられない。
Web BFF が token をブラウザへ公開しない理由と、CSRF の方式は [structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う。
Web BFF frontend と資格情報の consumer である host の adapter は責務が異なり、適用範囲を分けることは平文の永続保管や UI への token 公開を許可することではない。

### 完了条件
Web BFF frontend が認証の token を受け取らず、localStorage、sessionStorage、IndexedDB、メモリの store に置いていない。
Web BFF への API の呼び出しが、session cookie と CSRF token の専用 header を定めた認証と CSRF の経路として使っている。
CSRF token が、localStorage、sessionStorage、IndexedDB に置かれず、session の再生成と失効で古い値を破棄されている。
別の host が資格情報を扱う場合は、値を使う adapter と保持期間が明示され、機密でない設定、一般状態、viewer、host 非依存の extension へ値が渡っていない。

### 禁止事項
Web BFF frontend へ認証の token を渡し、JavaScript から読める store に置くこと。
CSRF token を、localStorage、sessionStorage、IndexedDB に置くこと。
Web BFF frontend 以外であることを理由に、資格情報の平文の永続保管や、一般状態と UI への公開を許可すること。

### 行動
Web BFF frontend の認証を session cookie に閉じ、状態を変える API の呼び出しでは CSRF token の専用 header を使う。
Web BFF の token、session、CSRF の規律は [structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) に従う。
別の host の資格情報 consumer は、host の composition が注入する adapter として分け、Chromium の実現は [chromium](./chromium.md)、IDE の実現は [vscode](./vscode.md) が定める。

### 例
Web BFF frontend へ token を返して web storage に置くと、XSS から読み取れる。

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
      ).then((received) => received.mapErr((error) => toLoginError(signal, error))),
    ));
```

期限 wrapper は、UI の event handler として JSX の `on` 属性に渡す関数の内側で実行する。

```tsx
<form
  onSubmit={async () => {
    const loginResult = await withDeadlineEffect(
      env,
      submitLogin(body),
      deadlinePolicy.createAt(),
      parentSignal,
      resumeSource,
    );
    if (loginResult.isErr()) showLoginError(loginResult.error);
  }}
/>;
```

以後の remote 読み出しは、await を持たない同期の compute で run ごとの signal を作り、Effect を期限 wrapper から実行する。
入力の読取りと取消の結び方は、[solidjs](./solidjs.md) の「remote の規律」に従う。

```typescript
const session = createMemo(() => {
  const controller = new AbortController();
  onCleanup(() => controller.abort());
  return withDeadlineEffect(
    env,
    loadSession(),
    deadlinePolicy.createAt(),
    controller.signal,
    resumeSource,
  );
});
```

## 生成型を型としてのみ使い、通信を port に通す

### 要求
viewer と extension は contracts/generated の型を型としてだけ import し、生成した client を import しない。
viewer の通信は ui port、extension の通信は host port を通して行う。
生成した client を使うのは、viewer の ui port または extension の host port を実装する host の adapters に限る。

### 根拠
viewer や extension が生成した client を import すると、surface が通信の実装に縛られ、host ごとに別の実装へ差し替えられなくなる。
型としてだけ使えば、surface は契約の型の境界に留まる。
通信を port に通せば、surface は通信の実装から切り離される。
生成した client の利用を host の adapters に集めれば、transport の判断が host の側に揃う。

### 完了条件
viewer と extension で、生成型が型としてのみ import されている。
viewer と extension が、生成した client を import していない。
viewer の通信が ui port を、extension の通信が host port を通っている。
生成した client の import が、viewer の ui port または extension の host port を実装する host の adapters に限られている。

### 禁止事項
viewer と extension で、生成型を runtime の値として使うこと。
viewer と extension から、生成した client を import すること。
surface の通信を、対応する port の外で行うこと。

### 行動
viewer と extension では生成型を `import type` で取り込み、通信はそれぞれ ui port と host port を通す。
生成した client は、host の adapters が viewer の ui port または extension の host port の実装として使う。

## 参照
効果システムは [effect](../../concerns/effect/README.md)、依存の向きは [dependency](../../concerns/dependency/README.md) に従う。
取り消しの AbortSignal は [coordination](./coordination.md)、状態は [solidjs](./solidjs.md) に従う。
資格情報の保管と保持は [secrets](../../concerns/secrets/README.md) に従い、host ごとの機構は [chromium](./chromium.md) と [vscode](./vscode.md) が定める。
