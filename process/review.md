# レビューの順序

レビューは、境界の特定から規律の照合へ進める。
適用の3則と判定の枠は root の [README](../README.md) に従う。

## 順序

1. 機械検証で判定できる指摘を、静的解析と CI に任せ、以降の照合を残りに絞る([principles/verification](../principles/verification.md) の重要な制約を機械検証に固定するに従う)。
2. 変更対象がどの境界に属すかを、[structure/skeleton](../structure/skeleton.md) の境界集合で特定する。
3. その境界の layout と、変更が触れる [principles](../principles/)・[concerns](../concerns/) を読む。
4. 対象言語の該当する実現軸([languages](../languages/))で、使う機構を確かめる。
5. 判定の枠で照合し、指摘は [audit](./audit.md) の列挙の形で、該当規律の file を添えて返す。

## 確認点

機械で検証できる指摘は、人手の指摘で終えず、検証の追加として返す([principles/verification](../principles/verification.md) の重要な制約を機械検証に固定するに従う)。
標準本文の矛盾と改訂提案の扱いは、[audit](./audit.md) の確認点に従う。

## 範囲外

標準そのものの監査は扱わない。
標準リポジトリの保守が行う。
