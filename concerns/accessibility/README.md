# accessibility

## 概要
accessibility は、利用者面の可達性と識別性を全系で統べる規律である。
適用範囲は、利用者が判断し操作する面である。
GUI の viewer を主に、extension の UI や console の対話にも及ぶ。
pointer target、対比、色だけに頼らない表現の規律は、visual UI だけに適用する。
console には、keyboard 操作の規律を適用する。
principles の [legibility](../../principles/legibility/README.md) が定める明瞭さを、入力機構と知覚の差を越えて届く利用者面へ具象化する。
設計の目的は、入力機構と知覚と手の精度の差によって、操作と識別が不可能になる面を作らないことである。

## 規律

- [キーボードで操作でき、色だけに頼らない](./keyboard-color-contrast.md) — 機械+レビュー(axe検査+AA目視レビュー)
- [pointer target を掴める大きさに保つ](./pointer-target-size.md) — 機械(bounding box照合test)

## 参照
明瞭さは [legibility](../../principles/legibility/README.md)、利用者に向けた画面の体験は [experience](../experience/README.md) に従う。
viewer の構造は [structure/surfaces/viewer](../../structure/surfaces/viewer/layout.md)、検証の技法と検証手段の割り当ては [structure/tests/methods](../../structure/tests/methods.md)、見た目と機構は [tools](../tools/) が定める。
