# extension の構造

extension は、拡張の surface である。
host は、runtimes の ide が担う。
host の機能を core の操作へ写像する。
host に求める能力を port として定義する。
host 非依存で、host の分岐を持たない。
UI の体験は [concerns/experience](../../../concerns/experience.md) に従う。
extension は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
extension/
├─ features/
│  └─ <feature>     core の操作を呼ぶ拡張の機能。
├─ shared/          host 非依存の primitive と host port。
└─ composition      core への接続・host port の注入・機能の登録。
```

`features` は、1 feature を1ファイルに置く。
`shared` は host 非依存の primitive と、host の能力を表す port を置く。
`composition` は単一の組立点である。

## 依存方向

依存は一方向に保つ。
composition が features を組み立て、host port を注入する。
core への接続も composition が持つ。
features は shared を参照できる。
features と shared は、composition を参照しない。
extension の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## host 非依存

extension は、host に求める能力を port として定義する。
host が、port の実装を注入する。
一つの extension surface は、複数の host から port の実装を注入される。
extension は、host の分岐を持たない。
具体 host ごとの実装は [runtimes](../../runtimes/) に置く。
UI を持つ機能は、独立した surface である [viewer](../viewer/) を再利用し、その公開 API を参照する。
extension と viewer は、それぞれの shared を統合しない。

## core への接続

extension は、core を直接埋め込まない。
remote の関心は、host が port として注入する client で server の API を呼ぶ。
extension 自身は、[contracts/generated](../../contracts/generated.md) の型の import にとどめる。
local の関心は、core を埋め込んだ埋め込み surface へ、[contracts/protocol](../../contracts/protocol.md) の言語非依存の protocol で接続する。
local の接続は、host が要求する場合に限って使う。
server の API を、この接続で置き換えない。
extension は、core の操作を呼び、業務判断を持たない。
接続の依存は [skeleton](../../skeleton.md) に、機構は [languages](../../../languages/) に従う。

## 配布

extension は、marketplace を経て配布する。
配布と更新は [deploy](../../deploy/layout.md) に従う。
