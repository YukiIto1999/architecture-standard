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
└─ e2e/
   └─ <small|medium|large>/
```

## 区画の役割

conformance は、業務の語彙で書いた Gherkin の executable spec を、公開された interface を越して検証する。
適合は、シナリオの合否で判定し、点数化しない。
contract は、[contracts/canonical](../contracts/canonical.md) の契約定義を駆動元として検証する。
generated が canonical と binding(http・protocol)から外れていないことを、drift の検査で確かめる。
arch は、[skeleton](../skeleton.md) と各部の layout、[concerns/dependency](../../concerns/dependency/README.md) が定める依存と境界の禁止を、機械で検証する。
viewer と extension が特定 host の API や型を参照しないことも、arch で検証する。
e2e は、critical path の最小の smoke と visual だけに絞る。
integration は、複数の実装単位または境界を組み合わせて検証する。
検証の重みは、公開 interface 越しのuse-caseの検証に置き、内側の個別のテストは型と契約の保証で減らす([principles/verification](../../principles/verification/README.md) に従う)。

## サイズによる配置

テストを、実際に使う依存の範囲で Small・Medium・Large に分ける。
Small は、同一プロセス内で完結し、filesystem・socket・network・別プロセスへ依存しない hermetic なテストとする。
Medium は、filesystem、Unix socket、localhost、local の既存プロセス・container・browser・service のいずれかへ依存するテストとする。
Large は、local host の外にある資源または本番相当の外部環境へ依存するテストとする。
複数の依存を持つテストは、最も大きい依存のサイズへ分類する。
integration、contract、conformance、arch、e2e という技法の名前から、サイズを決めない。
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
size 別 runner の対象は、各言語の test runner が discovery で返す native test ID の集合で定義する。
同じ native test ID を複数の size へ含めない。
parameterized case、doctest、生成した executable spec は、runner が個別に返す ID をそのまま用いる。
各 size の実行結果が返す native test ID の集合を、その size の discovery 集合と一致させ、発見件数が0件なら失敗する。
size 別 runner は、許可していない filesystem・socket・network・process を実行環境で到達不能にし、接続を試みた test を失敗させる。
Small の test は、実行開始後に filesystem、socket、network、別 process へ到達できない環境で動かす。
Small の fixture は、test binary または test process の値として読み込み前に組み込み、test 本体から repository や一時領域を読まない。
Medium の実行環境は task が用意した local host の資源だけを提供し、外部 network への経路を持たない。
Large の実行環境は、対象として記録した外部資源だけを接続許可に加える。
全 size の discovery 集合の和は、filter をかけない全域 discovery の native test ID 集合と一致させる。
未分類の ID、複数 size に属する ID、配置より大きい資源を必要とした test、対象に記録していない外部資源へ接続した test は失敗する。
サイズを分けても、各段が個別に肥大すれば配分は崩れる。
厚みは Small に置き、上の段は絞る([principles/verification](../../principles/verification/README.md) に従う)。

test が存在しない category・size の区画のフォルダは、作らない。

## 段階実行

実行の順序と失敗時の停止は、[process/verification](../../process/verification.md) が定める。
各段は、runner が許可する資源と配置が一致した test を選ぶ。
conformance と e2e も、実依存に対応する段で実行する。


## タスク実行の正本

検証と release の手順は、単一の正本として root のタスク定義に集約する。
外部の検証サービスがファイルの置き場を強制する場合、その置き場には正本を呼ぶ最小の起動だけを置く。
タスクを編成する orchestrator の採用は、[tools/build](../../tools/build/README.md) が定める。

## 依存方向

tests の実行時依存は [skeleton](../skeleton.md) の実行時依存表に従う。
libs の Testing package への依存は、skeleton の build・test-only 依存表に従う。
production の code は、tests を参照しない。
