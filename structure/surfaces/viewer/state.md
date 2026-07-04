# 状態の分離

viewer の状態を、目的ごとに分けて扱う規律を定める。
state は [layout](./layout.md) の依存に従う。

## 目的による分離

状態を、remote・URL・local・横断 の4つに分ける。
remote は、外部から取得した状態である。
URL は、画面の位置や絞り込みの条件を URL で表す状態である。
local は、一つの component の中だけの状態である。
横断 は、複数の component で共有する client の状態である。
異なる目的の状態を、一つの入れ物に混ぜない。
URL は pages、local は各 component、横断は共有する複数のスライスの下の層に置き、layout の shared 層とは別に扱う。

## remote の状態

remote の状態は、cache・再取得・無効化を備えた仕組みで扱う。
remote の状態を、横断 の client の状態と混ぜない。
remote の通信は、ui port を通して行う。
型は、contracts/generated の型を参照する。
参照の規律は [layout](./layout.md) と [skeleton](../../skeleton.md) に従う。
状態管理の機構は [languages](../../../languages/) に従う。
