# translation

## 概要
translation は、TypeScript で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、TypeScript の機構で満たす。
境界での parse とエラー分類の規律は [valibot](./valibot.md) が、契約の client と型の生成の規律は [http-client-js](./http-client-js.md) が持つ。
生成した型と client の使い分けの規律は [connection](./connection.md) が持つ。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md) に従う。
