# publication

## 概要
publication は、TypeScript で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization/README.md) が定める入口での評価・[security](../../concerns/security/README.md) が定める攻撃面の最小化を、TypeScript の機構で満たす。
surface ごとの規律は、[solidjs](./solidjs.md)・[tailwind](./tailwind.md)・[opentelemetry-js](./opentelemetry-js.md)・[vite](./vite.md)・[vscode](./vscode.md)・[vscode-jsonrpc](./vscode-jsonrpc.md) が持つ。
browser の store へ置かない規律は [connection](./connection.md) が持つ。

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

## 参照
境界と依存の向きは [separation](../../principles/separation/README.md)、入口での評価は [authorization](../../concerns/authorization/README.md)、攻撃面の最小化は [security](../../concerns/security/README.md) に従う。
配置は [structure/surfaces/viewer](../../structure/surfaces/viewer/layout.md)・[structure/surfaces/extension](../../structure/surfaces/extension/layout.md)・[structure/runtimes](../../structure/runtimes/) に従う。
