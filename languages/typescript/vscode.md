# VSCode

用途は、extension の surface を動かす ide の host である。
採用は、VSCode である。
判断基準は、host の能力を port の adapter で満たせ、webview で viewer をホストできることである。
撤回条件は、判断基準を満たさなくなることであり、市場と拡張 API の変化を再評価のトリガーとする。

## ide の host

### 要求
ide の host は VSCode とし、adapters が extension の host port を VSCode の API で実装する。
UI は webview で viewer をホストし ui port を注入する。
acquireVsCodeApi は1回だけ呼び1つの instance を保持し、webview との通信は判別子つきの union で型付けた postMessage で行う。
postMessage の受信は translation の parse を通し、型アサーションで信じない。

### 根拠
adapters が host port を VSCode の API で実装すれば、surface は VSCode に縛られない。
webview で viewer をホストし ui port を注入すれば、UI が host から切れる。
acquireVsCodeApi は session に1回だけなので、1つの instance を保持して配る。
postMessage を判別子つきの union で型付ければ、境界の外の値を型へ通せる。
型アサーションは検証を経ない値を型として信じることになるので、safeParse を通し translation と同じ境界の不信を postMessage にも適用する。

### 完了条件
ide の host が VSCode で、adapters が host port を VSCode の API で実装している。
UI が webview で viewer をホストし、ui port が注入されている。
acquireVsCodeApi が1回だけ呼ばれ、1つの instance が保持されている。
webview の通信が、判別子つきの union で型付けられている。
postMessage の受信が、型アサーションでなく safeParse を通している。

### 禁止事項
acquireVsCodeApi を、複数回呼ぶこと。
webview の通信を、型のない postMessage で行うこと。
postMessage の受信を、型アサーションで型付けること。

### 行動
adapters で host port を VSCode の API で実装し、webview で viewer をホストする。
acquireVsCodeApi を1回だけ呼び instance を保持し、postMessage を判別子つきの union の schema で safeParse する。

### 例
判別子つき union の schema で `safeParse` し、`acquireVsCodeApi` が返す instance を一つ保持する。

```typescript
const HostToViewSchema = v.variant("type", [v.object({ type: v.literal("render"), lines: v.number() })]);
type HostToView = v.InferOutput<typeof HostToViewSchema>;
type ViewToHost = { type: "alert"; text: string };
const vscode = acquireVsCodeApi();
window.addEventListener("message", (event: MessageEvent<unknown>) => {
  const result = v.safeParse(HostToViewSchema, event.data);
  if (result.success && result.output.type === "render") render(result.output.lines);
});
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
