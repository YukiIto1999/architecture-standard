# 監査の順序

監査は、root の境界から内側の実装へ照合を進める。
判定の枠と適用の3則は root の [README](../README.md) に、規律の正本は各層に従う。

## 順序

1. [structure/skeleton](../structure/skeleton.md) の境界と依存方向表に、root の実態を照合する。
2. 各境界の内部を、対応する layout の構成と固有規律に照合する。
3. 横断の規律を、[concerns](../concerns/) の完了条件と禁止事項に照合する。
4. 設計の判断を、[principles](../principles/) の完了条件と禁止事項に照合する。
5. 実装を、[languages](../languages/) の採用機構と各規律の完了条件に照合する。
6. 使われている道具を、[tools](../tools/) の採用と判断基準に照合する。
7. 違反は、severity・file と該当箇所・対応する標準の規律を添えて列挙する。

## 確認点

準拠の基準は、root の [README](../README.md) の標準の参照に従い、project の ADR に記録された標準の commit である。
severity は、禁止事項と依存方向表への違反を critical、完了条件の不達を major とする。
完了条件と禁止事項に触れない磨きは、違反に数えず、minor の提案として区別する。
照合で見つけた標準本文の矛盾は、root の [README](../README.md) の矛盾の解決に従って報告する。
標準への改訂提案は、root の [README](../README.md) の標準の参照に従い、project の docs/revision に置く。

## 範囲外

指摘の修正は監査に含めない。
修正は [implementation](./implementation.md) と [refactoring](./refactoring.md) に、標準との差分を埋める移行は [migration](./migration.md) に従う。
