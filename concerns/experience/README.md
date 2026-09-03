# experience

## 概要
experience は、利用者に向けた画面の体験を統べる規律である。
適用範囲は、利用者が判断し操作する面である。
GUI の viewer を主に、extension の UI や console の対話にも及ぶ。
視覚的な重み、target size、mouse 操作、route の規律は、visual UI だけに適用する。
console には、判断、feedback、進行表示の規律を適用する。
principles の [legibility](../../principles/legibility/README.md) が定める明瞭さと [separation](../../principles/separation/README.md) が定める責務の境界を、利用者に向けた面へ具象化する。
設計の目的は、利用者の判断と操作を、楽に安全に迷いなくすることである。
コードの設計が変更を楽にするのと、同じ型である。

## 規律

- [判断の易しさを最適化する](./decision-simplicity.md)
- [主操作と既定値を先に示し、頻用操作に近道を備える](./primary-action-defaults.md)
- [状態と結果を即時に返す](./immediate-feedback.md)
- [誤りを防ぎ、起きたら回復を助け、取り返せるようにする](./error-prevention-recovery.md)
- [利用者の語彙と現実に合わせ、操作できることを見える形で示す](./user-vocabulary-affordance.md)
- [情報を局面と依存でまとめ、余白と階層で導く](./information-grouping.md)
- [同じ目的に同じ画面のパターンを使う](./consistent-patterns.md)
- [情報構造を作業の流れに沿わせ、現在地を示す](./workflow-aligned-navigation.md)
- [誇張せず、効かないものを見せない](./honest-capability-display.md)

## 参照
明瞭さは [legibility](../../principles/legibility/README.md)、責務の境界は [separation](../../principles/separation/README.md)、不正状態の排除は [modeling](../../principles/modeling/README.md)、境界での parse は [types](../types/README.md)、語彙の統一は [naming](../../principles/naming/README.md) に従う。
利用者面の可達性と識別性は [accessibility](../accessibility/README.md) に従う。
viewer の構造は [structure/surfaces/viewer](../../structure/surfaces/viewer/layout.md)、見た目と機構は [tools](../tools/) が定める。
