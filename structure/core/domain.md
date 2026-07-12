# domain 層

domain 層は業務判断の純粋な核である。
集約とその不変条件を表し、値・イベント・エラーを置く。
domain は [layout](./layout.md) の単位と依存に従う。

## 集約

集約は、強整合を保つ単位である。
一つの集約は、集約 root と、それに属する値・状態・イベント・エラーからなる。
一つの集約が一つの強整合境界に対応する。
集約は、別の集約の内部を参照しない。
集約をまたぐ一貫性は domain では保証しない。
composition が、イベントを用いて集約をまたぐ一貫性を最終的に保つ。
整合性と集約境界の原則は [principles/data](../../principles/data.md) に従う。

## 常に正しい構築

集約と値は、不変条件を検証する factory のみで生成する。
不変条件を迂回する公開 constructor は持たない。
状態の変更は、集約のメソッドを通じて、新しい状態を返す純粋な遷移として行う。
フィールドを直接書き換える setter は持たない。
値とイベントは不変である。

## 純粋性

domain は純粋な値と関数のみで構成する。
domain が参照しない対象は [concerns/effect](../../concerns/effect.md) の禁止事項に従う。
domain は、加えてログ、外部 SDK、非同期実行も参照しない。
副作用と非同期は application と infrastructure が担う。
効果の規律と、状態の遷移を副作用のない判断として書く方法は [concerns/effect](../../concerns/effect.md) に従う。

## 業務の型と語彙

業務上の意味をもつ値は、value object で表す。
識別子、金額、数量、状態、期間はその例である。
裸の string、number、boolean を業務上の意味に用いない。
domain が用いてよいのは、domain の型と shared である。
domain は、persistence の record、wire 型、DTO、contracts の型を参照しない。
許可される依存は [layout](./layout.md) の依存方向に、型の設計は [concerns/types](../../concerns/types.md) に、命名は [principles/naming](../../principles/naming.md) に従う。

## イベント

集約は、履歴として残すべき状態変更を domain イベントとして表す。
ログではなくイベントで残すかの判断は [principles/data](../../principles/data.md) の履歴保持に従う。
イベントの配送と integration event への写像は composition が担う。
配送の規律は [concerns/messaging](../../concerns/messaging.md) に従う。
