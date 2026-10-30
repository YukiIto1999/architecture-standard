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
一時の状態は createSignal の範囲に閉じ、派生値は createMemo で元の値から導く。
server が権威を持つ remote の読み口は、後続の「remote の規律」の例に従う。

```typescript
const [count, setCount] = createSignal(0);
const total = createMemo(() => items().reduce(sum, 0));
```

## remote の規律

### 要求
remote の状態は async computation の createMemo の単位で扱い、初回の未準備状態を Loading で表示する。
remote の読み口を createMemo に限り、再計算と無効化は refresh で行う。
remote の値を、local の横断 store へ複製しない。
remote の読み口の compute は、`async` でも `await` を持つ関数でもない同期の関数にする。
compute は、[ts-results-es](./ts-results-es.md) の「効果を遅延した関数で表す」が定める実行境界であり、Effect を `withDeadlineEffect` で実行した `AsyncResult` を返す。
compute は、reactive な入力の読取り、`AbortController` の生成、その abort を呼ぶ `onCleanup` の登録を、`withDeadlineEffect` の呼出式より前に行う。
`withDeadlineEffect` の親の signal は、その `AbortController` の signal だけにする。
compute は、`AsyncResult` の method へ渡す関数の中で reactive な入力を読まない。
`onCleanup` の呼出しの位置は、[coordination](./coordination.md) の「後始末」に従う。
Solid が置き換えた run の結果を捨てることを、通信の abort や後始末の完了とみなさない。

### 根拠
remote の値を local の横断 store へ複製すると、server から再取得した値と local の複製がずれる。
async computation の createMemo に remote の読み口を限れば、取得と reactive な読み出しが一箇所で揃う。
Loading は初回の未準備状態を表示し、refresh は derived read を再計算する。
`AsyncResult` は thenable なので、compute が返すと Solid は async computation として扱う。
Solid が捨てるのは置き換えた run の結果であり、その run が始めた通信の取消は含まない。
Solid は reactive な入力の読取りを compute の同期の本体で追跡する。
`AsyncResult` の method へ渡す関数は通信が settle した後に動くので、その中で読んだ入力は依存にならず、その入力を変えても compute は再実行されない。
production build は、この取りこぼしを診断しないので、構造検査と実行テストで止める。
compute を同期の関数にすれば、読取りと生成の時点を「`withDeadlineEffect` の呼出式より前」の一点で決められ、構文から判定できる。
`async` 関数や `await` を許すと、`await` の後の読取りが追跡から外れ、時点を一点で決められなくなる。
run の `AbortController` の signal だけを親にすれば、置き換えと owner の破棄の両方が、同じ signal を通って通信へ届く。
owner の破棄でも run の `onCleanup` が走るので、外の signal を足さなくても、破棄で通信が止まる。
外の signal だけを親にすると、置き換えた run の通信が止まらない。
親の signal を run の `controller.signal` の一つの形に限れば、構造検査が親の signal の由来を式の形で判定できる。
run の後始末が走る時点と、`onCleanup` を呼ぶ位置の理由は、[coordination](./coordination.md) の「後始末」に従う。
結果を捨てることは画面へ出さないことであり、通信や server の処理が終わったことを示さない。

### 完了条件
remote の取得と reactive な読み出しが、async computation の createMemo の単位で扱われている。
remote の初回の未準備状態が、Loading で表示されている。
remote の再計算と無効化が、refresh で行われている。
remote の値が、local の横断 store へ複製されていない。
remote の読み口の compute が、`async` でも `await` を持つ関数でもない同期の関数である。
compute が、reactive な入力の読取り、`AbortController` の生成、abort を呼ぶ `onCleanup` の登録を、`withDeadlineEffect` の呼出式より前に行っている。
compute が、`AsyncResult` の method へ渡す関数の中で、reactive な入力を読んでいない。
`withDeadlineEffect` の親の signal が、compute の `AbortController` の signal だけである。
compute の `onCleanup` が、その `AbortController` の abort を呼んでいる。
compute が読む reactive な入力のそれぞれを変更すると、compute が再実行され、変更後の入力で通信が始まる。
画面に出る前に置き換えられた run の通信が、置き換えの時点で abort されている。
owner の破棄で終わる run の通信が、破棄の時点で abort されている。
置き換えと owner の破棄が起こした abort が、Errored の fallback にも unhandled rejection にも現れていない。
捨てた結果が、画面に表示されていない。
UI の表示と破棄が、通信の abort と収束とは別に観測されている。

