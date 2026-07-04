# console の構造

console は、CLI の surface である。
core を埋め込み、コマンドの引数を use-case へ写像する。
自己ホストであり、自身でプロセスを起動する。
console は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
console/
├─ commands/
│  └─ <command>     引数を use-case へ写像する。
└─ composition      core の埋め込み・設定の読み込み・起動。
```

`commands` は、1 command を1ファイルに置く。
`composition` は単一の組立点である。

## 依存方向

依存は一方向に保つ。
composition が commands を組み立て、core を埋め込む。
commands は composition を参照しない。
console の外との依存は [skeleton](../../skeleton.md) に従う。
依存方向の規律は [concerns/dependency](../../../concerns/dependency.md) に従う。

## 入口とコマンド

command は、引数を use-case へ写像する。
command は、業務判断を持たず、入力の解析と use-case の呼び出しだけを行う。
console は wire の binding を持たず、外部へ面を公開しない。
console は、派生読みモデルの臨時・手動の再構築 operation を command として起動する役割を担う。
引数の解析の機構は [languages](../../../languages/) に従う。

## 配布

console は、単一の配布 channel で配布する。
更新は channel に任せる。
self-update は、標準外とする。

## 組み立てと起動

composition は、build_core で core を埋め込み、自身でプロセスを起動する。
composition は、実行の文脈を request context として組み立て、core へ渡す。
actor への写像は [structure/core/composition](../../core/composition.md) が担う。
停止の合図を受けたら、進行中の処理を協調して止めて終わる。
終了の規律は [concerns/lifecycle](../../../concerns/lifecycle.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration.md) に従う。
