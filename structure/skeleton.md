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
│  ├─ generated/
│  └─ adapters/
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
contracts は canonical を常に持ち、http・protocol は通信の関心があるときに、generated は canonical の契約を code から使うときに、adapters は契約を core の公開 application 入口へ接続するときに置く。
server・console・worker・viewer・extension の surface は、surfaces の直下に、対応する関心があるときに置く。
runtimes・deploy は、対応する関心があるときに置く。
libs は、対応する機構があるときに置く。

schema migration の artifact の所有と置き場は [core/infrastructure](./core/infrastructure.md) の「永続化」に従い、全コンテキストの DDL をまとめる root の `migrations/` は置かない。
集合を適用する配備の計画は [deploy](./deploy/layout.md) の delivery に置き、artifact の所有と分ける。

| 境界 | 役割 |
|---|---|
| core | 業務と外部依存の adapter を内包する。媒体を知らない。 |
| libs | 業務非依存の技術基盤と、言語・library・framework の不足を補う機構を収める。core の子ではなく、各消費側が公開 API を直接使う。 |
| contracts | 公開契約を canonical・http・protocol・generated に分け、adapters で core の公開 application 入口へ接続する。 |
| surfaces | 対話様式ごとの入口を束ねる。直下に server・console・worker・viewer・extension・埋め込み surface を置く。 |
| server | API の surface。core を埋め込み、http を公開する。Web BFF を提供する場合は、token を仲介する。 |
| console | CLI の surface。core を埋め込む。 |
| worker | 背景処理・定期実行の surface。core を埋め込む。 |
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

依存方向の規律は [concerns/dependency](../concerns/dependency/README.md) に従う。

production のソースコードが持つ root またぎ依存は、次の表に従う。
参照先の公開面だけを使い、同じ repository 内でも package の内部へ到達しない。

| 境界 | 依存してよい先 |
|---|---|
| core | libs |
| libs | 他の libs の機構の公開 domain・application |
| contracts/adapters | core の公開 API・libs・contracts/generated のデータ型 |
| contracts/generated | libs |
| server | core・libs・contracts/adapters の公開 API・contracts/generated のデータ型 |
| console・worker | core・libs・contracts/adapters の公開 API・contracts/generated のデータ型 |
| 埋め込み surface | core・libs・contracts/adapters の公開 API・contracts/generated のデータ型と protocol の提供側 stub |
| viewer | libs・contracts/generated の型 |
| extension の remote | libs・contracts/generated の型 |
| extension の local | libs・contracts/generated のデータ型 |
| extension(UI を持つ場合) | viewer の公開 API |
| runtimes/\<host\> | libs・対応する surface・その host の API・port の実装に用いる contracts/generated のデータ型と通信 client・stub・core を埋め込む場合は core と contracts/adapters の公開 API・その host が HTTP surface を自己ホストする場合は同じ core を埋め込む自己ホスト surface の routes |
| deploy | 配備の機構に用いる libs の公開 API |

core は composition を含め、contracts・surface・runtime・deploy・tests を参照しない。
libs は libs 以外の root を参照せず、機構間の公開面と循環の禁止は [libs](./libs/layout.md) に従う。
deploy と tests は、他の root のソースコードの依存先にしない。
contracts/canonical・http・protocol は、生成と契約検査の入力であり、実行時に import するコードの依存先ではない。
contracts/toolchain は生成を実行する build-only package 群であり、製品の runtime と型検査の依存先にしない。
データ型と通信 client・stub の依存単位の分離は [contracts/generated](./contracts/generated.md) に従う。
公開契約と core の application 入出力の写像は [contracts/adapters](./contracts/adapters.md) が所有する。

build と test にだけ存在してよい root またぎ依存は、次の表に従う。

| 参照元 | 依存してよい先 |
|---|---|
| 全ての境界の build | libs の compile-time tool package |
| root tests | core・libs・contracts・surfaces・runtimes の公開面 |
| root tests・各境界内の test package | libs の mechanism testing package |
| 契約を検査する test package | contracts/canonical・http・protocol |

