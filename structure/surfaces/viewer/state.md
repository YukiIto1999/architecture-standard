# 状態の分離

viewer の状態を、正本の所在と寿命で分けて扱う規律を定める。
state は [layout](./layout.md) の依存に従う。

## 権威と寿命による分離

状態を、まず正本の所在で remote と local に分ける。
remote は、正本を surface の外の系が持ち、viewer が控えとして扱う状態である。
local は、正本を実行中の surface または host が持つ状態である。
remote と local を、寿命だけで分けない。
local を、寿命と共有範囲で URL・横断・一時 に分ける。
URL は、画面の位置や絞り込みの条件を URL で表し、遷移と共有で寿命が決まる状態である。
横断 は、複数の component で共有する状態である。
一時 は、一つの component の中に閉じる状態である。
URL・横断・一時 を、remote と並ぶ分類として扱わない。
異なる分類の状態を、一つの入れ物に混ぜない。
URL は pages、一時は各 component、横断は共有する複数のスライスの下の層に置き、layout の shared 層とは別に扱う。

## remote の状態

remote の状態は、cache・再取得・無効化を備えた仕組みで扱う。
remote の値を、local の状態の入れ物へ複製しない。
remote の通信は、ui port を通して行う。
型は、contracts/generated の型を参照する。
参照の規律は [layout](./layout.md) と [skeleton](../../skeleton.md) に従う。
状態管理の機構は [languages](../../../languages/) が定める。

## 区分の表示と選択

業務区分の識別子と表示名を分け、表示名や表示順から送信する区分を復元しない。
viewer は表示名と表示順を表示へ写す対応を持ち、公開契約が持つ表示名と表示順を別の一覧へ複製しない。
業務区分の意味と入力の値域は公開契約に従う。
選択肢は、入力先の operation が公開する選択可能な集合から導き、区分の全一覧や過去の表示対象と同一視しない。
認可・現在の状態・廃止による選択制限を viewer で独立して定義せず、operation の選択肢を返す ui port を通して受け取る。
取得した選択肢は「remote の状態」に従って扱う。
入力補助と契約の検証の区別は [concerns/types](../../../concerns/types/parse-once-at-boundary.md) の「境界で一度だけ parse する」に従う。
