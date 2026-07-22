# mobile の構造

mobile は、[viewer](../../surfaces/viewer/layout.md) を mobile の shell でホストする runtime である。
viewer の ui port を mobile の API で実装する。
viewer を起動する。
viewer を共有しない native の UI は、標準外とする。
採る project は、ADR に明記する。
mobile は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
mobile/
├─ adapters/
│  └─ <port>        viewer の ui port を mobile の API で実装する。
└─ composition      ui port の注入・viewer の起動・mobile の shell の構築。
```

`adapters` は、viewer が要求する ui port を、1 port を1ファイルとして実装する。
`composition` は単一の組立点である。

## 依存方向

依存は一方向に保つ。
composition が adapters を組み立て、viewer へ注入する。
adapters は、viewer の ui port を実装し、composition を参照しない。
mobile の外との依存は [skeleton](../../skeleton.md) に従う。
同じ viewer をホストする runtime どうしは、互いに依存しない。
それぞれが viewer に依存する。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## ui port の実装

adapters は、viewer が定義する ui port を mobile の API で実装する。
remote の通信は、[contracts/generated](../../contracts/generated.md) の client を ui port の実装として渡す。
adapters は、viewer の ui port の型に依存する。
composition は、viewer が公開する起動の入口に依存する。
mobile は、viewer の内部へ踏み込まない。
mobile 固有の処理は、adapters と composition に置く。
viewer の中に、mobile や platform の分岐を置かない。
具体の API の機構は [languages](../../../languages/) が定める。

## 組み立てと起動

composition は、adapters を viewer へ注入する。
composition は、mobile の shell を構築する。
その shell の中で viewer を起動する。
offline で動かす project は、host がプロセス内に core を抱けるかで置き方が決まる。
host がプロセス内に core を抱けるなら、composition が core を埋め込み、その操作を remote の ui port の実装として渡す。
別プロセスや別言語で抱けないなら、embedded surface を同梱起動し、protocol で繋ぐ。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
shell と bundler の機構は [languages](../../../languages/) が定める。

## 配布

mobile は、OS の store を経て配布する。
配布と更新は [deploy](../../deploy/layout.md) に従う。
