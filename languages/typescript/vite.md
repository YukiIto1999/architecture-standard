# Vite

用途は、viewer を載せる host の entry と bundler である。
採用は、Vite と @solidjs/vite-plugin である。
判断基準は、index.html を entry として扱え、採用している viewer の機構と bundler plugin の peer を同時に満たし、build の設定をテストと共有できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、採用している viewer の機構と bundler plugin の安定版の到達を再評価のトリガーとする。

## viewer を載せる host の entry と build

### 要求
entry と bundler は Vite と @solidjs/vite-plugin で組み、composition が ui port を注入し viewer を @solidjs/web の render で DOM に mount する。
desktop と mobile の host が同じ viewer の成果物を載せる場合も、同じ entry と bundler で build した成果物を使う。
viewer を載せる host の tsconfig は、`jsx` を `preserve` にし、`jsxImportSource` を `@solidjs/web` にする。

### 根拠
composition が ui port を注入し viewer を mount すれば、依存が一箇所で注入される。
Vite は index.html を entry として扱い、@solidjs/vite-plugin は SolidJS 2.0 と @solidjs/web の peer を宣言する。
SolidJS 2.0 は web の JSX runtime の型を @solidjs/web が所有するため、TypeScript の JSX 解決先を renderer package へ向ける。

### 完了条件
entry と bundler が、Vite と @solidjs/vite-plugin である。
composition が ui port を注入し、viewer が @solidjs/web の render で DOM に mount されている。
viewer を載せる host の tsconfig の `jsx` が `preserve` で、`jsxImportSource` が `@solidjs/web` になっている。

### 禁止事項
viewer を、composition の外で DOM に手で注入すること。
SolidJS 2.0 の peer を宣言しない bundler plugin で viewer を build すること。

### 行動
index.html を entry にし、Vite と @solidjs/vite-plugin で SolidJS 2.0 の TSX を build する。
viewer を載せる host の tsconfig に、`jsx: "preserve"` と `jsxImportSource: "@solidjs/web"` を設定する。
composition で ui port を注入して、@solidjs/web の render で mount する。

### 例
composition が ui port を注入し、viewer を @solidjs/web の `render` で mount する。

```tsx
import { render } from "@solidjs/web";

const ui = composeUi();
render(() => <App ui={ui} />, document.getElementById("root")!);
```

