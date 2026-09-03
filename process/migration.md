# 移行の順序

移行は、標準との差分埋め・基盤の入れ替え・契約とスキーマの変更のように、動いている系を壊さずに別の形へ揃える作業の順序である。
移行は独立した手順の並びでなく、[implementation](./implementation.md) と同じく、安全網の緑を保ったまま範囲が段階的に及ぶ一続きの過程である。
段階的で可逆な変更の性質は [principles/evolution](../principles/evolution.md) に従う。

## 順序

1. 現行の意味、state の authority、実行経路が確立していなければ [recovery](./recovery.md) を実行し、目標の形が確立していなければ [design](./design.md) を実行する。その後、現行と目標の差分を出す(標準との差分は [audit](./audit.md) の順序で出す)。
2. 既存の違反を一度に解消できない場合は、準拠との差分を検査の失敗 baseline として全件固定し、各差分に所有者・解消条件・検出する root check を割り当てる。新しい違反は baseline に加えない。
3. 変える前に安全網を張る([principles/verification](../principles/verification.md) の「テストを振る舞いの安全網にする」に従い、回帰テスト・本番の観測・新旧の整合検査を備える)。
4. 変更を小さく可逆な段に分け、各段に達成条件・撤退条件・不可逆点を定める([principles/evolution](../principles/evolution.md) の「変更は段階的で可逆にする」に従う)。
5. 新旧が同じ datastore にある場合は、[concerns/transaction](../concerns/transaction.md) の「一つの確定点を持つ」と、[concerns/migration](../concerns/migration.md) の「稼働中のスキーマを拡張・移行・収縮の段で進化させる」を適用する。
   schema migration の artifact は [concerns/migration](../concerns/migration.md) の forward-only の定めに従い、service の配備とは独立して適用する。
6. 新旧が別の datastore にある場合は、[concerns/transaction](../concerns/transaction.md) の「状態とイベントを同一パスで記録する」を適用する。
7. 別 datastore の既存 data の移送から cutover までは、[concerns/migration](../concerns/migration.md) の「別 datastore の移行を同じ時点で検証して切り替える」の行動を記載順に実行する。
8. outbox の再配送と失敗の回復は、[concerns/resilience](../concerns/resilience.md) と [concerns/observability](../concerns/observability.md) の規律を適用する。
9. 各段で安全網の緑を確かめてから次へ進み、不可逆点の手前では観測の期間を置く。
10. 新しい正本への昇格を確認してから、旧い正本への write と旧い経路を落とす。
11. 標準へ揃える移行は、[structure/skeleton](../structure/skeleton.md) の境界から内側の core へ向かって進める。
12. 揃えられない箇所は、標準の単一性の定めに従い、project の ADR に逸脱として記録する。

## 確認点

各段の達成条件・撤退条件・不可逆点の定めと安全網の具備は、[principles/evolution](../principles/evolution.md) の「変更は段階的で可逆にする」の完了条件に照合する。
失敗 baseline に、準拠との差分の欠落、新規違反、所有者・解消条件・root check の欠落がないことを確かめる。
安全網に頼る前に、テストを意図的に壊して赤になることを確かめる([principles/verification](../principles/verification.md) の「テストの信頼性を保つ」に照合する)。
同じ datastore の移行は、[concerns/transaction](../concerns/transaction.md) の一つの確定点と、[concerns/migration](../concerns/migration.md) の「稼働中のスキーマを拡張・移行・収縮の段で進化させる」の完了条件に照合する。
schema migration が forward-only の artifact であり、service の配備と別の実行単位で適用され、撤退も新しい forward migration で行われることを確かめる。
別 datastore の確定は、[concerns/transaction](../concerns/transaction.md) の「状態とイベントを同一パスで記録する」の完了条件と禁止事項に照合する。
別 datastore の data 移送と cutover は、[concerns/migration](../concerns/migration.md) の「別 datastore の移行を同じ時点で検証して切り替える」の完了条件と禁止事項に照合する。
outbox の再配送と失敗後の回復は、[concerns/resilience](../concerns/resilience.md) と [concerns/observability](../concerns/observability.md) の完了条件に照合する。
標準へ揃える移行の完了は、[audit](./audit.md) の順序の再実行で判定し、残る差分の全てが project の ADR に逸脱として記録されていることを確かめる。
基盤と契約の移行の完了は、適用した concerns の完了条件、旧い経路の削除、安全網の緑で判定する。

## 範囲外

事業判断としての移行の可否は扱わない。
