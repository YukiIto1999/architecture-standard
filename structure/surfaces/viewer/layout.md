# viewer の構造

viewer は、GUI の surface である。
feature ごとのスライスに分け、host に求める能力を ui port として定義する。
host 非依存で、host の分岐を持たない。
状態の分離は [state](./state.md)、見た目は [styling](./styling.md) で規定する。
利用者に向けた体験の規律は [concerns/experience](../../../concerns/experience.md) に従う。
viewer は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
viewer/
├─ app/            初期化・配線・文脈の供給・ui port の受け取り。
├─ pages/
│  └─ <page>       route に対応する画面。
├─ widgets/
│  └─ <widget>     画面の区画。
├─ features/
│  └─ <feature>    利用者の操作。
├─ entities/
│  └─ <entity>     画面の業務モデル。
└─ shared/         host 非依存の primitive と ui port。
```

`features` と `entities` は、業務の関心ごとにスライスを置く。
各スライスは、内部を隠し、public API だけを公開する。
同じ層のスライスは、互いを参照しない。
複数のスライスが共有するものは、下の層に置く。

## 依存方向

依存は一方向に保つ。
app が composition root であり、各層を組み立てる。
参照は、app・pages・widgets・features・entities・shared の順に下る。
下位の層は、上位の層を参照しない。
技術カテゴリでまとめず、feature と entity で分ける。
viewer の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## 画面の形

一覧と詳細を組む形は、[concerns/experience](../../../concerns/experience.md) が用途で定める。
ルート分割は、一覧の page と詳細の page を分け、route で繋ぐ。
並置は、一つの page を一覧と詳細の widget で構成する。
route と URL の状態は [state](./state.md) に従う。

## 文言

viewer は、単一の locale で作り、多言語化は project が加算で持ち込む。
画面の文言は、業務の語彙に従う。
語彙の規律は [principles/naming](../../../principles/naming.md) に従う。

## host 非依存

viewer は、host に求める能力を ui port として定義する。
host が、ui port の実装を注入する。
一つの viewer surface は、複数の host から ui port の実装を注入される。
viewer は、host の分岐を持たない。
具体 host は [runtimes](../../runtimes/) が担う。

## 観測

エラーの報告と telemetry の収集は、viewer の業務の判断に混ぜず、境界の殻で行う([concerns/observability](../../../concerns/observability.md) に従う)。
収集は ui port として定義し、host が実装を注入する。
viewer 自体は、収集の機構を持たない。
個人情報を含む観測は、[concerns/observability](../../../concerns/observability.md) の個人情報の規律に従う。
収集の機構は [languages](../../../languages/) が定める。
host の実装は [runtimes](../../runtimes/) に従う。
