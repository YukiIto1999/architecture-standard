# web の構造

web は、[viewer](../../surfaces/viewer/layout.md) を browser でホストする runtime である。
viewer の ui port を browser の API で実装する。
viewer を起動する。
web は core を埋め込まず、remote の通信で動く。
core のプロセスを browser に置く採用を、標準は持たない。
web は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
web/
├─ adapters/
│  └─ <port>        viewer の ui port を browser の API で実装する。
└─ composition      ui port の注入・viewer の mount と起動。
```

`adapters` は、viewer が要求する ui port を、1 port を1ファイルとして実装する。
`composition` は単一の組立点である。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency.md) に従う。
composition が adapters を組み立て、viewer へ注入する。
adapters は、viewer の ui port を実装し、composition を参照しない。
web の外との依存は [skeleton](../../skeleton.md) に従う。
同じ viewer をホストする runtime どうしは、互いに依存しない。
それぞれが viewer に依存する。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## ui port の実装

adapters は、viewer が定義する ui port を browser の API で実装する。
remote の通信は、[contracts/generated](../../contracts/generated.md) の client を ui port の実装として渡す。
adapters は、viewer の ui port の型に依存する。
composition は、viewer が公開する起動の入口に依存する。
web は、viewer の内部へ踏み込まない。
web 固有の処理は、adapters と composition に置く。
viewer の中に、browser や web の分岐を置かない。
具体の API の機構は [tools](../../../tools/) が定める。

## 組み立てと起動

composition は、adapters を viewer へ注入する。
composition は、viewer を DOM に mount して起動する。
entry と bundler の機構は [tools](../../../tools/) が定める。
