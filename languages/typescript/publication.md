# publication

## 概要
publication は、TypeScript で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization.md) が定める入口での評価・[security](../../concerns/security.md) が定める攻撃面の最小化を、TypeScript の機構で満たす。

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
```tsx
// props を分割代入し、反応性が切れる
function Greeting({ name }: { name: string }) { return <h1>Hello {name}</h1>; }

// composition root で provider と ui port を配り、props は直接参照する
render(() => <AuthProvider><App ui={ui} /></AuthProvider>, document.getElementById("root")!);
function Greeting(raw: { name: string; greeting?: string }) {
  const props = mergeProps({ greeting: "Hello" }, raw);
  return <h1>{props.greeting} {props.name}</h1>;
}
```

## styling

### 要求
design token は entry の CSS の `@theme` に集約し、entry の CSS は `@theme` と `@import` だけにする。
styling の機構は Tailwind CSS の Vite plugin に一つ固定し、CSS をビルド時に静的に出す。
runtime に style を生成する CSS-in-JS は使わない。
スタイルはマークアップのタグ内で完結させ、component 単位の独立した CSS は標準外とする。
layout primitive は container query で組み、headless は Kobalte を使い見た目は design token で与える。
design token の交換形式の採否は、[tools/stack](../../tools/stack.md) の styling の機構が定める。

### 根拠
design token を `@theme` に集約すれば、変わりそうな見た目の決定が一箇所に隠れる。
CSS をビルド時に静的に出し runtime CSS-in-JS を使わなければ、styling の機構が一つに定まり、実行時に style を生成する別の目的の機構が増えない。
component 単位の独立した CSS を作らずタグ内で完結させれば、技術の層でなく変更理由で分かれる。
headless を Kobalte で受け見た目を design token で与えれば、振る舞いと見た目が分かれる。
layout を container query で組めば、要素の幅で配置が決まり、画面幅に縛られない。

### 完了条件
design token が `@theme` に集約され、entry の CSS が `@theme` と `@import` だけである。
styling の機構が Tailwind の Vite plugin に一つ固定され、CSS が静的に出ている。
runtime CSS-in-JS が、使われていない。
スタイルがタグ内で完結し、component 単位の独立した CSS がない。
layout primitive が container query で組まれ、headless が Kobalte で見た目が design token である。

### 禁止事項
design token を、`@theme` の外へ散らすこと。
runtime CSS-in-JS で、style を生成すること。
component 単位の独立した CSS を作ること。
design token を、`@theme` の外の交換形式で持つこと。

### 行動
design token を `@theme` に集約し、styling の機構を Tailwind の Vite plugin に一本化して runtime CSS-in-JS を導入しない。
スタイルをタグ内で完結させ、headless を Kobalte、layout を container query で組む。

### 例
```css
/* entry の CSS は @import と @theme だけ。token を一元化する */
@import "tailwindcss";
@theme { --color-brand-500: oklch(0.62 0.21 256); --breakpoint-3xl: 120rem; }
```
```tsx
// component 別の独立 CSS を作らず、class で完結し、layout は container query
<div class="@container"><div class="grid grid-cols-1 @md:grid-cols-2">{props.children}</div></div>
```

## viewer の telemetry

### 要求
viewer の trace と構造化 event の収集は、ui port の背後に閉じる。これを OpenTelemetry JS の modular な browser 構成で満たす。
trace と event は同じ文脈で相関させ、OTLP/HTTP で collector へ送る。
SDK の登録と exporter の構成は、host の adapter が持つ。

### 根拠
収集を境界の殻で行う規律([observability](../../concerns/observability.md))に、ui port の背後の OpenTelemetry で応える。
viewer 本体が SDK に触れると、収集の機構が UI の関心へ漏れる。
API と SDK を分ける OpenTelemetry の構成は、port の型を API だけに依存させ、SDK を adapter に隔離できる。
独立した UI の event は、trace の文脈を付けた LogRecord で表すと、trace と同じ文脈で相関できる。

