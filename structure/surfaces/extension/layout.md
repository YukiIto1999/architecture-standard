# extension の構造

extension は、拡張の surface である。
host は、runtimes の [ide](../../runtimes/ide/layout.md) または [browser-extension](../../runtimes/browser-extension/layout.md) が担う。
host の機能を remote API または埋め込み protocol の operation へ写像する。
host に求める能力を port として定義する。
host 非依存で、host の分岐を持たない。
UI の体験は [concerns/experience](../../../concerns/experience/README.md)、可達性と識別性の規律は [concerns/accessibility](../../../concerns/accessibility/README.md) に従う。
extension は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
extension/
├─ features/
│  └─ <feature>     remote API または埋め込み protocol を呼ぶ拡張の機能。
├─ shared/          host 非依存の primitive と host port。
└─ composition      host port の注入・features の組み立て。
```

`features` は、1 feature を1ファイルに置く。
`shared` は host 非依存の primitive と、host の能力を表す port を置く。
`composition` は、host が呼び出す組み立ての所有単位である。
host の実行 context ごとに必要な features を組み立て、単一の常駐 instance を前提にしない。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が features を組み立て、host port を注入する。
core への接続は、host が注入した client または protocol の port を使う。
features は shared を参照できる。
features と shared は、composition を参照しない。
extension の外との依存は [skeleton](../../skeleton.md) に従う。
host 非依存の技術的な処理は、[libs](../../libs/layout.md) の公開 API を直接利用し、core や host を仲介にしない。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## host 非依存

extension は、host に求める能力を port として定義する。
host が、port の実装を注入する。
一つの extension surface は、複数の host から port の実装を注入される。
extension は、host の分岐を持たない。
port は目的と operation を表し、host の API 型、実行 context、message の wire 型を公開契約に含めない。
具体 host ごとの実装は [runtimes](../../runtimes/) に置く。
UI を持つ機能は、独立した surface である [viewer](../viewer/) を再利用し、その公開 API を参照する。
extension と viewer は、それぞれの shared を統合しない。
実行 context ごとの entry、host への登録、起動と停止は host が所有し、extension は host から呼ばれる公開入口を提供する。
実行 context 間の通信は host の adapters に閉じ、extension は限定した operation と検証済みの入力だけを受け取る。
資格情報の取得と認証付き通信は host が所有し、extension と viewer の状態や port のデータ型に資格情報を含めない。

## core への接続

extension は、core を直接埋め込まない。
remote の関心は、host が port として注入する client で server の API を呼ぶ。
extension 自身は、remote と local のどちらも [contracts/generated](../../contracts/generated.md) のデータ型の import にとどめる。
local の関心は、core を埋め込んだ埋め込み surface へ、host が port として注入する protocol の client・stub で接続する。
protocol の意味と wire の binding は [contracts/protocol](../../contracts/protocol.md) が定め、extension がそのスキーマや通信実装を実行時に直接 import しない。
local の接続は、host が要求する場合に限って使う。
server の API を、この接続で置き換えない。
extension は、注入された client または protocol の operation を呼び、業務判断を持たない。
接続の依存は [skeleton](../../skeleton.md) に従う。
接続の機構は [languages](../../../languages/) が定める。

## 配布

extension の公開と配布は、[deploy](../../deploy/layout.md) の「公開と配布の選択」に従う。
公開または配布を選び、その channel が marketplace の場合に、marketplace へ成果物を提出する。
手元だけで利用する extension は、host が認めるローカルの読み込みを使い、marketplace への登録と提出を必須にしない。
公開用とローカル用で実装を分けず、配布経路に応じて必要な metadata と接続設定を組み立てる。
