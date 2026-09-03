# 構造改善の順序

構造改善は、[implementation](./implementation.md) の refactor の段、臭いの知覚、別作業の途中で見つけた異常、[audit](./audit.md) の指摘を契機に始める。
臭いの言語化は、[principles/evolution](../principles/evolution.md) の「触れた範囲を構造改善する」に従う。
安全網を張ってから、小さく可逆な段で進め、深追いせずに止める。

## 順序

1. 対象の意味、外から見た契約、重要な state の authority と invariant が確立していなければ、修正せずに [recovery](./recovery.md) へ戻る。
2. 対象の規模を、安全を確かめるのに要る検証の水準で見積もる([principles/verification](../principles/verification.md) の「テストを振る舞いの安全網にする」に従う)。
3. 振る舞いの安全網を確かめ、足りない範囲は現在の振る舞いを観測して固定するテストで埋める([principles/verification](../principles/verification.md) の「テストを振る舞いの安全網にする」に従う)。固定した挙動を `Intended` とみなさない。
4. 一つの use case・pipeline・state transition のように意味が閉じた単位へ変更を分け、境界を跨ぐ変更は境界ごとにチェックポイントを置く([principles/evolution](../principles/evolution.md) の「変更は段階的で可逆にする」に従う)。
5. 目的が混在した要素は、目的ごとに分けてから、同じ知識を表す部分だけを抽出する([principles/separation](../principles/separation.md) の「変更理由で分ける」に従う)。
6. 制御の混乱した箇所は、入出力の契約だけを固定し、内部を書き直す([principles/evolution](../principles/evolution.md) の「触れた範囲を構造改善する」に従う)。
7. 各段でテストの緑と参照の静的な追跡を保つ。
8. 置き換えた旧経路、重複した state、不要になった adapter・fallback・抽象を、その段の中で削除する。
9. 契機になった重複と痛みが解消したら、触れた範囲の改善で止める([principles/evolution](../principles/evolution.md) の「触れた範囲を構造改善する」に従う)。
10. 変更したコードとコメントを [principles/legibility](../principles/legibility.md) と [principles/comment](../principles/comment.md) に照合する。

## 確認点

各段で、全テストが緑であり、外から見た振る舞いが変わっていないことを確かめる([principles/verification](../principles/verification.md) の「テストを振る舞いの安全網にする」に従う)。
安全網に頼る前に、テストを意図的に壊して赤になることを確かめる([principles/verification](../principles/verification.md) の「テストの信頼性を保つ」に照合する)。
新しい場合の追加が既存の分岐本体の修正を要したなら、[principles/construction](../principles/construction.md) の「業務判断を型と多態で構造化する」に照合する。
想定内の失敗が型に出ていれば、失敗の追加は全ての呼び出し側を型検査が指すので、拡張の圧は臭いの知覚でなくコンパイラが運ぶ([concerns/effect](../concerns/effect.md) の「要求と想定内失敗を型に現す」に照合する)。圧が来ないなら、失敗が型から漏れているか、呼び出し側が取りこぼしを黙らせる腕を持っている。
結合の診断は、[principles/separation](../principles/separation.md) の「結合を距離に見合う強さにする」に従う。
変更した範囲を、[principles/legibility](../principles/legibility.md) の「コードを第一級の文書として明瞭に書く」の完了条件と禁止事項に照合する。
コメントを、[principles/comment](../principles/comment.md) の各規律の完了条件と禁止事項に照合する。
テストの有効性の検査は [structure/tests/methods](../structure/tests/methods.md) に従う。
置き換えた旧構造が残らず、一つの目的に一つの経路だけがあることを確かめる。

## 範囲外

基盤の入れ替えと契約の変更、標準との差分を埋める移行は、[migration](./migration.md) に従う。
