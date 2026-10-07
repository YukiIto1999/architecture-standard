# runtimes

runtime は、被ホストの surface をホストする具体の host である。
ターゲットの runtimes/ 直下は、具体の host 名で命名する。
本書の web・desktop・mobile・ide は、host の種類を表す見出しである。

## 構成

| host | ホストする面 | platform | ファイル |
|---|---|---|---|
| [web](./web/layout.md) | viewer | browser | layout |
| [desktop](./desktop/layout.md) | viewer | native の shell | layout |
| [mobile](./mobile/layout.md) | viewer | mobile の shell | layout |
| [ide](./ide/layout.md) | extension。UI を持つ場合は viewer も | IDE | layout |

## 共通の形

4つの host は、adapters と composition の2単位という意味で同形である。
core を埋め込むかは、host ごとに layout が定める。
adapters が、surface の定義する port を platform の API で実装する。
1 port を、1ファイルとして実装する。
composition が、port を注入し、surface を起動する。
runtime は、surface の公開する port と起動の入口に依存し、surface の内部へ踏み込まない。
runtime は、技術基盤が必要な場合に [libs](../libs/layout.md) の公開 API を直接使い、その機構への依存を自分の package で宣言する。
この利用は core の埋め込みと無関係であり、surface や core を経由した再公開を要求しない。
libs の利用範囲は [skeleton](../skeleton.md) の実行時依存表と libs の公開面に従う。
[skeleton](../skeleton.md) の実行時依存表が host に core の埋め込みを許す場合に限り、runtime は core に直接依存してよい。
core を埋め込まない runtime は core に直接依存しない。
core を埋め込む runtime は、generated のデータ型を使う core の公開 operation を port の実装として surface へ注入する。
runtime は canonical や binding のスキーマを実行時に import せず、core の内部のコンテキスト型を port へ露出しない。
HTTP を持たず core の公開 operation を直接渡す構成は、server の routes に依存しない。
runtime どうしは、互いを参照しない。
同じ surface をホストする別の runtime は、surface への依存として並列に表す。
