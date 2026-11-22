# 見た目の規律

viewer の見た目を組み立てる規律を定める。
styling は [layout](./layout.md) の依存に従う。

## design tokens

色・間隔・字形などの値は、design tokens として一元化する。
component は、design tokens を通して見た目の値を参照する。
token は値の一致ではなく用途で選ぶ。
例えば、選択中の行と警告の背景が一つのテーマで同色でも、警告色の変更で選択の表示まで変わらないようにする。

## layout primitives

配置は、host に依らない layout primitive の組み合わせで組む。

## headless とアクセシビリティ

振る舞いとアクセシビリティは、見た目を持たない headless の部品で担う。
見た目の値は、design tokens で headless の部品に与える。
テーマで同じ状態の外観を変えても、状態を切り替える条件や、その状態で可能な操作は変えない。
具体の機構は [languages](../../../languages/) が定める。
