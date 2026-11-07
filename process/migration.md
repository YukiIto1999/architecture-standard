# 移行の順序

移行は、標準との差分埋め・基盤の入れ替え・契約とスキーマの変更のように、動いている系を壊さずに別の形へ揃える作業の順序である。
移行は独立した手順の並びでなく、[implementation](./implementation.md) と同じく、安全網の緑を保ったまま範囲が段階的に及ぶ一続きの過程である。
段階的で可逆な変更の性質は [principles/evolution](../principles/evolution/README.md) に従う。

## 順序

1. 現行の意味、state の authority、実行経路が確立していなければ [recovery](./recovery.md) を実行し、目標の形が確立していなければ [design](./design.md) を実行する。
   その後、現行と目標の差分を出す(標準との差分は [audit](./audit.md) の順序で出す)。
2. 既存の違反を一度に解消できない場合は、[audit](./audit.md) が定める基線台帳へ全件記録し、各行に所有者・解消条件・検出する root check を割り当てる。
   新しい違反は基線台帳に加えない。
3. 変える前に安全網を張る([principles/verification](../principles/verification/behavioral-safety-net.md) の「テストを振る舞いの安全網にする」に従い、回帰テスト・本番の観測・新旧の整合検査を備える)。
4. 変更を小さく可逆な段に分け、各段に達成条件・撤退条件・不可逆点を定める([principles/evolution](../principles/evolution/incremental-reversible-change.md) の「変更は段階的で可逆にする」に従う)。
   保存済みの事実を含む場合は、[concerns/persistence](../concerns/persistence/fact-preserving-migrations.md) の「保存済みの事実を意味と値を保って移行する」に従い、書き換える移行と旧い版の行を残す読み出し変換のどちらで意味と値を保つかを選び、保持する版の解釈と移行対象の旧い経路を分ける。
5. 新旧が同じ datastore にある場合は、[concerns/transaction](../concerns/transaction/single-commit-point.md) の「一つの確定点を持つ」と、[concerns/migration](../concerns/migration/schema-change-cutover.md) の「新旧の併存に応じてスキーマを切り替える」を適用する。
   旧い構造を読み書きする全ての経路を止められるか、新旧が併存するかを決めて決定の記録に残し、止められる場合は停止の確認、復旧点、変更の適用、照合、受付の再開の順に進める。
   併存する場合は、互換を保てない変更を三段の順に進め、互換を保てる変更は旧い program の読み書きを壊さないことを確かめて適用する。
   schema migration の artifact は [concerns/migration](../concerns/migration/schema-change-cutover.md) の「新旧の併存に応じてスキーマを切り替える」が定める forward-only に従い、停止切替でも併存でも、service の配備とは独立して適用する。
   独立した集合ごとに source、対象 DB、適用履歴、設定を対応づけ、同じ DB への適用を所有する配備の task を一つに定め、各段の順序に従って直列に適用する。
   履歴表の名前や集合の所属だけを変える場合も DB の移行として扱い、適用済みの版と checksum を所有元へ対応づけて引き継ぎ、既存の schema と data が保たれ、適用済みの SQL が再実行されないことを確かめる。
   新旧の適用入口が別々の履歴へ書き続けないように切り替え、旧い入口が停止し、新しい履歴と実際の schema の対応が確認できるまで、旧い履歴を落とさない。
6. 新旧が別の datastore にある場合は、[concerns/transaction](../concerns/transaction/state-event-atomicity.md) の「状態とイベントを同一パスで記録する」を適用する。
7. 別 datastore の既存 data の移送から cutover までは、[concerns/migration](../concerns/migration/datastore-cutover.md) の「別 datastore の移行を同じ時点で検証して切り替える」の行動を記載順に実行する。
8. outbox の再配送と失敗の回復は、[concerns/resilience](../concerns/resilience/README.md) と [concerns/observability](../concerns/observability/README.md) の規律を適用する。
9. 各段で安全網の緑を確かめてから次へ進み、不可逆点の手前では観測の期間を置く。
10. 新しい正本への昇格を確認してから、移行対象の旧い正本への write と旧い経路を落とす。
11. 標準へ揃える移行は、[structure/skeleton](../structure/skeleton.md) の境界から内側の core へ向かって進める。
12. 揃えられない箇所は、root の [README](../README.md) の標準の単一性に従い、現在の逸脱の根拠と撤回条件を、判断を所有するコード、契約、設定と読者向けの文書から辿れるようにする。

## 確認点

各段の達成条件・撤退条件・不可逆点の定めと安全網の具備は、[principles/evolution](../principles/evolution/incremental-reversible-change.md) の「変更は段階的で可逆にする」の完了条件に照合する。
基線台帳に、準拠との差分の欠落、新規違反、所有者・解消条件・root check の欠落がないことを確かめる。
安全網の検出力は、守る性質を破る変更を検証対象へ加え、その違反で判定が失敗する証拠で確かめる([principles/verification](../principles/verification/test-reliability.md) の「テストの信頼性を保つ」に照合する)。
この確認は、[principles/verification](../principles/verification/test-reliability.md) の「テストの信頼性を保つ」が要求する検証対象の保証の違反と判定結果に照合し、runner だけの赤と区別して、条件が同じ既存の検出の証跡を再利用する。
同じ datastore の移行は、[concerns/transaction](../concerns/transaction/README.md) の一つの確定点と、[concerns/migration](../concerns/migration/schema-change-cutover.md) の「新旧の併存に応じてスキーマを切り替える」の完了条件に照合し、停止切替か併存かの選択の根拠を決定の記録に照合する。
schema migration の artifact は、[concerns/migration](../concerns/migration/schema-change-cutover.md) の「新旧の併存に応じてスキーマを切り替える」の完了条件と禁止事項に照合する。
独立した migration の集合ごとの source、対象 DB、履歴、設定、適用順序と実行所有者を照合し、履歴の移設では元の適用済み記録と既存の schema、data の保存、適用済みの SQL の再実行の不在、旧い適用入口の停止を確かめる。
別 datastore の確定は、[concerns/transaction](../concerns/transaction/state-event-atomicity.md) の「状態とイベントを同一パスで記録する」の完了条件と禁止事項に照合する。
別 datastore の data 移送と cutover は、[concerns/migration](../concerns/migration/datastore-cutover.md) の「別 datastore の移行を同じ時点で検証して切り替える」の完了条件と禁止事項に照合する。
outbox の再配送と失敗後の回復は、[concerns/resilience](../concerns/resilience/README.md) と [concerns/observability](../concerns/observability/README.md) の完了条件に照合する。
標準へ揃える移行の完了は、[audit](./audit.md) の順序の再実行で判定し、残る差分の全てについて、現在の逸脱とその根拠を root の [README](../README.md) の標準の単一性に照合する。
基盤と契約の移行の完了は、適用した concerns の完了条件、移行対象の旧い経路の削除、安全網の緑で判定する。
保存事実の移行による意味と値の保持と版の解釈の存続・撤去、配送中の旧版対応の存続・撤去は、それぞれ [concerns/persistence](../concerns/persistence/fact-preserving-migrations.md) と [concerns/messaging](../concerns/messaging/event-contract-versioning.md) の完了条件に照合する。

## 範囲外

事業判断としての移行の可否は扱わない。