test の依存を production の依存表へ混ぜない。
test は deploy の script・設定・secret を実行部品として import、組み込み、呼び出しで再利用しない。
配備定義や依存の構造を検査対象として読むことは、実行部品としての依存と区別する。

core・surface・runtime は、必要な libs の公開 API を直接 import し、依存を自分の package で宣言する。
libs の利用は core の埋め込みを条件にせず、core や別の surface を経由した再公開を要求しない。
core と surface の公開 API が運ぶ libs の型(Result・Effect)を使う境界も、その機構へ直接依存する。
libs の公開面と adapter 構築用 API の利用範囲は [libs](./libs/layout.md) に従う。
canonical operation を HTTP へ束ねる写像の正本は contracts の http であり、自己ホスト surface の routes はその写像を実装する。
runtime がその HTTP surface を自己ホストする場合は routes を参照し、同じ写像を二重に作らない。
HTTP を持たず core を埋め込む構成には、routes を要求せず、公開契約を持つ port は contracts/adapters を通して接続する。

| 成果物の消費元 | 消費してよい成果物 |
|---|---|
| deploy | 配備対象の surface・runtime の成果物、core・libs・採用依存が公開する schema migration の artifact と適用時の設定 |
| 埋め込み surface を同梱する runtime | 対応する埋め込み surface の成果物 |
| root tests | 検証対象の成果物 |

成果物の消費はソースコードへの import と区別し、配備や同梱起動の入力として明示する。
localhost の service、filesystem、container への接続もソース依存と区別し、test の実行資源は [tests/layout](./tests/layout.md) に従う。
production のソース依存表、build・test-only 依存表、成果物の消費表が、root またぎ依存の機械検証の駆動元である。
表に無い参照元から参照先への root またぎ依存は、禁止とする。
root の arch test は、ソース参照の runtime・build・test の phase と、成果物の消費を区別して検査する。
各表から種類と phase ごとの許可 edge を生成し、言語別の検査は [languages](../languages/) の inspection が定める。
build または test のソース依存が production の成果物へ混入した場合は、失敗する。

contracts 内部の層間の依存は [contracts](./contracts/layout.md) に従う。
contracts/generated の生成と利用は [contracts/generated](./contracts/generated.md) に従う。
host は、surface の port を、generated の通信 client・stub または core の埋め込みで実装する。
core を埋め込む host は core を組み立て、contracts/adapters を通して port の入出力を公開 application 入口へ接続する。
extension は、core を直接埋め込まない。
extension の local の関心は、core を埋め込んだ別プロセスへ、言語非依存の protocol で接続する。
そのプロセスは、対応する runtime が同梱して起動する。
extension が UI を持つ場合は viewer を再利用し、対応する host が viewer もホストして ui port を注入する。
自己ホスト surface が持つ一時 store の置き場は、各 surface の layout が定める。

## workspace

root は、言語ごとの package を集めた polyglot の monorepo である。
各コード境界は、その言語の package として workspace に属する。
package の境界は、依存方向の規律で守る。
build は、言語ごとの package を横断する task graph を orchestrator で実行する。
orchestrator は task graph の順序、affected の選択、cache だけを担い、package の依存境界を強制しない。
orchestrator の採用と選定の判断基準は、[tools/build/nx](../tools/build/nx.md) が定める。
package の依存境界は、依存方向の各表を入力にした言語別の root arch test で強制する。

## 加算

境界の展開は [principles/construction](../principles/construction/simplicity-by-default.md) の「単純な形を既定にする」と [no-speculation](../principles/construction/no-speculation.md) の「投機的で説明できない要素を作らない」に、分割の契機は [principles/separation](../principles/separation/split-by-change-reason.md) の「変更理由で分ける」に従う。
媒体の追加は加算で行い、既存の core と server を変えない。
surface の追加は、surfaces の直下に閉じ、root を変えない。
