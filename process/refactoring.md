# 構造改善の順序

構造改善は、[implementation](./implementation.md) の refactor の段、臭いの知覚、別作業の途中で見つけた異常、[audit](./audit.md) の指摘を契機に始める。
臭いの言語化は、[principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う。
安全網を張ってから、小さく可逆な段で進め、深追いせずに止める。

## 順序

1. 対象の規模を、安全を確かめるのに要る検証の水準で見積もる([principles/verification](../principles/verification.md) のテストを振る舞いの安全網にするに従う)。
2. 振る舞いの安全網を確かめ、足りない範囲は現在の振る舞いを観測して固定するテストで埋める([principles/verification](../principles/verification.md) のテストを振る舞いの安全網にするに従う)。
3. 変更を小さく可逆な段に分け、境界を跨ぐ変更は境界ごとにチェックポイントを置く([principles/evolution](../principles/evolution.md) の変更は段階的で可逆にするに従う)。
4. 目的が混在した要素は、目的ごとに分けてから、同じ知識を表す部分だけを抽出する([principles/separation](../principles/separation.md) の変更理由で分けるに従う)。
5. 制御の混乱した箇所は、入出力の契約だけを固定し、内部を書き直す([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
6. 各段でテストの緑と参照の静的な追跡を保つ。
7. 契機になった重複と痛みが解消したら、触れた範囲の改善で止める([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。

## 確認点

各段で、全テストが緑であり、外から見た振る舞いが変わっていないことを確かめる([principles/verification](../principles/verification.md) のテストを振る舞いの安全網にするに従う)。
安全網に頼る前に、テストを意図的に壊して赤になることを確かめる([principles/verification](../principles/verification.md) のテストを振る舞いの安全網にするに従う)。
差分が追加に寄っているかを確かめ、修正が多いなら [principles/construction](../principles/construction.md) の業務判断を型と多態で構造化するに照合する。
結合の診断は、[principles/separation](../principles/separation.md) の結合を距離に見合う強さにするに従う。
テストの有効性の検査は [structure/tests/methods](../structure/tests/methods.md) に従う。

## 範囲外

基盤の入れ替えと契約の変更は、[principles/evolution](../principles/evolution.md) の変更は段階的で可逆にするに従う。
標準との差分を埋める移行は [migration](./migration.md) に従う。
