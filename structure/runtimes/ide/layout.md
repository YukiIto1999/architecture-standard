# ide の構造

ide は、[extension](../../surfaces/extension/layout.md) を IDE でホストする runtime である。
extension の host port を IDE の API で実装する。
extension を IDE へ登録して起動する。
ide の host は、core を埋め込まない。
local の関心は、同梱起動する埋め込み surface が担う。
ide は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
ide/
├─ adapters/
│  └─ <port>        extension の host port を IDE の API で実装する。
└─ composition      host port の注入・extension の登録と起動。
```

`adapters` は、extension が要求する host port を、1 port を1ファイルとして実装する。
`composition` は単一の組立点である。

## 依存方向

依存は一方向に保つ。
composition が adapters を組み立て、extension へ注入する。
adapters は、extension の host port を実装し、composition を参照しない。
ide の外との依存は [skeleton](../../skeleton.md) に従う。
同じ extension をホストする runtime どうしは、互いに依存しない。
それぞれが extension に依存する。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## host port の実装

adapters は、extension が定義する host port を IDE の API で実装する。
remote の通信は、[contracts/generated](../../contracts/generated.md) の client を port の実装として渡す。
adapters は、extension の host port の型に依存する。
composition は、extension が公開する起動の入口に依存する。
ide は、extension の内部へ踏み込まない。
ide 固有の処理は、adapters と composition に置く。
extension の中に、IDE の分岐を置かない。
具体の API の機構は [languages](../../../languages/) が定める。

## UI の host

extension が UI を持つ場合、ide は viewer もホストする。
webview の bridge で viewer の ui port を実装し、注入する。
viewer の規律は [viewer](../../surfaces/viewer/layout.md) に従う。

## 組み立てと起動

composition は、adapters を extension へ注入する。
composition は、extension を IDE へ登録して起動する。
extension が local で接続する埋め込み surface は、composition が同梱して起動する。
extension の core への接続は [extension](../../surfaces/extension/layout.md) に従う。
登録の機構は [languages](../../../languages/) が定める。
