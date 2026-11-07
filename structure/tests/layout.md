# tests の構造

tests は、ターゲットプロジェクトの root の規模の検証を収める。
テストは、技法の名前ではなく、実際に使う依存と size 別 runner が許可する資源でサイズを決める。
root の tests では技法ごとの区画の下を実測サイズで分ける。
何をどの技法で検証するかは [methods](./methods.md) に従う。
ダブルとフィクスチャの扱いは [doubles](./doubles.md) に従う。
tests は [skeleton](../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
tests/
├─ integration/
│  └─ <small|medium|large>/
├─ contract/
│  └─ <small|medium|large>/
├─ conformance/
│  └─ <small|medium|large>/
├─ arch/
│  └─ <small|medium|large>/
├─ e2e/
│  └─ <small|medium|large>/
└─ performance/
   └─ <small|medium|large>/
```

## 区画の役割

conformance は、業務の語彙で書いた Gherkin の executable spec を、公開された interface を越して検証する。
適合は、シナリオの合否で判定し、点数化しない。
contract は、[contracts/canonical](../contracts/canonical.md) の契約定義を駆動元として検証する。
generated が canonical と binding(http・protocol)から外れていないことを、drift の検査で確かめる。
生成物の契約の表現と未知項目の扱いの検査は [methods](./methods.md) の「性質別の技法」に従い、drift の一致だけで生成能力の充足とみなさない。
arch は、[skeleton](../skeleton.md) と各部の layout、[concerns/dependency](../../concerns/dependency/README.md) が定める依存と境界の禁止を、機械で検証する。
arch の検査は repository の source と manifest を読むため、hermetic でなければ Medium に置き、実行する段は [process/verification](../../process/verification.md) が定める。
viewer と extension が特定 host の API や型を参照しないことも、arch で検証する。
コンテキスト間の参加操作への接続は、[core/application](../core/application.md) と [core/layout](../core/layout.md) に照らし、組立点以外のコンテキスト間参照と内部の型への到達を arch で拒む。
shared-kernel の型に要求する意味と変更理由の同一性は、記録と型の対応を機械で照合し、共有する意味の適否をレビューで判定する。
e2e は、公開入口から実際の構成を通した結果のうち、他の検査で保証していない性質を検証し、critical path の smoke と visual だけに限定しない。
同じ計算の組合せを重ねず、他の検査へ移す性質と入力領域について、移管先が対象の不具合を実際に検出する証拠を [methods](./methods.md) の「テストの有効性」に従って確認する。
利用者面の操作ごとに状態、feedback、progress が表示されるまでの時間を browser を駆動して測る検証は、e2e に置かず integration に置く。
smoke の到達点と visual の受入判定は、[methods](./methods.md) の「利用者面の受入」に従う。
integration は、複数の実装単位または境界を組み合わせて検証する。
検証の重みは、公開 interface 越しのuse-caseの検証に置き、内側の個別のテストは型と契約の保証で減らす([principles/verification](../../principles/verification/README.md) に従う)。
performance は、固定した workload と環境で SLO を計測し、変更前後の比較から退行を判定する。
SLO の計測は、機能の合否を判定する test と同じ区画に混ぜない。
performance の区画の test は size 別 runner の機能の test の集合から除き、計測の入口が実依存の size の資源で実行する。

## 実行可能な仕様

業務の受入条件は、Gherkin の feature と scenario に、前提、操作、外から観測できる結果を業務の語彙で表す。
実装の class、DB の列、UI のクリック手順を、業務の仕様の語彙にしない。
成功だけでなく、業務上の拒否と、結果を変える境界条件を scenario へ含める。
テストを作る前に scenario の期待結果を確定し、仕様の変更と実装の追随を同じ変更理由で扱う。
既存機能の修正では該当する feature と scenario を更新し、修正専用の仕様を別ファイルへ重複させない。
通信失敗時の入力保持など、業務仕様ではない基本品質は対応するテストで保証し、その確認だけを目的として業務の feature や scenario を増やさない。
scenario は言語固有の step binding から公開 interface を検証し、記法を揃えることと、実行や保証を実現する機構を同じにすることを混同しない。
業務語彙の scenario は、検証する公開 interface を所有する実装単位の言語の実行系で一度だけ実行し、同じ scenario を別の言語の実行系で重ねて実行しない。
実行系と feature、step binding、公開 interface の対応検査は [languages](../../languages/) が定め、仕様の実行を repository の検証入口へ含める。
UI の smoke と visual は、業務の仕様の代替にしない。

## サイズによる配置

テストを、実際に使う依存の範囲で Small・Medium・Large に分ける。
Small は、同一プロセス内で完結し、filesystem・socket・network・別プロセスへ依存しない hermetic なテストとする。
Medium は、filesystem、Unix socket、localhost、local の既存プロセス・container・browser・service のいずれかへ依存するテストとする。
Large は、local host の外にある資源または本番相当の外部環境へ依存するテストとする。
複数の依存を持つテストは、最も大きい依存のサイズへ分類する。
integration、contract、conformance、arch、e2e、performance という技法の名前から、サイズを決めない。
conformance は、hermetic に同一プロセスで完結すれば Small、local host の資源を使えば Medium、local host の外または本番相当の外部環境を使えば Large に置く。
e2e も、hermetic に同一プロセスで完結すれば Small、local host の資源に閉じれば Medium、local host の外または本番相当の外部環境を使えば Large に置く。
root の tests に置く検証は、技法の区画の下に実依存と一致する `<small|medium|large>/` を置く。
hermetic に同一プロセスで完結する unit と property は、対象のコードと同じ場所に置く。
一つの adapter に閉じるテストは、その adapter の近傍の `tests/<small|medium|large>/` に置く。
複数の境界をまたぐテストは、技法と実測サイズに従って root の tests に置く。
Small runner は、同一 process 内の hermetic な実行に必要な資源だけを提供する。
Medium runner は、local host に閉じた資源だけを提供する。
Large runner は、local host の資源と、対象として明示した外部資源を提供する。
資源の用意と接続許可は、同じ size の runner 設定に一度だけ置き、test ごとの台帳へ重複させない。
検証対象のプロセスは、その成果物の公開入口と設定で起動し、配備 script を起動部品として使わない。
ローカルの datastore などを使うことと、deploy のコードや資材へ依存することを区別する。
size 別 runner の対象は、各言語の test runner が discovery で返す native test ID の集合で定義する。
同じ native test ID を複数の size へ含めない。
parameterized case、doctest、生成した executable spec は、runner が個別に返す ID をそのまま用いる。
各走行で実行する native test ID を影響範囲から選び、実行結果の集合を選択した集合と一致させる。
未選択の ID を実行済みとせず、選択結果をその size の全域 discovery の完了と同一視しない。
その size の区画を置いた場合に、発見件数が0件なら失敗する。
size 別 runner は、許可していない filesystem・socket・network・process を実行環境で到達不能にし、接続を試みた test を失敗させる。
Small の test は、実行開始後に filesystem、socket、network、別 process へ到達できない環境で動かす。
Small の fixture は、test binary または test process の値として読み込み前に組み込み、test 本体から repository や一時領域を読まない。
Medium の実行環境は task が用意した local host の資源だけを提供し、外部 network への経路を持たない。
Large の実行環境は、対象として記録した外部資源だけを接続許可に加える。
全 size の機能の test の discovery 集合と performance の区画の discovery 集合の和は、filter をかけない全域 discovery の native test ID 集合と一致させる。
未分類の ID、複数 size に属する ID、配置より大きい資源を必要とした test、対象に記録していない外部資源へ接続した test は失敗する。
サイズは資源の分類であり、所要時間や承認する段を決めるものではない。
公開振る舞いの Small test を厚くし、実依存でしか観測できない性質は必要なサイズで検証する。
遅い検査の件数を減らすために、必要な実観測を省いたり fake へ替えたりしない。

test が存在しない category・size の区画のフォルダは、作らない。

## 段階実行

実行の順序と失敗時の停止は、[process/verification](../../process/verification.md) が定める。
選択した test は、実依存と配置に対応した資源を許可する runner で実行する。
conformance と e2e の実行時点も、サイズだけでなく必要な保証と有効な証跡から決める。


## タスク実行の正本

検証と release の手順は、単一の正本として root のタスク定義に集約する。
外部の検証サービスがファイルの置き場を強制する場合、その置き場には正本を呼ぶ最小の起動だけを置く。
タスクを編成する orchestrator の採用は、[tools/build](../../tools/build/README.md) が定める。

## 依存方向

tests のソース依存と成果物の消費は [skeleton](../skeleton.md) の build・test-only 依存表と成果物の消費表に従う。
libs の Testing package への依存は、skeleton の build・test-only 依存表に従う。
他の root の code は、tests を参照しない。
