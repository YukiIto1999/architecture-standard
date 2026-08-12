# skeleton

skeleton は、ターゲットプロジェクトの root の構造を定める。
関心は、アクターと変更理由で分ける。
対話様式の入口は、surfaces の直下に第一級の境界として置く。
gui・hosts のような技術カテゴリの箱を作らない。
surfaces は、対話様式というアクターの軸で束ねており、技術カテゴリの箱ではない。

## root 構成

```
<project>/
├─ core/
├─ libs/
├─ contracts/
│  ├─ canonical/
│  ├─ http/
│  ├─ protocol/
│  └─ generated/
├─ surfaces/
│  ├─ server/
│  ├─ console/
│  ├─ worker/
│  ├─ viewer/
│  ├─ extension/
│  └─ <embedded>/
├─ runtimes/
├─ deploy/
└─ tests/
```

上は、実行時とビルドのコード境界の最大構成である。
core・contracts・tests は、常に置く。
contracts は canonical を常に持ち、http・protocol・generated は通信の関心があるときに置く。
server・console・worker・viewer・extension の surface は、surfaces の直下に、対応する関心があるときに置く。
runtimes・deploy は、対応する関心があるときに置く。
libs は、対応する機構があるときに置く。

| 境界 | 役割 |
|---|---|
| core | 業務と外部依存の adapter を内包する。媒体を知らない。 |
| libs | 言語拡張と技術基盤の機構を収める。機構は業務を参照しない。 |
| contracts | 契約を canonical・http・protocol・generated に分ける。 |
| surfaces | 対話様式ごとの入口を束ねる。直下に server・console・worker・viewer・extension・埋め込み surface を置く。 |
| server | API の surface。core を埋め込み、http を公開し、token を仲介する。 |
| console | CLI の surface。core を埋め込む。 |
| worker | 背景処理・定期実行の daemon。core を埋め込む。 |
| viewer | GUI の surface。被ホストで、host は runtimes に置く。 |
| extension | 拡張の surface。被ホストで、host は runtimes に置く。core は埋め込まない。 |
| 埋め込み surface | core を埋め込み protocol を公開する surface。host が同梱起動する。 |
| runtimes | 被ホストの surface の具体 host。 |
| deploy | 配備。IaC・GitOps・provenance。 |
| tests | root の規模のテスト。境界・依存方向・契約の drift・conformance。 |

core の内部は [core](./core/layout.md)、libs の内部は [libs](./libs/layout.md)、contracts の内部は [contracts](./contracts/layout.md)、tests の内部は [tests](./tests/layout.md) に従う。
surfaces の内部は [server](./surfaces/server/layout.md)・[console](./surfaces/console/layout.md)・[worker](./surfaces/worker/layout.md)・[viewer](./surfaces/viewer/layout.md)・[extension](./surfaces/extension/layout.md)・[embedded](./surfaces/embedded/layout.md) に従う。
runtimes の内部は [runtimes](./runtimes/README.md) に、deploy の内部は [deploy](./deploy/layout.md) に従う。

## 入口の命名

surfaces の入口は、抽象的な対話様式で命名する。
server は API、console は CLI、worker は背景処理、viewer は GUI、extension は拡張を表す。
runtimes の中は、具体的なランタイムやプラットフォームの名で命名する。
surfaces と runtimes で、同じ名を並べない。

## 自己ホストと被ホスト

