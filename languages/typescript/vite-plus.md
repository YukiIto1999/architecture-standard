# Vite+

用途は、TypeScript の build、lint、format、テストを、一つの入口と一つの設定で駆動する統合 toolchain である。
採用は、TypeScript は `vite-plus` である。
判断基準は、`vp build` が Rolldown を bundler とする Vite を、`vp check` が Oxlint と Oxfmt と tsgolint を、`vp test` が Vitest を、同梱した一組の版で駆動し、各部品の設定を `vite.config.ts` に置けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、構成部品のいずれかが Vite+ 経由で自身の判断基準を満たせなくなることを再評価のトリガーとする。

## 実行入口を一つに集約する

### 要求
TypeScript の build、dev server、lint、format、テストの実行は、Vite+ の built-in command で行う。
build は `vp build`、dev server は `vp dev`、lint と format は `vp check`、テストは `vp test` で行う。
build と dev server は [vite](./vite.md)、型情報を要さない lint は [oxlint](./oxlint.md)、型情報を要する lint は [tsgolint](./tsgolint.md)、format は [oxfmt](./oxfmt.md)、テストは [vitest](./vitest.md) の規律に従い、この file は各部品の規律を再定義しない。
compiler の型検査は [inspection](./inspection.md) の「予防」に従い、`vp check` の診断だけで代替しない。
部品の設定は、`vite.config.ts` の `lint`・`fmt`・`test` の各 block と Vite の設定に置く。
`lint` と `fmt` の block は workspace root の `vite.config.ts` に置き、package ごとの差は各 block の `overrides` で表す。
`.oxlintrc.json`・`oxlint.config.ts`・`.oxfmtrc.json`・`vitest.config.ts` を置かない。
`vite-plus` は project の devDependency に置き、版を manifest と lockfile に記録する。
検証入口と Nx の target は、project の `vite-plus` が提供する `vp` を呼び、global の `vp` CLI の導入を前提にしない。
Node.js と package manager の供給は Vite+ の責務に含めず、環境が `vite-plus` の `engines` を満たす Node.js を供給する。
`vite` と `vitest` を import または peer に持つ package が `vite-plus` の同梱版へ解決されるよう、package manager の override で `vite` を `@voidzero-dev/vite-plus-core` の alias に、`vitest` を同梱の版に固定する。
task の定義と依存順序と cache は [nx](../../tools/build/nx.md) が持ち、Nx の target の command が `vp` の built-in command を呼ぶ。
`vp run` と `vite.config.ts` の `run` block を、task の編成に使わない。

### 根拠
`vite-plus` package は、Vite と Rolldown、Vitest、Oxlint、Oxfmt、tsgolint を含み、`vp` の command から各部品を駆動する。
build は、Rolldown を bundler とする Vite が行う。
`vp check` は format と lint を一度の実行で行い、型情報を要する lint は tsgolint が担う。
設定を `vite.config.ts` に集約すれば、各部品が一つの設定を読み、部品ごとの設定 file の間で値が食い違わない。
`vite-plus` は各部品の版を exact に固定して依存するので、部品を個別に更新して版が食い違うことがない。
`vite` や `vitest` を直接 import する plugin が別の実体を解決すると、`instanceof` による判定が破れ、Vitest の mock と runner の状態が二重になる。
override は、これらを `vite-plus` の同梱版の一つの実体へ揃える。
project の `vite-plus` は、既存の Node.js と package manager を要求し、global の `vp` CLI なしで build、check、test の各 command を提供する。
`vp run` が駆動する Vite Task は、task の定義と依存順序と cache を `vite.config.ts` と package.json に持つので、使うと task の正本が Nx と二つになる。
task の正本を一つに保つ要求は、[nx](../../tools/build/nx.md) の「task の正本」に従う。
型検査と lint の診断は、依存方向と副作用の形を規則に当てる構造検査と保証が異なるので、構造検査は [typescript-compiler-api](./typescript-compiler-api.md) の別系として維持する。

### 完了条件
検証入口の lint と format が `vp check` で、build が `vp build` で、テストが `vp test` で実行されている。
`vite-plus` の版が、manifest と lockfile に記録されている。
`vite` の alias と `vitest` の固定版が、package manager の override に置かれ、`vite-plus` の同梱版と一致している。
`lint` と `fmt` の設定が workspace root の `vite.config.ts` の block に、テストと build の設定が `vite.config.ts` に限られ、部品ごとの設定 file が無い。
採用している Vite plugin の peer 宣言が、alias した `vite` に対して成立している。
`vp build` が、採用している Vite plugin を登録した状態で成果物を生成している。
Nx の target が `vp` の built-in command を呼び、`vite.config.ts` に `run` block が無い。
環境が供給する Node.js が、`vite-plus` の `engines` を満たしている。

### 禁止事項
Oxlint と Oxfmt と Vitest が担う責務に、ESLint・Prettier・Jest などの別の linter、formatter、test runner を検証入口へ置くこと。
`vp run` と `vite.config.ts` の `run` block で、task の定義と依存順序と cache を持つこと。
global の `vp` CLI と `vp env` の導入を、検証入口の前提にすること。
部品の設定を、`vite.config.ts` と別の file に二重に置くこと。
`vite` と `vitest` の解決を、`vite-plus` の同梱版と食い違わせること。
Vite+ の型検査と lint を、compiler API による構造検査の代わりにすること。
bundler plugin の peer 宣言の成立を測らずに、`vite-plus` の版を上げること。

### 行動
`vite-plus` を project の devDependency に加え、`vite` と `vitest` の override を置く。
lint と format の設定を workspace root の `vite.config.ts` の `lint`・`fmt` の各 block へ集め、テストの設定を `test` block へ置く。
Nx の target に、`vp build`・`vp check`・`vp test` などの built-in command を定める。
`vite-plus` の版を上げるときは、`vp toolchain` で同梱の版を確かめ、override と coverage provider の版を揃えて、`vp check`・compiler の型検査・`vp test`・`vp build` を通し、peer 宣言の成立を確かめる。
