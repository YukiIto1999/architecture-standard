# mobile の構造

mobile は、[viewer](../../surfaces/viewer/layout.md) を mobile の shell でホストする runtime である。
viewer の ui port を mobile の API で実装する。
viewer を起動する。
viewer を共有しない native の UI は、標準外とする。
採る project は、決定の記録に明記する。
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

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が adapters を組み立て、viewer へ注入する。
adapters は、viewer の ui port を実装し、composition を参照しない。
mobile の外との依存は [skeleton](../../skeleton.md) に従う。
adapters と composition は、必要な技術基盤を [libs](../../libs/layout.md) の公開 API から直接利用する。
libs の利用は、core の埋め込みを条件にしない。
同じ viewer をホストする runtime どうしは、互いに依存しない。
それぞれが viewer に依存する。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

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
remote の core だけを使う場合は生成した通信 client で接続し、ローカルの core を同梱しない。
ローカルの core の公開 API を直接呼べる場合は、composition が core を組み立て、contracts/adapters の保護された公開入口を ui port の実装へ接続する。
別言語の core は [embedded surface](../../surfaces/embedded/layout.md) の native library を同梱し、composition が初期化して protocol へ接続する。
mobile のローカル core は同一プロセスに組み込み、別プロセスの同梱起動を前提にしない。
その構成に HTTP がなければ、server の routes や生成した HTTP client を要求しない。
offline の要件を持つ場合は、ネットワークを使わず必要な業務操作と状態の保存・再起動後の復元が成立することを確かめ、組込の未成立を remote 接続への変更で隠さない。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
shell と bundler の機構は [languages](../../../languages/) が定める。
起動失敗・準備前・停止開始後の要求を受け付けず、準備が成立しない場合は viewer へ失敗を返す。
OS による中断と強制終了は正常停止の完了を前提にせず、復帰または再起動時の回復を [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従って定める。

## 配布

mobile の公開と配布は、[deploy](../../deploy/layout.md) の「公開と配布の選択」に従う。
OS の store を配布 channel に選ぶ場合は、その提出と更新の条件を満たす。
手元での利用は OS が認めるインストール経路を使い、公開を選ばないことと OS の署名や実行権限の条件を免れることを同一視しない。
shell と native library とその依存物は一組の成果物として配布・更新する。
対象の OS と CPU ごとに、開発環境のない端末へ配布成果物を入れ、起動・業務操作・取消・中断からの復帰・強制終了後の再起動を確認する。
