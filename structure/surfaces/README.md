# surfaces

surface は、対話様式ごとの入口である。
[skeleton](../skeleton.md) の surfaces 直下の境界に対応する。

## 構成

| surface | 種別 | 対話様式 | ファイル |
|---|---|---|---|
| [server](./server/layout.md) | 自己ホスト | API | layout |
| [console](./console/layout.md) | 自己ホスト | CLI | layout |
| [worker](./worker/layout.md) | 自己ホスト | 背景処理・定期実行 | layout |
| [viewer](./viewer/layout.md) | 被ホスト | GUI | layout・state・styling |
| [extension](./extension/layout.md) | 被ホスト | 拡張 | layout |
| [embedded](./embedded/layout.md) | 埋め込み | protocol | layout |

## 共通の形

各 surface は、layout がフォルダ構成・依存方向・固有の規律を持つ。
末端は、1ファイルを1概念に対応させる。
組立点は単一である。
server・console・worker・extension・embedded では composition が、viewer では app が組立点を担う。
app は、viewer における composition root の別名である。
入口は、業務判断を持たず、入力を build_core が返す core API、remote API、または protocol の operation へ写像する。
core を埋め込む surface は、[concerns/authentication](../../concerns/authentication.md) に従って認証境界で資格情報を検証し、actor を構築する。
core の公開 API へは actor と検証済み入力だけを渡し、資格情報と認証方式の型を渡さない。
自己ホストの surface は、core を埋め込み、自身でプロセスを起動する。
埋め込みの surface は、core を埋め込み protocol を公開し、host が同梱して起動する。
被ホストの surface は、host に求める能力を port として定義し、host が実装を注入する。
被ホストの surface は、actor と資格情報を構築せず、server、埋め込み surface、または host の認証境界へ委ねる。
被ホストの viewer は複数の host から共有され、extension が UI を持つ場合は ide が viewer も併せてホストする。
surface の中に、host の分岐を置かない。
