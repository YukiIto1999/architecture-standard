# Vite

用途は、web の host の entry と bundler である。
採用は、Vite である。
判断基準は、index.html を entry として扱え、build の設定をテストと共有できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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
composition が ui port を注入し、viewer を `render` で mount する。

```tsx
const ui = composeUi();
render(() => <App ui={ui} />, document.getElementById("root")!);
```