### 完了条件
収集の呼び出しが、ui port の型だけに依存している。
SDK の登録と exporter が、host の adapter に閉じている。
trace と event が、同じ文脈で相関して collector へ届いている。

### 禁止事項
viewer の component から、SDK や exporter を直接使うこと。
収集の失敗を、UI の操作の失敗にすること。

### 行動
telemetry の ui port を定義し、host の adapter で OpenTelemetry の SDK と exporter を構成する。
event には trace の文脈を付け、OTLP/HTTP で collector へ送る。

## web の host

### 要求
entry と bundler は Vite で組み、composition が ui port を注入し viewer を DOM に mount する。

### 根拠
composition が ui port を注入し viewer を mount すれば、依存が一箇所で注入される。
Vite は index.html を entry として扱う。

### 完了条件
entry と bundler が、Vite である。
composition が ui port を注入し、viewer が DOM に mount されている。

### 禁止事項
viewer を、composition の外で DOM に手で注入すること。

### 行動
index.html を entry にし、composition で ui port を注入して render で mount する。

### 例
```tsx
// composition が ui port を注入し、render で mount する
const ui = composeUi();
render(() => <App ui={ui} />, document.getElementById("root")!);
```

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
```typescript
// surface が host の API を直接呼ぶ。host に縛られ単体で動かせない
import * as vscode from "vscode";

// surface は port にだけ依存し、adapter が host を満たす
interface FileSystemPort { read(path: string): Promise<string>; }
interface MessagingPort { notify(text: string): void; }
async function showDoc(path: string, fileSystem: FileSystemPort, messaging: MessagingPort) { messaging.notify(await fileSystem.read(path)); }
```

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
```typescript
// 判別子つき union の schema で safeParse し、acquireVsCodeApi は1回だけ
const HostToViewSchema = v.variant("type", [v.object({ type: v.literal("render"), lines: v.number() })]);
type HostToView = v.InferOutput<typeof HostToViewSchema>;
type ViewToHost = { type: "alert"; text: string };
const vscode = acquireVsCodeApi(); // 1回だけ、instance を保持
window.addEventListener("message", (event: MessageEvent<unknown>) => {
  const result = v.safeParse(HostToViewSchema, event.data); // 型アサーションでなく safeParse を通す
  if (result.success && result.output.type === "render") render(result.output.lines);
});
```

## core への接続

### 要求
extension が接続する core のプロセスへは、外へ出すのを小さい契約だけにして接続する。これを vscode-jsonrpc で満たす。

### 根拠
メソッドを型で宣言し protocol をライブラリに委ねれば、外へ出すのは小さい契約だけになり、framing を手書きしない。

### 完了条件
core のプロセスへの接続が、vscode-jsonrpc で行われている。

### 禁止事項
JSON-RPC の framing や protocol を、自作すること。

### 行動
メソッドを RequestType・NotificationType で型宣言し、vscode-jsonrpc で接続して listen する。

### 例
```typescript
// メソッドを型で宣言し、framing は委譲する
const EchoRequest = new rpc.RequestType<{ text: string }, { echoed: string }, void>("echo");
const connection = rpc.createMessageConnection(new rpc.StreamMessageReader(stdout), new rpc.StreamMessageWriter(stdin));
connection.listen();
const response = await connection.sendRequest(EchoRequest, { text: "hi" });
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
```jsonc
// 公開面を exports で宣言し、内部の path を外へ出さない
{ "exports": { ".": "./dist/index.js", "./ports": "./dist/ports/index.js" } }
```

## 参照
境界と依存の向きは [separation](../../principles/separation.md)、入口での評価は [authorization](../../concerns/authorization.md)、攻撃面の最小化は [security](../../concerns/security.md) に従う。
配置は [structure/surfaces/viewer](../../structure/surfaces/viewer/layout.md)・[structure/surfaces/extension](../../structure/surfaces/extension/layout.md)・[structure/runtimes](../../structure/runtimes/) に従う。
