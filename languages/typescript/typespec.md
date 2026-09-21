# TypeSpec

用途は、UI が参照する契約の型の真実源となる契約記述である。
採用は、TypeSpec と `@typespec/openapi3` の OpenAPI を、build 時の openapi-typescript で型だけに生成することである。生成器は openapi-typescript の peer dependency に適合する TypeScript を使い、製品が採用する TypeScript と別に扱う。
判断基準は、契約から OpenAPI を出力でき、openapi-typescript の peer dependency に適合する TypeScript を生成器の toolchain に置き、openapi-typescript を製品の型検査と同じ toolchain へ混ぜず、生成した型が製品の採用する TypeScript で型検査を通ることである。
撤回条件は、生成物が製品の採用する TypeScript で型検査を通らなくなることであり、この失敗を再評価のトリガーとする。

## 契約の型を生成する

### 要求
contracts/generated の TypeScript の型は、TypeSpec から `@typespec/openapi3` で出力した OpenAPI を、openapi-typescript を build 時の生成器として使い、生成器の toolchain は openapi-typescript の peer dependency に適合する TypeScript を使い、製品が採用する TypeScript と別に分けた上で、製品が採用する TypeScript の型検査へ通す。

### 根拠
openapi-typescript は型定義だけを出力し runtime のコードを持たないので、生成型を型としてのみ使い runtime の依存を持ち込まない規律とかみ合う。
契約から型を生成すれば、UI が参照する型が契約に従う。

### 完了条件
型が、TypeSpec から `@typespec/openapi3` を経て openapi-typescript で生成され、生成器の toolchain が openapi-typescript の peer dependency に適合する TypeScript を使い、製品が採用する TypeScript と別に扱われ、生成物が製品が採用する TypeScript の型検査を通っている。

### 禁止事項
契約の型を、runtime のコードを含む生成器で作ること。
openapi-typescript の peer dependency を、製品が採用する TypeScript の型検査 toolchain に混ぜること。
openapi-typescript の peer dependency に適合しない TypeScript で生成器を動かすこと。

### 行動
TypeSpec から `@typespec/openapi3` で OpenAPI を出力し、openapi-typescript の peer dependency に適合する TypeScript を使う build 時の生成器として実行する。生成器の TypeScript を製品が採用する TypeScript と混ぜず、生成物を製品が採用する TypeScript の型検査へ通す。
