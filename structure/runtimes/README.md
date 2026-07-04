# runtimes

runtime は、被ホストの surface をホストする具体の host である。
ターゲットの runtimes/ 直下は、具体の host 名で命名する。
本書の web・desktop・mobile・ide は、host の種類を表す見出しである。

## 構成

| host | ホストする面 | platform |
|---|---|---|
| [web](./web/layout.md) | viewer | browser |
| [desktop](./desktop/layout.md) | viewer | native の shell |
| [mobile](./mobile/layout.md) | viewer | mobile の shell |
| [ide](./ide/layout.md) | extension。UI を持つ場合は viewer も | IDE |

## 共通の形

4つの host は、adapters と composition の2単位という意味で同形である。
core を埋め込むかは、host ごとに layout が定める。
adapters が、surface の定義する port を platform の API で実装する。
1 port を、1ファイルとして実装する。
composition が、port を注入し、surface を起動する。
runtime は、surface の公開する port と起動の入口だけに依存し、内部へ踏み込まない。
runtime どうしは、互いを参照しない。
同じ surface をホストする別の runtime は、surface への依存として並列に表す。
