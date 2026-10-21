# worker の構造

worker は、背景処理と定期実行の surface である。
core を埋め込み、job の要求を契約 adapter の保護された公開入口へ渡す。
自己ホストであり、自身でプロセスを起動する。
背景の処理は、API server に同居させず、worker のプロセスで実行する。
常駐して job を処理する queue と、OS の定時起動が起動する一回実行の schedule を持つ。
worker は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
worker/
├─ jobs/
│  └─ <job>        core API の operation を呼び出す。
├─ queue           単一の DB を土台に job を取り出し、予約した時刻に達した job を起動する常駐の runner。
├─ schedule        OS の定時起動から一回だけ起動し、予定時刻から導いた冪等の鍵を付けて job の要求を渡す入口。
└─ composition     core の埋め込み・配線・起動。
```

`jobs` は、1 job を1ファイルに置く。
`queue` は、job を取り出す runner である。
`schedule` は、定時起動の入口である。
`composition` は単一の組立点である。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が jobs・queue・schedule を組み立て、core を埋め込む。
jobs・queue・schedule は、composition を参照しない。
worker の外との依存は [skeleton](../../skeleton.md) に従う。
worker 自身の技術的な処理は、[libs](../../libs/layout.md) の公開 API を直接使え、core の operation を仲介にしない。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## job と application

job が業務の operation を起動する経路は、core の公開 application 入口へ接続した契約 adapter の保護された公開入口に限る。
core の業務処理が必要とする libs の port は、[core/composition](../../core/composition.md) が配線する。
worker が所有する技術機構の配線は worker の composition に置き、queue の runner と schedule の入口はその公開 API を直接使う。
job は、業務判断を持たず、配線された処理を呼ぶだけである。
job は queue の機構の型を core へ持ち込まず、公開契約の生成 DTO を契約 adapter の公開入口へ渡す。
payload の decode と契約の形式と制約の検証は境界で行い、application 入出力との写像は [contracts/adapters](../../contracts/adapters.md) が所有する。
生成 DTO、未知項目の扱い、生成能力の不足の解消は [contracts/generated](../../contracts/generated.md) に従い、job が同義の DTO を手書きしない。
worker は、派生読みモデルの定常・定期の再構築 workflow を job として起動する役割を担う。

## OS と worker の分担

OS は、プロセスの起動・監視・再起動、資源制限、固定の時刻と間隔による起動を担う。
worker は、durable な job の queue、業務のデータが決める時刻の予約、再配送、冪等な確定を担う。
同じ仕事を両方に持たせず、OS が担う仕事を、worker の内部の supervisor、資源上限の強制、固定の時刻の scheduler として再実装しない。
OS の採用は [tools/platforms/nixos](../../../tools/platforms/nixos.md) が定め、その宣言は [deploy](../../deploy/layout.md) の infrastructure に置く。

## queue と予約

queue runner は、queue から実行可能な job を取り出して起動する。
業務のデータが決める時刻の予約(確定の三日後の確認など)は、予約時刻を持つ job として queue が durable に保持し、時刻に達した job を queue runner が起動する。
予約は、業務の識別子と種類から導いた冪等の鍵を持ち、同じ業務事実から二度積まれても一つの job にまとまる。
冪等の鍵と適用済みの記録は [concerns/resilience](../../../concerns/resilience/idempotent-operations.md) の「再実行のある操作を冪等にする」に従う。
長期にわたる stateful な workflow は、標準の対象外とする。
queue の engine は、project の選択の対象でなく、[languages](../../../languages/) が固定する。
並行度、順序、排他、背圧、durable receipt、ack、processing completion、冪等な確定、再配送、失敗の隔離は、[concerns/concurrency](../../../concerns/concurrency/README.md)、[concerns/messaging](../../../concerns/messaging/README.md)、[concerns/resilience](../../../concerns/resilience/README.md)、[concerns/transaction](../../../concerns/transaction/README.md) に従う。

## 定時起動

schedule は、OS の定時起動が起動する一回実行の入口であり、常駐しない。
OS の定時起動は、一つの機の上での起動の合図である。
複数の機の中で一つだけが起動すること、停止中に過ぎた全ての予定時刻の起動を残すこと、実行中の入口への合図を別の実行として残すこと、業務の予約が一度だけ起きることを、保証しない。
これらの保証は、OS でなく schedule と durable な記録が担う。
予定時刻は、起動した時刻でなく、起動の宣言が引数で渡す周期の式から、起動時刻以前で最新の時刻として得る。
周期の式は起動の宣言だけが持ち、OS の timer と schedule の引数は同じ式から作る。
schedule は、job の要求に予定時刻から導いた冪等の鍵を付けて、契約 adapter の保護された公開入口へ渡す。
同じ予定時刻の要求は、複数の機からの起動、重複した起動、遅れた起動でも、鍵の durable な記録で一つの job にまとまる。
排他は OS の起動でなく鍵の記録の一意性で担い、冪等の鍵と適用済みの記録は [concerns/resilience](../../../concerns/resilience/idempotent-operations.md) の「再実行のある操作を冪等にする」に従う。
全ての予定時刻の実行が業務上必要な job は、OS の補完に頼らず、起動のたびに永続化した処理済みの予定時刻から今の予定時刻までを数え上げ、未処理の全てを要求する。
最新の予定時刻だけが必要な job は、過ぎた予定時刻を要求せず捨てることを、決定の記録に残す。
起動の遅れと未処理の予定時刻の数は、観測へ出す。

## 組み立てと起動

composition は、build_core で core を埋め込み、自身でプロセスを起動する。
queue の常駐 process と schedule の一回実行 process は、同じ composition から起動する。
queue の runner は、job context の発行元、対象、完全性、有効性を認証境界で検証し、認証主体と資格情報の許可範囲を確定する。
schedule は、実行環境が渡す起動主体の資格情報を認証境界で検証し、認証主体と資格情報の許可範囲を確定する。
job は payload が指定する認証主体を信頼せず、検証済みの認証文脈へ結び付けた契約 adapter の保護された公開入口を使う。
job の期限、取消、相関の実行文脈を、認証の文脈や業務入力と分ける。
資格情報、job context に含まれる認証素材、queue と schedule の認証方式の型を core へ渡さない。
常駐する queue は、生存と準備の面を公開する。
一回実行の schedule は、終了 status で成功と失敗を返し、OS がその結果を観測する。
lifecycle の規律は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。
観測の規律は [concerns/observability](../../../concerns/observability/README.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration/README.md) に従う。
queue の機構は [languages](../../../languages/) が定め、定時起動の機構は [tools/platforms/nixos](../../../tools/platforms/nixos.md) が定める。
