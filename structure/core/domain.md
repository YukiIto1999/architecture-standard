# domain 層

domain 層は、そのコンテキストの業務判断と内部表現を所有する純粋な核である。
集約とその不変条件を表し、値・区分・集合・状態・イベント・エラーを置き、外部への公開と手順の所有は application に分ける。
domain は [layout](./layout.md) の単位と依存に従う。

## 集約

集約は、独立した状態と、その状態について同時に守る不変条件を所有する単位である。
アクターの目的と変更理由で分けたモデルのうち、独立した状態と不変条件を所有するものを集約として引き、値や方針だけを表す純粋なモデルは集約にしない。
一つの集約は、集約 root と、それに属する値・状態・イベント・エラーからなる。
一つの集約が、その集約の不変条件を同時に守る一つの強整合境界に対応する。
集約は、別の集約の内部を参照せず、識別子で参照する。
集約は、table、コンテキスト、transaction の単位と同一視しない。
集約が数える単位と識別子が表す同一性は、[principles/data](../../principles/data/fact-state-time.md) の「データを事実・状態・時間で分類する」が定める単位、同一性、範囲の決定から引き、識別子の型や table の key から逆算しない。
domain は、一つの集約の不変条件と遷移を純粋な関数で判断し、複数の集約の変更を同時に確定するかも、確定の範囲も決めない。
同じコンテキストの複数の集約の判断を要する業務動作は、application の use-case が各集約の純粋な関数を呼んで結果を組み、同時に確定するかを決める。
別の確定に分けた集約どうしの一貫性と進行は、同じコンテキストの application が所有し、複数の動作の調整が必要な場合は workflow が各 use-case の型付き outcome を用いる。
整合性と集約境界の原則は [principles/data](../../principles/data/README.md) に従う。

## 常に正しい構築

集約と値は、不変条件を検証する factory のみで生成する。
不変条件を迂回する公開 constructor は持たない。
状態の変更は、集約のメソッドを通じて、新しい状態を返す純粋な遷移として行う。
遷移の結果は、新しい状態と起きた出来事の対応を一つの業務判断として表し、呼出側が両者を別々の規則で組み立てない。
この新しい状態は判断結果の値であり、保存時の正本と導出の関係は [principles/data](../../principles/data/derive-state-from-facts.md) の「今の状態を事実の行から導く」に従う。
フィールドを直接書き換える setter は持たない。
値とイベントは不変である。

## 純粋性

domain は純粋な値と関数のみで構成する。
domain が参照しない対象は [concerns/effect](../../concerns/effect/README.md) の禁止事項に従う。
domain は、加えてログ、外部 SDK、非同期実行も参照しない。
副作用と非同期は application と infrastructure が担う。
効果の規律と、状態の遷移を副作用のない判断として書く方法は [concerns/effect](../../concerns/effect/README.md) に従う。

## ドメイン型と語彙

値の計算と比較、区分に基づく判断、集合の業務操作を持つ型と関数は domain に置き、application はその操作を呼ぶ。
値の意味と操作は [modeling](../../principles/modeling/meaning-in-types.md) の「業務の意味を型に封じる」に従う。
区分と判断は [construction](../../principles/construction/decisions-as-types.md) の「業務判断を型と多態で構造化する」に、集合と操作は [construction](../../principles/construction/named-collection-operations.md) の「集合処理を名前のある操作で表す」に従う。
事実の行から今の状態を導く定義の配置は、[concerns/persistence](../../concerns/persistence/period-state-views.md) の「期間の判定を一か所のビューに定義する」に従う。
domain は導出された値を受け取って業務判断を行い、datastore に定義した判定を書き写さない。
控えの条件は [principles/data](../../principles/data/derive-state-from-facts.md) の「今の状態を事実の行から導く」に従い、控えの保存と更新の確定は application と infrastructure が担う。
domain の業務型と規則は、そのコンテキストが独立して所有し、外部との公開 Interface や共有の業務モデルにしない。
domain は、persistence の record、wire 型、DTO、公開契約の定義と生成した型・構築・codec・Interface を参照しない。
許可される依存は [layout](./layout.md) の依存方向に、型の設計は [concerns/types](../../concerns/types/README.md) に、命名は [principles/naming](../../principles/naming/README.md) に従う。

## イベント

domain イベントは、集約の遷移で起きた業務上の出来事を、domain が値として返す表現である。
domain イベントを返すことは、業務事実としての保持、outbox への記録、外部への公開、イベント列からの状態の復元のいずれも約束しない。
出来事を業務事実として残すかは、[principles/data](../../principles/data/preserve-facts-and-current-state.md) の「業務事実と現在情報を分けて保持する」に従って契約から決め、残さない出来事は遷移の結果の値にとどめる。
イベント列を集約の状態の正本にする方式(Event Sourcing)でも、状態の正本と導出は data の規律に従う。
対象となる全ての状態変更を事実の行として保持する契約と、再構築、訂正、消去、競合の扱いを必要とし、domain イベントがあることからこの保持契約を作らない。
domain イベントの存在を、別の datastore や broker を採る理由にしない。
integration event への写像は application が担い、配送経路の配線は composition が担う。
配送の規律は [concerns/messaging](../../concerns/messaging/README.md) に従う。
