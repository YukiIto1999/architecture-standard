# Tailwind CSS

用途は、styling を組む機構である。
採用は、TypeScript は Tailwind CSS の Vite plugin である。
design token は `@theme` に一元化し、W3C Design Tokens Community Group の draft の交換形式は、安定版でないため採用しない。
判断基準は、design token を一元化でき、CSS をビルド時に静的に出せることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## styling

### 要求
design token は entry の CSS の `@theme` に集約し、entry の CSS は `@theme` と `@import` だけにする。
styling の機構は Tailwind CSS の Vite plugin に一つ固定し、CSS をビルド時に静的に出す。
runtime に style を生成する CSS-in-JS は使わない。
スタイルはマークアップのタグ内で完結させ、component 単位の独立した CSS は標準外とする。
layout primitive は container query で組み、headless は Kobalte を使い見た目は design token で与える。
design token の交換形式の採否は、[tailwind](./tailwind.md) が定める。

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
entry の CSS は `@import` と `@theme` だけで構成し、token を `@theme` に集約する。

```css
@import "tailwindcss";
@theme { --color-brand-500: oklch(0.62 0.21 256); --breakpoint-3xl: 120rem; }
```

component ごとの CSS を作らず、class で完結させて layout に container query を使う。

```tsx
<div class="@container"><div class="grid grid-cols-1 @md:grid-cols-2">{props.children}</div></div>
```