### 禁止事項
remote の値を、local の横断 store へ複製すること。
remote の読み口を、createMemo と Loading の外へ分散すること。
remote の読み口の compute を、`async` 関数にしたり `await` を置いたりすること。
`withDeadlineEffect` の呼出式の中または後で、reactive な入力を読むこと。
`AsyncResult` の method へ渡す関数の中で、reactive な入力を読むこと。
compute の `AbortController` の signal 以外を、`withDeadlineEffect` の親の signal にすること。
外の signal と run の signal を合成した signal を、`withDeadlineEffect` の親の signal にすること。
置き換えた run の結果を捨てることを、通信の abort や後始末の完了とみなすこと。

### 行動
remote の client-side の読み口を async computation の createMemo に限り、初回の未準備状態は Loading で表示する。
remote の再計算と無効化は refresh で行う。
compute を同期の関数にし、reactive な入力を局所の定数へ読み、`AbortController` を作って abort を `onCleanup` に登録してから、その signal を親にして `withDeadlineEffect` で Effect を実行し、`AsyncResult` を返す。
`AsyncResult` の method へ渡す関数では、局所の定数だけを使う。
TypeScript compiler API による AST 構造検査で、型情報により accessor を識別して compute の形を検査する。
実 browser の実行テストで、入力を変更して再実行と変更後の入力での通信の開始を確かめ、置き換えと owner の破棄による abort と、捨てた結果が表示されないことを確かめる。

### 例
remote の値を store へ複製すると、再取得した値とずれて二重の真実になる。

```typescript
createEffect(
  () => user(),
  (value) => setAppState((draft) => {
    draft.user = value;
  }),
);
```

compute の外の signal だけを親にすると、置き換えた run の通信が止まらない。
`AbortSignal.any` で外の signal と run の signal を合成した signal も、親にしない。

```typescript
const user = createMemo(() => {
  const currentUserId = userId();
  return withDeadlineEffect(env, loadUser(currentUserId), deadlinePolicy.createAt(), parentSignal, resumeSource);
});
```

`AsyncResult` の method へ渡す関数は通信が settle した後に動くので、その中で読んだ `permissions()` の変更は追跡されない。

```typescript
const user = createMemo(() => {
  const currentUserId = userId();
  const controller = new AbortController();
  onCleanup(() => controller.abort());
  return withDeadlineEffect(env, loadUser(currentUserId), deadlinePolicy.createAt(), controller.signal, resumeSource)
    .map((loaded) => ({ loaded, canEdit: permissions().includes("edit") }));
});
```

compute を `async` にして `await` を置くと、`await` の後に読んだ `permissions()` は追跡されない。

```typescript
const user = createMemo(async () => {
  const controller = new AbortController();
  onCleanup(() => controller.abort());
  const loaded = await withDeadlineEffect(env, loadUser(userId()), deadlinePolicy.createAt(), controller.signal, resumeSource);
  return { loaded, canEdit: permissions().includes("edit") };
});
```

remote の client-side の読み口を async computation の createMemo に限り、初回の未準備状態を Loading で表示する。
compute は、入力を局所の定数へ読み、run ごとの controller を作って abort を onCleanup に登録してから Effect を実行する。
`AsyncResult` の method へ渡す関数は局所の定数だけを使い、再計算には refresh を使う。

```tsx
const user = createMemo(() => {
  const currentUserId = userId();
  const canEdit = permissions().includes("edit");
  const controller = new AbortController();
  onCleanup(() => controller.abort());
  return withDeadlineEffect(env, loadUser(currentUserId), deadlinePolicy.createAt(), controller.signal, resumeSource)
    .map((loaded) => ({ loaded, canEdit }));
});
const reload = () => refresh(user);
<Loading fallback={<Spinner />}><Profile user={user()} /></Loading>;
```

