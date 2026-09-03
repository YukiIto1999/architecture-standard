# worker の構造

worker は、背景処理と定期実行の daemon の surface である。
core を埋め込み、job を core API の operation へ写像する。
自己ホストであり、自身でプロセスを起動する。
背景の処理は、API server に同居させず、worker のプロセスで実行する。
worker は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
worker/
├─ jobs/
│  └─ <job>        core API の operation を呼び出す。
├─ queue           単一の DB を土台に job を取り出す runner。
├─ schedule        定期実行を DB の lock で単一プロセスに絞る runner。
└─ composition     core の埋め込み・配線・起動。
```

`jobs` は、1 job を1ファイルに置く。
`queue` は、job を取り出す runner である。
`schedule` は、定期実行を起動する runner である。
`composition` は単一の組立点である。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が jobs・queue・schedule を組み立て、core を埋め込む。
jobs・queue・schedule は、composition を参照しない。
worker の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## job と application

job は、core の公開 API だけを呼び出す。
libs の port の配線と駆動は、[core/composition](../../core/composition.md) に閉じる。
job は、業務判断を持たず、配線された処理を呼ぶだけである。
job は、queue や schedule の機構の型を core へ持ち込まず、core API の operation へ写像する。
worker は、派生読みモデルの定常・定期の再構築 workflow を job として起動する役割を担う。

## queue と schedule

queue runner は、queue から実行可能な job を取り出して起動する。
schedule runner は、定期実行の時点に達した job を起動する。
長期にわたる stateful な workflow は、標準の対象外とする。
queue と schedule の engine は、project の選択の対象でなく、[tools](../../../tools/) が固定する。
並行度、順序、排他、背圧、durable receipt、ack、processing completion、冪等な確定、再配送、失敗の隔離は、[concerns/concurrency](../../../concerns/concurrency/README.md)、[concerns/messaging](../../../concerns/messaging/README.md)、[concerns/resilience](../../../concerns/resilience/README.md)、[concerns/transaction](../../../concerns/transaction/README.md) に従う。

## 組み立てと起動

composition は、build_core で core を埋め込み、自身でプロセスを起動する。
queue と schedule の runner は、job context の発行元、対象、完全性、有効性を認証境界で検証し、actor を一度だけ構築する。
job は actor または資格情報を payload から受け取らず、認証境界が構築した actor と検証済み入力だけを core の公開 API へ渡す。
資格情報、job context に含まれる認証素材、queue と schedule の認証方式の型を、core の公開 API へ渡さない。
worker は、生存と準備の面を公開する。
lifecycle の規律は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。
観測の規律は [concerns/observability](../../../concerns/observability/README.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration/README.md) に従う。
queue と schedule の機構は [tools](../../../tools/) が定める。
