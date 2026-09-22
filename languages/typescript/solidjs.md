# SolidJS

用途は、GUI の surface を組む骨格である。
採用は、SolidJS 2.0 系、@solidjs/web、@solidjs/vite-plugin である。
判断基準は、viewer、bundler plugin、UI component の peer 宣言が同時に成立する一組へ版を固定でき、composition root から provider と ui port を注入する形で組めることである。
撤回条件は、判断基準を満たさなくなることであり、SolidJS、@solidjs/web、@solidjs/vite-plugin、UI component の各安定版の到達を再評価のトリガーとする。

## viewer

### 要求
viewer は SolidJS で組み、app が composition root として provider と ui port を配る。
props は分割代入せず、既定値の合成は merge、取り出しは omit で扱う。

### 根拠
app が composition root として provider と ui port を配れば、依存が一箇所で注入される。
SolidJS 2.0 の merge と omit は props の reactive な読み口を保ったまま、既定値の合成と props の取り出しを行う。

### 完了条件
viewer が SolidJS で組まれ、app が composition root として provider と ui port を配っている。
props が、分割代入されていない。
props の既定値の合成と取り出しが、merge と omit で扱われている。

### 禁止事項
props を分割代入して、反応性を切ること。
props の既定値の合成または取り出しを、merge と omit 以外の独自処理で行うこと。

### 行動
app を composition root にし、provider と ui port を配る。
props は merge で既定値を合成し、omit で取り出す。

### 例
props を分割代入すると反応性が切れる。

```tsx
function Greeting({ name }: { name: string }) { return <h1>Hello {name}</h1>; }
```

composition root が provider と ui port を配り、component は merge と omit で props を扱う。

```tsx
import { render } from "@solidjs/web";
import { merge, omit } from "solid-js";

render(() => <AuthProvider><App ui={ui} /></AuthProvider>, document.getElementById("root")!);
function Greeting(raw: { name: string; greeting?: string; class?: string }) {
  const props = merge({ greeting: "Hello" }, raw);
  const content = omit(props, "class");
  return <section class={props.class}><h1>{content.greeting} {content.name}</h1></section>;
}
```

## 状態の機構

### 要求
状態の分類は、[structure/surfaces/viewer/state](../../structure/surfaces/viewer/state.md) の「権威と寿命による分離」に従う。
remote の状態は、async computation の createMemo と Loading で扱う。
URL の状態は、router の params と search params で扱う。
横断の状態は、createStore と Context で扱う。
一時の状態は、createSignal で扱う。
派生の値は createMemo で表し、第2引数は options として扱う。
書込可能な派生の値は、関数形式の createSignal で表す。

### 根拠
remote は server が権威で、async computation が取得し、Loading が初回の未準備状態を表示する。
URL の状態は、router が params と search params で持つ。
横断の状態は、createStore と Context が細かい反応性で配る。
一時の状態は一つの component に閉じるので、createSignal で足りる。
派生の値を createMemo にすれば、元の状態から一意に導かれ、二重に持たない。

### 完了条件
状態の分類が、structure の「権威と寿命による分離」に従っている。
remote が、async computation の createMemo と Loading で扱われている。
URL が、router で扱われている。
横断が、createStore と Context で扱われている。
一時が、createSignal で扱われている。
派生の値が、createMemo で表され、第2引数が options として扱われている。
書込可能な派生の値が、関数形式の createSignal で表されている。

### 禁止事項
structure の分類と異なる分け方で、状態を分類すること。
createMemo の第2引数へ、派生値の初期値を渡すこと。

### 行動
状態を structure の「権威と寿命による分離」に従って分類する。
remote は async computation の createMemo と Loading、URL は router、横断は createStore と Context、一時は createSignal で扱う。
派生は createMemo で表し、書込可能な派生は関数形式の createSignal で表す。

### 例
一時の状態は createSignal の範囲に閉じ、server が権威を持つ remote は async computation の createMemo と Loading で扱う。派生値は createMemo で元の値から導く。

```typescript
const [count, setCount] = createSignal(0);
const user = createMemo(() => loadUser(userId()));
const total = createMemo(() => items().reduce(sum, 0));
<Loading fallback={<Spinner />}><Profile user={user()} /></Loading>;
```

## remote の規律

### 要求
remote の状態は async computation の createMemo の単位で扱い、初回の未準備状態を Loading で表示する。
remote の読み口を createMemo に限り、再計算と無効化は refresh で行う。
remote の値を、local の横断 store へ複製しない。

### 根拠
remote の値を local の横断 store へ複製すると、server から再取得した値と local の複製がずれる。
async computation の createMemo に remote の読み口を限れば、取得と reactive な読み出しが一箇所で揃う。
Loading は初回の未準備状態を表示し、refresh は derived read を再計算する。

### 完了条件
remote の取得と reactive な読み出しが、async computation の createMemo の単位で扱われている。
remote の初回の未準備状態が、Loading で表示されている。
remote の再計算と無効化が、refresh で行われている。
remote の値が、local の横断 store へ複製されていない。

### 禁止事項
remote の値を、local の横断 store へ複製すること。
remote の読み口を、createMemo と Loading の外へ分散すること。

### 行動
remote の client-side の読み口を async computation の createMemo に限り、初回の未準備状態は Loading で表示する。
remote の再計算と無効化は refresh で行う。

### 例
remote の値を store へ複製すると、再取得した値とずれて二重の真実になる。

```typescript
const user = createMemo(() => loadUser(userId()));
createEffect(() => setAppState("user", user()));
```

remote の client-side の読み口を async computation の createMemo に限り、初回の未準備状態を Loading で表示する。再計算には refresh を使う。

```tsx
const user = createMemo(() => loadUser(userId()));
const reload = () => refresh(user);
<Loading fallback={<Spinner />}><Profile user={user()} /></Loading>;
```

