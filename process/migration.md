# 移行の順序

移行は、差分の把握から標準へ揃え切るまで、外から内へ進める。
段階的な変更の規律は [principles/evolution](../principles/evolution.md) に従う。

## 順序

1. [audit](./audit.md) の順序で差分を出す。
2. [structure/skeleton](../structure/skeleton.md) の境界から順に、内側の core へ向かって標準へ揃える。
3. 各段の進め方は、[principles/evolution](../principles/evolution.md) の変更は段階的で可逆にするに従う。
4. 揃えられない箇所は、標準の単一性の定めに従い、project の ADR に逸脱として記録する。

## 確認点

各段の達成条件・撤退条件・不可逆点の定めと安全網の具備は、[principles/evolution](../principles/evolution.md) の変更は段階的で可逆にするの完了条件に照合する。
移行の完了は、[audit](./audit.md) の順序の再実行で判定し、残る差分の全てが project の ADR に逸脱として記録されていることを確かめる。

## 範囲外

事業判断としての移行の可否は扱わない。
