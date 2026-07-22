# retention

## 概要
retention は、TypeScript で永続化と共有される状態を扱う実現軸である。
TypeScript は viewer・extension・web と ide の host の面を担い永続化を持たないので、状態を由来と面で分けて扱い、認証の秘密を保持しない。
principles の [data](../../principles/data.md) が定める真実の所在の一意さと、concerns の [security](../../concerns/security.md) が定める境界の不信を、viewer は [structure/surfaces/viewer/state](../../structure/surfaces/viewer/state.md) の4分離で、extension は host の状態 API との切り分けで満たす。

## 状態の機構

### 要求
remote の状態は createResource、URL の状態は router の params と search params、local の状態は createSignal、横断 の状態は createStore と Context で扱う。
派生の値は createMemo で表す。

### 根拠
状態は由来によって寿命と権威が違う。
remote はサーバが権威で、createResource が取得と loading と error と再取得をまとめる。
URL は遷移で共有される状態で、router が params と search params で持つ。
local はその場限りの状態で、createSignal で足りる。
横断 は複数の場所が読む状態で、createStore と Context が細かい反応性で配る。
横断は状態の由来による分類の一つであり、[structure/surfaces/viewer/layout](../../structure/surfaces/viewer/layout.md) が定める shared 層(host 非依存の primitive と ui port を置く層)とは別の概念である。
派生の値を createMemo にすれば、元の状態から一意に導かれ、二重に持たない。

### 完了条件
remote が createResource、URL が router、local が createSignal、横断 が createStore と Context で扱われている。
派生の値が、createMemo で表されている。

### 禁止事項
由来の違う状態を、同じ機構に混ぜること。

### 行動
状態を由来で4つに分け、それぞれの機構で扱い、派生は createMemo で表す。

### 例
```typescript
const [count, setCount] = createSignal(0);              // local はその場限り
const [user] = createResource(userId, fetchUser);       // remote はサーバが権威
const total = createMemo(() => items().reduce(sum, 0)); // 派生は元から導く
```

## remote の規律

### 要求
remote の状態は cache・再取得・無効化を createResource の単位で扱い、remote の値を 横断 の store へ複製しない。

### 根拠
remote の値を 横断 の store へ複製すると、再取得した値と複製がずれ、二重の真実ができる。
createResource を唯一の真実として読めば、cache と再取得と無効化が一箇所で揃う。

### 完了条件
remote の cache・再取得・無効化が、createResource の単位で扱われている。
remote の値が、横断 の store へ複製されていない。

### 禁止事項
remote の値を、横断 の store へ複製すること。

### 行動
remote は createResource を唯一の真実として読み、無効化は refetch で行う。

### 例
```typescript
// remote の値を store へ複製する。再取得とずれて二重の真実になる
const [user] = createResource(userId, fetchUser);
createEffect(() => setAppState("user", user()));

// createResource を唯一の真実として読む
const [user, { refetch }] = createResource(userId, fetchUser); // 無効化は refetch()
```

## 保存の禁止

### 要求
認証の token を localStorage・sessionStorage・メモリの store に置かない。
API の呼び出しは、session cookie と、状態を変える要求の CSRF token の専用 header だけを送る。
CSRF token は、専用 header で返すためだけに保持し、localStorage・sessionStorage に置かない。

### 根拠
localStorage・sessionStorage・メモリの store はいずれも JavaScript から読めるので、XSS で token が持ち出される。
CSRF token は応答で受け取り header で返す設計なので JavaScript から扱うが、永続の保管に置くと有効な期間が session を越えて残る。
token を信頼境界の外へ出さない理由と、CSRF の方式は [concerns/authentication](../../concerns/authentication.md) に従う。

### 完了条件
認証の token が、localStorage・sessionStorage・メモリの store に置かれていない。
API の呼び出しが、session cookie と CSRF token の専用 header だけを送っている。
CSRF token が、localStorage・sessionStorage に置かれていない。

### 禁止事項
認証の token を、localStorage・sessionStorage・メモリの store に置くこと。
CSRF token を、localStorage・sessionStorage に置くこと。

### 行動
認証の token をブラウザの store に置かず、API の呼び出しを session cookie と CSRF token の header だけにする。
token・session・CSRF の規律は [concerns/authentication](../../concerns/authentication.md) に従う。

### 例
```typescript
// token を web ストレージに置く。XSS で抜かれる
localStorage.setItem("access_token", response.accessToken);

// token をブラウザに置かない。BFF が HttpOnly の session cookie を設定する
await fetch("/bff/login", { method: "POST", credentials: "include", body });
// 以後の呼び出しは cookie を送るだけ
const [session] = createResource(() => fetch("/bff/me", { credentials: "include" }));
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
```typescript
// surface が host の Memento を直接呼ぶ。host に縛られる
context.globalState.update("draftCount", count);

// surface は port にだけ依存し、adapter が host の Memento と secret storage を使い分ける
interface StatePort { getDraftCount(): number; setDraftCount(count: number): Promise<void>; }
interface SecretPort { getToken(): Promise<string | undefined>; } // 秘密は secret storage 側の adapter
```

## 参照
真実の所在は [data](../../principles/data.md)、境界の不信は [security](../../concerns/security.md)、token を信頼境界の外へ出さない規律は [authentication](../../concerns/authentication.md)、状態の4分離は [structure/surfaces/viewer/state](../../structure/surfaces/viewer/state.md)、extension の host 非依存の境界は [publication](./publication.md) に従う。
