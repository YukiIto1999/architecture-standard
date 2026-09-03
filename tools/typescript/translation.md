# translation

## 概要
translation は、TypeScript で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信を、TypeScript の機構で満たす。
境界での parse とエラー分類の規律は [valibot](./valibot.md) が、契約の型生成の規律は [typespec](./typespec.md) が持つ。

## 生成型を型としてのみ使い、通信を port に通す

### 要求
contracts/generated の型は型としてだけ import し、契約の package へ runtime の依存を持ち込まない。
通信は ui port を通して行う。

### 根拠
生成型を runtime の値として使うと、契約の package が実行時の依存になり、UI が契約の実装に縛られる。
型としてだけ使えば、契約は型の境界に留まる。
通信を port に通せば、UI は通信の実装から切り離される。

### 完了条件
生成型が、型としてのみ import されている。
契約の package に、runtime の依存がない。
通信が、ui port を通っている。

### 禁止事項
生成型を、runtime の値として使うこと。
契約の package へ、runtime の依存を持ち込むこと。

### 行動
生成型を `import type` で取り込み、通信は ui port を通す。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md) に従う。