自己ホストの surface は、それ自身がプロセスとして走る。
server・console・worker は core を埋め込み、root で自己完結する。
自己ホストの surface に、runtimes のエントリを作らない。
被ホストの surface は、host の中でだけ走る。
viewer と extension は、それぞれ surfaces に surface を置き、具体 host を runtimes に置く。
一つの surface は、複数の host から共有される。
host の中で走る surface は、その host を runtimes に置く。
埋め込みの surface は、core を埋め込み、言語非依存の protocol を公開し、自身の runtimes エントリを持たず、同梱する host の runtime が起動する。
埋め込みの surface は、server を持たないローカル優先の構成で、被ホストの surface が core をローカルに使うときに置く。
被ホストの surface が core をローカルに使うとき、その置き方は host が core を抱けるかで決まる。
host がプロセス内に core を抱けるなら、host の runtime が core を埋め込み、port の実装として直接渡す。
別プロセスや別言語で抱けないなら、埋め込みの surface を同梱起動し、protocol で繋ぐ。
surfaces に surface として置き、protocol の対話様式を表す名で命名し、protocol の契約は contracts の protocol 層に置く。

## 依存方向

依存方向の規律は [concerns/dependency](../concerns/dependency.md) に従う。

実行時の root またぎ依存は、次の表に従う。

| 境界 | 依存してよい先 |
|---|---|
| core | libs |
| core/composition | contracts/canonical |
| libs | なし |
| server | core・contracts/canonical・contracts/http |
| console・worker | core・contracts/canonical |
| 埋め込み surface | core・contracts/canonical・contracts/protocol |
| viewer | contracts/generated の型 |
| extension の remote | contracts/generated の型 |
| extension の local | contracts/protocol と、protocol から生成した contracts/generated |
| extension(UI を持つ場合) | viewer の公開 API |
| runtimes/\<host\> | 対応する surface・その host の API・port の実装に用いる contracts/generated・core を埋め込む場合は core と contracts/canonical |
| deploy | 配備の対象となる成果物 |
| tests | 検証のために全ての境界 |

build と test にだけ存在してよい root またぎ依存は、次の表に従う。

| 参照元 | 依存してよい先 |
|---|---|
| 全ての境界の build | libs の compile-time tool package |
| root tests・各境界内の test package | libs の mechanism testing package |

実行時依存表と build・test-only 依存表が、root またぎ依存の機械検証の唯一の駆動元である。
両表に無い参照元から参照先への root またぎ依存は、すべて禁止とする。
root の arch test は、runtime・build・test の phase ごとに依存 edge を区別する。
root の arch test は、両表から phase ごとの許可 edge を生成する。
phase ごとの edge を検査する言語別の実現は、各言語の inspection が定める。
各言語の検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。

contracts 内部の層間の依存は [contracts](./contracts/layout.md) に従う。
contracts/generated は、contracts/canonical と binding(http・protocol)から生成する。
host は、surface の port を、contracts/generated の client または core の埋め込みで実装する。
core を埋め込む host は、core と contracts/canonical に依存する。
extension は、core を直接埋め込まない。
extension の local の関心は、core を埋め込んだ別プロセスへ、言語非依存の protocol で接続する。
そのプロセスは、対応する runtime が同梱して起動する。
extension が UI を持つ場合は viewer を再利用し、ide の host が viewer もホストして ui port を注入する。
contracts への依存を core で持てるのは composition だけであり、各コンテキストと shared は表の core 行に従う。
自己ホスト surface が持つ一時 store の置き場は、各 surface の layout が定める。

## workspace

root は、言語ごとの package を集めた polyglot の monorepo である。
各コード境界は、その言語の package として workspace に属する。
package の境界は、依存方向の規律で守る。
build は、言語ごとの package を横断する task graph を orchestrator で実行する。
orchestrator は task graph の順序、affected の選択、cache だけを担い、package の依存境界を強制しない。
orchestrator の採用と選定の判断基準は、[tools/build](../tools/build.md) が定める。
package の依存境界は、依存方向の両表を入力にした言語別の root arch test で強制する。

## 加算

境界の展開は [principles/construction](../principles/construction.md) の単純な形の既定と投機の排除に、分割の契機は [principles/separation](../principles/separation.md) の変更理由に従う。
媒体の追加は加算で行い、既存の core と server を変えない。
surface の追加は、surfaces の直下に閉じ、root を変えない。
