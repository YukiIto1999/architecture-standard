# 監査の順序

監査は、root の境界から内側の実装へ照合を進める。
判定の枠と適用の4則は root の [README](../README.md) に、規律の正本は各層に従う。

## 順序

1. system purpose、語彙、重要な state の authority、実際の境界と実行経路が監査の根拠として確立していなければ、先に [recovery](./recovery.md) を実行する。
2. [structure/skeleton](../structure/skeleton.md) の境界と依存方向表に、root の実態を照合する。
3. 各境界の内部を、対応する layout の構成と固有規律に照合する。
4. 横断の規律を、[concerns](../concerns/) の完了条件と禁止事項に照合する。
5. 設計の判断を、[principles](../principles/) の完了条件と禁止事項に照合する。
6. 実装を、[languages](../languages/) の採用機構と各規律の完了条件・禁止事項に照合する。
7. 使われている道具を、[tools](../tools/) の採用と判断基準に照合する。
8. 違反は、severity・file と該当箇所・対応する標準の規律とその本文の引用を添えて列挙する。

## 確認点

準拠の基準は、root の [README](../README.md) の標準の参照に従い、project の ADR に記録された標準の commit である。
severity は、root の [README](../README.md) の判定の枠で得た違反を次の一意な対応へ写すだけであり、各領域の正本を再定義しない。
principles と concerns は、禁止事項への違反を critical、完了条件の不達を major に写す。
structure は、依存方向か明示された禁止への違反を critical、必須の構成か layout の不達を major に写す。
languages は、明示された禁止への違反を critical、採用機構か完了条件の不達を major に写す。
tools は、採用か判断基準の不達を major に写す。
process は、順序の不遵守か確認点の未照合を major に写す。
同じ箇所が critical と major の両方に当たる場合は、critical だけを列挙する。
root の判定の枠にない磨きは違反に数えず、minor の提案として区別する。
照合で見つけた標準本文の矛盾は、root の [README](../README.md) の矛盾の解決に従って報告する。
標準への改訂提案は、root の [README](../README.md) の標準の参照に従い、project の docs/revision に置く。
意味回収を行った場合は、監査の判断を左右した主張が [principles/verification](../principles/verification.md) の根拠と決定状態を分けるの完了条件を満たすことを確かめる。

## 範囲外

指摘の修正は監査に含めない。
修正は [implementation](./implementation.md) と [refactoring](./refactoring.md) に、標準との差分を埋める移行は [migration](./migration.md) に従う。
