# contracts の構造

contracts のフォルダ構成と、契約の意味、binding、生成物、core への adapter の責務と依存を定める。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
各層の内部は、[canonical](./canonical.md)・[http](./http.md)・[protocol](./protocol.md)・[generated](./generated.md)・[adapters](./adapters.md) が定める。

## フォルダ構成

```
contracts/
├─ canonical/    公開契約の意味の正本。操作・型・エラー・制約。
├─ http/         HTTP の wire への binding。
├─ protocol/     ローカルの非 HTTP protocol への binding。
├─ toolchain/    生成用の build-only package・設定・template。
├─ generated/    canonical と binding からの出力。
└─ adapters/     公開契約と core の公開 application 入口の接続。
```

`canonical` は常に置く。
`http` と `protocol` は、canonical を wire へ束ねる binding であり、プロセスをまたぐ通信があるときに、その通信形式に応じて置く。
`http` は HTTP の通信に、`protocol` は webview と host の IPC や埋め込み surface との通信を含む非 HTTP のローカル通信に置く。
`generated` は、canonical の契約を code から使うすべての場合に置く。
`adapters` は、公開契約を core の公開 application 入口へ接続するときに置く。
`toolchain` は生成の実行環境と入力を持つ置き場であり、契約の意味を定める層には加えない。
公開契約を表す DTO は generated の型を使い、同じ意味の field、variant、制約を手書きで写した型を代わりに置かない。
生成物の不足は canonical、binding、生成器の責務に応じて直し、利用側に契約の第二の正本を作らない。
HTTP を持つ契約は OpenAPI 経由で client と型を、ローカル protocol を持つ契約は protocol の記述から stub と型を、いずれも持たない契約(同一プロセス・console 出力・ファイル形式)は JSON Schema 経由で型だけを、同じ `generated/` へ出す。
生成するデータ型と、通信を実行する client・stub は、別の依存単位に分ける。
protocol の記述の形式と stub の生成器は、protocol の採用とあわせて project が決定の記録に明記する。

## 生成の toolchain

独立した生成用 package と、project 固有の生成器設定、template、schema 駆動の出力処理、必要な script は、`toolchain/<stage>/` に置く。
実行用 package の manifest と、依存を固定する lock または toolchain の参照を追跡し、project 固有の生成入力とともに task の入力へ含める。
root の task graph の contracts 生成 task を利用入口とし、各 stage の command、入力、出力、生成の依存を task graph から辿れるようにする。
CLI を一度呼ぶだけの処理は task 定義から直接実行し、変換の実装を持つ script は対応する stage の package に置き、別の生成手順を並置しない。
後続 stage が前段の OpenAPI などを入力に使う場合は、前段の生成または入力に対応する有効な cache を task graph の依存で保証し、古い追跡済み出力を黙って使わない。
生成用の package は、製品の runtime と型検査の依存 closure から分離し、生成器が要求する言語版を製品の依存解決へ持ち込まない。
toolchain は canonical と binding を入力とし、契約の意味や媒体固有の写像を再定義しない。

## 層

| 層 | 役割 | 変更理由 |
|---|---|---|
| canonical | 公開契約の意味の正本 | 公開する操作・型・エラー・制約の変化 |
| http | 意味を HTTP の wire へ束ねる binding | HTTP の wire 形式の変化 |
| protocol | 意味を非 HTTP のローカル protocol へ束ねる binding | ローカル protocol の形式の変化 |
| generated | 出力。openapi・json schema・protocol の stub・各言語の client/型 | canonical と binding からの再生成 |
| adapters | 生成 DTO と core の公開 application 入出力を写像し、公開入口へ接続する | 公開契約と application の保証の対応の変化 |

## 依存方向

依存の向きは [concerns/dependency](../../concerns/dependency/README.md) に従う。

| 参照元 | 参照可 |
|---|---|
| canonical | なし |
| http | canonical |
| protocol | canonical |
| generated | canonical・binding(http・protocol) |
| adapters | generated のデータ型・core の公開 API・libs の公開 API |

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
公開契約とコンテキストの application 入出力との写像は [adapters](./adapters.md) が所有する。
