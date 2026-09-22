# playwright-bdd

用途は、Gherkin の feature を Playwright Test のテストファイルへ変換し、UI smoke を Gherkin で書けるようにする変換器である。
採用は、TypeScript は playwright-bdd である。
判断基準は、Gherkin の記法で UI smoke を書け、変換した test の実行を [playwright](./playwright.md) の runner に委ねられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## UI smoke の Gherkin を Playwright の test へ変換する

### 要求
UI の E2E smoke は Gherkin の feature で書き、playwright-bdd で Playwright Test のテストファイルへ変換する。
変換した test は、[playwright](./playwright.md) の runner で、実装と同じ検証入口から実行する。
UI の E2E smoke と visual を、[cucumber-js](./cucumber-js.md) が実行する業務語彙の executable spec の代替として並べない。

### 根拠
UI の E2E smoke と visual は、ブラウザ越しの見た目と疎通を確かめる。
playwright-bdd は Gherkin の feature ファイルを Playwright Test のテストファイルへ変換する変換器で、実行は Playwright の runner が担う。
同じ Gherkin の記法でも、業務語彙の仕様の実行系と、UI smoke を Gherkin で書くための変換器とでは、担う目的が違う。
目的の違うものを代替として並べると、どちらの役割も果たせなくなる。

### 完了条件
UI の E2E smoke が、Gherkin の feature から playwright-bdd で変換され、Playwright の runner で実行されている。
UI の E2E smoke と visual が、業務語彙の executable spec の代替として並べられていない。

### 禁止事項
executable spec と UI の E2E smoke・visual を、代替として並べること。
変換した test を、Playwright の runner 以外で実行すること。

### 行動
UI の E2E smoke の Gherkin を playwright-bdd で変換し、Playwright の runner で実装と同じ検証入口から実行する。
業務語彙の executable spec は [cucumber-js](./cucumber-js.md) で別に書く。
