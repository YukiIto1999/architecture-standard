# contracts の構造

contracts のフォルダ構成と、契約の意味、binding、生成物の責務と依存を定める。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
各層の内部は、[canonical](./canonical.md)・[http](./http.md)・[protocol](./protocol.md)・[generated](./generated.md) で規定する。

## フォルダ構成

```
contracts/
├─ canonical/    公開契約の意味の正本。操作・型・エラー・制約。
├─ http/         HTTP の wire への binding。
├─ protocol/     ローカルの非 HTTP protocol への binding。
└─ generated/    canonical と binding からの出力。
```

`canonical` は常に置く。
`http` と `protocol` は、canonical を wire へ束ねる binding であり、プロセスをまたぐ通信があるときに、その通信形式に応じて置く。
`http` は HTTP の通信に、`protocol` は埋め込み surface との非 HTTP のローカル通信に置く。
`generated` は、canonical の契約を code から使うすべての場合に置く。
公開契約を表す DTO は generated の型を使い、同じ意味の field、variant、制約を手書きで写した型を代わりに置かない。
生成物の不足は canonical、binding、生成器の責務に応じて直し、利用側に契約の第二の正本を作らない。
生成は単一の入口(task graph の contracts 生成 task)から行い、HTTP を持つ契約は OpenAPI 経由で client と型を、ローカル protocol を持つ契約は protocol の記述から stub と型を、いずれも持たない契約(同一プロセス・console 出力・ファイル形式)は JSON Schema 経由で型だけを、同じ `generated/` へ出す。
生成するデータ型と、通信を実行する client・stub は、別の依存単位に分ける。
protocol の記述の形式と stub の生成器は、protocol の採用とあわせて project が決定の記録に明記する。

## 層

| 層 | 役割 | 変更理由 |
|---|---|---|
| canonical | 公開契約の意味の正本 | 公開する操作・型・エラー・制約の変化 |
| http | 意味を HTTP の wire へ束ねる binding | HTTP の wire 形式の変化 |
| protocol | 意味を非 HTTP のローカル protocol へ束ねる binding | ローカル protocol の形式の変化 |
| generated | 出力。openapi・json schema・protocol の stub・各言語の client/型 | canonical と binding からの再生成 |

## 依存方向

依存の向きは [concerns/dependency](../../concerns/dependency/README.md) に従う。
依存方向の規律は [concerns/dependency](../../concerns/dependency/README.md) に従う。

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

## 利用側の型との区別

canonical と binding は、生成器へ公開契約を指定する正本であり、core の業務モデルではない。
generated の DTO は、公開契約の具体的な field、variant、制約を表す。
契約を表せない汎用の map や任意の payload を、生成 DTO の代わりにしない。
runtime の未完成入力、core の検証済み・解決済みの業務状態、surface の表示状態は、公開契約とは責務または保証が異なるため、それぞれの所有者が型を持つ。
層を越えることだけを理由に別の型を作らず、その境界で必要な責務と保証を generated の型が満たすなら再利用する。
公開契約とコンテキストの application 入出力との写像は [core/composition](../core/composition.md) が定める。
