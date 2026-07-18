# tests の構造

tests は、ターゲットプロジェクトの root の規模の検証を収める。
テストは、サイズで配置を分ける。
サイズは、プロセスの外への依存の範囲で決まる。
何をどの技法で検証するかは [methods](./methods.md) に従う。
ダブルとフィクスチャの扱いは [doubles](./doubles.md) に従う。
tests は [skeleton](../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
tests/
├─ integration/   実依存をコンテナで起動する Medium。
├─ contract/      canonical と generated の適合と drift の検査。
├─ conformance/   公開 interface 越しの executable spec。
├─ arch/          依存方向と構造制約の機械検証。
└─ e2e/           critical path の最小 smoke と visual。
```

## 区画の役割

conformance は、業務の語彙で書いた Gherkin の executable spec を、公開された interface を越して検証する。
適合は、シナリオの合否で判定し、点数化しない。
contract は、[contracts/canonical](../contracts/canonical.md) の TypeSpec を駆動元として検証する。
generated が canonical と binding(http・protocol)から外れていないことを、drift の検査で確かめる。
arch は、[skeleton](../skeleton.md) と各部の layout、[concerns/dependency](../../concerns/dependency.md) が定める依存と境界の禁止を、機械で検証する。
viewer と extension が特定 host の API や型を参照しないことも、arch で検証する。
e2e は、critical path の最小の smoke と visual だけに絞る。
integration は、localhost の中に閉じる Medium のうち、複数の境界をまたぐものを集める。
検証の重みは、公開 interface 越しのユースケースの検証に置き、内側の個別のテストは型と契約の保証で減らす([principles/verification](../../principles/verification.md) に従う)。

## サイズによる配置

テストを、プロセスの外への依存の範囲で Small・Medium・Large に分ける。
Small は、プロセスの外への依存を持たない。arch と contract、および unit と property がこれにあたる。
Medium は、localhost の中に閉じる。実依存をコンテナで起動する integration と、公開 interface 越しの conformance がこれにあたる。
Large は、本番と同等の環境を要する。critical path の e2e がこれにあたる。
Small の unit と property は、対象のコードと同じ場所に置く。
一つの adapter に閉じる Medium は、その adapter の近傍に置く。
複数の境界をまたぐ Medium と、arch・contract・conformance、および Large の e2e は、root の tests/ に置く。
サイズを分けても、各段が個別に肥大すれば配分は崩れる。
厚みは Small に置き、上の段は絞る([principles/verification](../../principles/verification.md) に従う)。

## 段階実行

検証は、Small・Medium・Large の順で実行する。
前の段が落ちたら、後の段を実行しない。
arch と contract は Small の段、integration と conformance は Medium の段、e2e は Large の段で走る。

## 依存方向

tests の依存は [skeleton](../skeleton.md) の依存方向表に従う。
production の code は、tests を参照しない。
