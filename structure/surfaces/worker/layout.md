# worker の構造

worker は、背景処理と定期実行の daemon の surface である。
core を埋め込み、job を use-case へ写像する。
自己ホストであり、自身でプロセスを起動する。
背景の処理は、API server に同居させず、worker のプロセスで実行する。
worker は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
worker/
├─ jobs/
│  └─ <job>        use-case を呼び出す。
├─ queue           単一の DB を土台に job を取り出す runner。
├─ schedule        定期実行を DB の lock で単一プロセスに絞る runner。
└─ composition     core の埋め込み・配線・起動。
```

`jobs` は、1 job を1ファイルに置く。
`queue` は、job を取り出す runner である。
`schedule` は、定期実行を起動する runner である。
`composition` は単一の組立点である。

## 依存方向

依存は一方向に保つ。
composition が jobs・queue・schedule を組み立て、core を埋め込む。
jobs・queue・schedule は、composition を参照しない。
worker の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## job と use-case

job は、core の use-case か、composition が libs の機構の port へ駆動する operation を呼び出す。
job は、業務判断を持たず、配線された処理を呼ぶだけである。
job は、queue や schedule の機構の型を core へ持ち込まず、use-case の入力へ写像する。
job は、command の識別子を冪等キーとして持ち、冪等に実行する。
worker は、派生読みモデルの定常・定期の再構築 operation を job として起動する役割を担う。

## queue と schedule

queue は、単一の DB を土台に job を一つずつ取り出し、取り出しを排他で直列化する。
outbox からの読み出しと配送、派生読みモデルへの駆動も、この queue runner が単一の DB を土台に担う。
queue は、取り出しの前に準備の判定を確かめる。
schedule は、定期実行を DB の lock で単一のプロセスに絞る。
queue と schedule は、外部の broker を必要としない。
長期にわたる stateful な workflow は、標準の対象外とする。
queue と schedule の engine は、project の選択の対象でなく、languages が固定する。
書き込みパスの規律は [concerns/transaction](../../../concerns/transaction.md)、配送は [concerns/messaging](../../../concerns/messaging.md)、冪等性と再実行は [concerns/resilience](../../../concerns/resilience.md) に従う。

## 失敗の隔離

上限・分類・記録の規律は [concerns/resilience](../../../concerns/resilience.md) に従う。
上限まで失敗した job と、恒久的な失敗と分類した job は、queue から除き、archive の表へ移す。

## 組み立てと起動

composition は、build_core で core を埋め込み、自身でプロセスを起動する。
composition は、job の文脈を request context として組み立て、core へ渡す。
actor への写像は [structure/core/composition](../../core/composition.md) が担う。
worker は、生存と準備の面を公開する。
期限の中で終わらない job は、queue へ返す。
lifecycle の規律は [concerns/lifecycle](../../../concerns/lifecycle.md) に従う。
観測の規律は [concerns/observability](../../../concerns/observability.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration.md) に従う。
queue と schedule の機構は [languages](../../../languages/) が定める。
