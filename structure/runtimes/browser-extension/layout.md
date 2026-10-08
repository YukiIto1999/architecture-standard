# browser-extension の構造

browser-extension は、[extension](../../surfaces/extension/layout.md) を browser の拡張としてホストする runtime の種類である。
UI を持つ場合は、同じ host が [viewer](../../surfaces/viewer/layout.md) もホストする。
core をプロセス内に埋め込まず、remote の通信で動く。
core の埋め込みや埋め込み surface の同梱起動を、この host の構成に含めない。
browser-extension は [skeleton](../../skeleton.md) の依存と命名、および [runtimes](../README.md) の共通の形に従う。
資格情報の検証は [concerns/authentication](../../../concerns/authentication/README.md)、保持と保管は [concerns/secrets](../../../concerns/secrets/README.md)、権限の評価は [concerns/authorization](../../../concerns/authorization/README.md) に従う。
処理の寿命は [concerns/concurrency](../../../concerns/concurrency/README.md)、停止と再生成は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。

## フォルダ構成

```
<host>/
├─ adapters/
│  └─ <port>        extension の host port と viewer の ui port を実装する。
└─ composition/
   └─ <context>     実行 context ごとの entry・port の注入・登録と起動。
```

`<host>` には、host の種類でなく具体の host 名を使う。
`adapters` は、surface が要求する port を、1 port を1ファイルとして実装する。
`composition` は組み立ての所有単位であり、実行 context ごとの entry をこの単位に置く。
context の種類、entry の形式、host への登録の機構は [languages](../../../languages/) が定める。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。

| 参照元 | 参照してよい先 |
|---|---|
| composition | adapters・extension の公開起動入口・UI を持つ場合は viewer の公開起動入口 |
| adapters | extension の host port・viewer の ui port・host の API・contracts/generated のデータ型と通信 client |

adapters は composition を参照せず、surface の内部へ踏み込まない。
host の外との依存は [skeleton](../../skeleton.md) の実行時依存表に従う。
技術基盤は、adapters と composition が [libs](../../libs/layout.md) の公開 API を直接利用する。
他の runtime の adapter や組立点を import せず、それぞれが同じ surface に依存する。

## host port の実装

adapters は、extension の host port を host の API で実装する。
remote の通信は、[contracts/generated](../../contracts/generated.md) の client を port の実装に用いる。
接続設定と transport の instance は host が組み立て、client に与える。
extension と viewer は generated のデータ型だけを import し、通信の実装は注入された port から受け取る。
port は、host の API 名や実行 context の種類でなく、surface が必要とする目的と限定した operation で表す。
具体の API、権限の宣言、認証 callback、保管と通信の機構は [languages](../../../languages/) が定める。

## 実行 context 間の通信

実行 context 間の message は、host の adapters が所有する wire transport である。
surface の port に message の wire 型や host の通信 API を露出せず、受信側 adapter が限定した operation と検証済みの入力へ写像する。
受信側 adapter は、送信元、要求された operation、対象と宛先、入力を検証してから処理を実行する。
送信元は host が提供する context の識別から判定し、payload の自己申告で代替しない。
任意の URL、header、body を受け取り、資格情報を付けて転送する汎用 proxy を公開しない。
許可した operation の入力と宛先への写像は adapter が所有し、要求側がその制限を上書きできる形にしない。
message の送受信と検証を実現する機構は [languages](../../../languages/) が定める。

## 資格情報の消費境界

資格情報の取得、保持、認証付き通信を所有する adapter は、host が信頼する実行 context に置く。
資格情報を content script やページ、host 非依存の extension と viewer へ渡さず、必要な operation だけを公開する。
一般状態の保管と資格情報の保持を同じ adapter の汎用 API に束ねず、consumer と保持終了の責任を追跡できる境界に分ける。
保持する期間と永続保管の保護は [concerns/secrets](../../../concerns/secrets/README.md) に従い、browser の保管 API があることだけで安全な保管とみなさない。

## UI の host

UI を持つ実行 context では、composition が viewer を起動し、adapters がその ui port を実装して注入する。
UI とそれ以外の実行 context を接続する場合も、同じ host が wire transport を所有する。
viewer の中に browser の拡張 API や host の分岐を置かず、viewer の規律は [viewer](../../surfaces/viewer/layout.md) に従う。

## 組み立てと起動

composition は実行 context ごとの entry で adapters を組み立て、その context に必要な surface の公開入口へ注入する。
各 context の起動、host への機能の登録、イベントの受付、依存資源の解放は host が所有する。
context の停止と再生成を host の寿命に従って扱い、一つの常駐 process や context 間の共有メモリを surface の前提にしない。
entry と登録、起動と停止の具体の機構は [languages](../../../languages/) が定める。
