# privacy

## 概要
privacy は、個人情報の最小化と期限による消去を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める事実の保持と削除の判断を、個人情報を含む記録の扱いとして具象化する。
個人情報を含む記録は、載せる項目の絞り込みと保持の期限を備え、消去の義務を果たせる形に保つ。

## 規律

- [個人情報は最小化して載せ、期限で消す](./minimize-and-expire.md)

## 参照
事実の保持と削除の判断は [data](../../principles/data/README.md) に従う。
観測の記録への適用と、境界を越えて伝播する文脈の扱いは [observability](../observability/README.md) に従う。
消去する port と管理操作の置き場は [structure/core/infrastructure](../../structure/core/infrastructure.md) が定める。
言語別の実現は [tools](../tools/) が定める。
