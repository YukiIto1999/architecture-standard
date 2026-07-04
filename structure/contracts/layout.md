# contracts の構造

contracts のフォルダ構成と、層間の依存・正本の規則を定める。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
各層の内部は、[canonical](./canonical.md)・[http](./http.md)・[protocol](./protocol.md)・[generated](./generated.md) で規定する。

## フォルダ構成

```
contracts/
├─ canonical/    意味の正本。操作・型・エラー。
├─ http/         HTTP の wire への binding。
├─ protocol/     ローカルの非 HTTP protocol への binding。
└─ generated/    canonical と binding からの出力。
```

`canonical` は常に置く。
`http` と `protocol` は、canonical を wire へ束ねる binding であり、プロセスをまたぐ通信があるときに、その通信形式に応じて置く。
`http` は HTTP の通信に、`protocol` は埋め込み surface との非 HTTP のローカル通信に置く。
`generated` は、別プロセスの client または型を要するときに置く。

## 層

| 層 | 役割 | 変更理由 |
|---|---|---|
| canonical | 契約の意味の正本 | 業務の操作・型・エラーの変化 |
| http | 意味を HTTP の wire へ束ねる binding | HTTP の wire 形式の変化 |
| protocol | 意味を非 HTTP のローカル protocol へ束ねる binding | ローカル protocol の形式の変化 |
| generated | 出力。openapi・json schema・protocol の stub・各言語の client/型 | canonical と binding からの再生成 |

## 依存方向

依存は一方向に保つ。
依存方向の規律は [concerns/dependency](../../concerns/dependency.md) に従う。

| 参照元 | 参照可 |
|---|---|
| canonical | なし |
| http | canonical |
| protocol | canonical |
| generated | canonical・binding(http・protocol) |

contracts の外との参照の規則は [skeleton](../skeleton.md) に従う。

## 正本

canonical だけが、契約の意味の正本である。
http・protocol と generated は、canonical を正本とする。
canonical の意味と、http・protocol・generated の表現を、二重の正本にしない。
