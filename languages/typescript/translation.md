# translation

## 概要
translation は、TypeScript で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、TypeScript の機構で満たす。
境界での parse とエラー分類の規律は [valibot](./valibot.md) が、契約の client と型の生成の規律は [http-client-js](./http-client-js.md) が持つ。

## 生成型を型としてのみ使い、通信を port に通す

### 要求
viewer は contracts/generated の型を型としてだけ import し、生成した client を import しない。
viewer の通信は ui port を通して行う。
生成した client を使うのは、ui port を実装する host の adapters に限る。

### 根拠
viewer が生成した client を import すると、UI が通信の実装に縛られ、host ごとに別の実装へ差し替えられなくなる。
型としてだけ使えば、viewer は契約の型の境界に留まる。
通信を port に通せば、UI は通信の実装から切り離される。
生成した client の利用を host の adapters に集めれば、transport の判断が host の側に揃う。

### 完了条件
viewer で、生成型が型としてのみ import されている。
viewer が、生成した client を import していない。
viewer の通信が、ui port を通っている。
生成した client の import が、ui port を実装する host の adapters に限られている。

### 禁止事項
viewer で、生成型を runtime の値として使うこと。
viewer から、生成した client を import すること。
通信を、ui port の外で行うこと。

### 行動
viewer では生成型を `import type` で取り込み、通信は ui port を通す。
生成した client は、host の adapters が ui port の実装として使う。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md) に従う。
