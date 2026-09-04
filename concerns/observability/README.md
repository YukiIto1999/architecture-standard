# observability

## 概要
observability は、外部の出力から内部の状態を推し量れる状態を全系で統べる規律である。
principles の [separation](../../principles/separation/README.md) が定める副作用の境界隔離を全系の観測として具象化し、未知の原因を運用しながら絞り込めるようにする。
carrier の正本は [context-propagation](../context-propagation/README.md) であり、observability は trace と観測 event への付与を書く。

## 規律

- [事実をイベントとして表し、構造化して出す](./structured-events.md) — 機械+レビュー(print系lint・no-console)
- [文脈を豊かに載せ、事後に問いを立て直せるようにする](./rich-context.md) — レビュー(review規律照合のみ)
- [仕込みを境界の殻で行う](./shell-instrumentation.md) — 機械+レビュー(禁止import構造検査)
- [観測は振る舞いを変えない](./non-invasive-observation.md) — レビュー(review規律照合のみ)

## 参照
業務の事実の種別は [messaging](../messaging/README.md) に従う。
観測のための技術イベントは、この概念の扱いであり messaging の種別の外である。
carrier の正本は [context-propagation](../context-propagation/README.md) であり、trace と観測 event への付与は observability が正本である。
観測に載せる個人情報の最小化と期限の消去は [privacy](../privacy/README.md) に従う。
利用者の環境で動く surface の観測の配線は [structure/surfaces/viewer](../../structure/surfaces/viewer/layout.md) が定める。
観測の機構の置き場は [structure](../structure/)、言語別の実現は [tools](../tools/) が定める。
