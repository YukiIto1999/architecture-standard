# SolidJS

用途は、GUI の surface を組む骨格である。
採用は、SolidJS である。
判断基準は、composition root から provider と ui port を注入する形で組め、被ホストの surface として host から切り離せることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## viewer

### 要求
viewer は SolidJS で組み、app が composition root として provider と ui port を配る。
props は分割代入せず、既定は mergeProps、分割は splitProps で扱う。

### 根拠
app が composition root として provider と ui port を配れば、依存が一箇所で注入される。
SolidJS の props を分割代入すると反応性が切れるので、mergeProps と splitProps で扱う。

### 完了条件
viewer が SolidJS で組まれ、app が composition root として provider と ui port を配っている。
props が、分割代入されていない。

### 禁止事項
props を分割代入して、反応性を切ること。

### 行動
app を composition root にし、provider と ui port を配る。
props は mergeProps・splitProps で扱う。

### 例
props を分割代入すると反応性が切れる。

```tsx
function Greeting({ name }: { name: string }) { return <h1>Hello {name}</h1>; }
```

composition root が provider と ui port を配り、component は props を直接参照する。

```tsx
render(() => <AuthProvider><App ui={ui} /></AuthProvider>, document.getElementById("root")!);
function Greeting(raw: { name: string; greeting?: string }) {
  const props = mergeProps({ greeting: "Hello" }, raw);
  return <h1>{props.greeting} {props.name}</h1>;
}
```

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
