# 新規構築の順序

新規構築は、境界の決定から内部の実装まで、外から内へ進める。
境界の正本は [structure/skeleton](../structure/skeleton.md)、判断の照合先は [principles](../principles/) と [concerns](../concerns/) に従う。
設計判断の都度、[design](./design.md) の順序で進め、principles と関係する concerns の完了条件・禁止事項に照合する。
決定の意味を、[principles/documentation](../principles/documentation/decision-records.md) の「設計判断の理由を決定の記録に残す」に従って、対応する正本へ残しながら進める。

## 順序

1. project の関心を列挙し、[structure/skeleton](../structure/skeleton.md) の条件で root と surface の境界集合を決める。
2. project の実装単位と言語の対応を入力として確定し、[languages](../languages/) の各 ecosystem の README が定める言語の採用に照合する。
3. [languages](../languages/) の6つの実現軸と全域規律 conventions で、言語の機構を固定する。
4. 必要な機構を [structure/libs](../structure/libs/layout.md) に従い target の `libs/<mechanism>` へ初期化する。
   target 内で管理する機構は、その path にコードと `spec.md` を置く。
   独立した repository から共有する機構だけを、[tools/build/vendoring](../tools/build/vendoring.md) が定める取得機構で、記録した exact commit から取り込む。
5. 骨格だけの最薄の一線を、タスク実行の正本と段階実行で検証入口の合格状態にする([structure/tests](../structure/tests/layout.md) の「タスク実行の正本」と「段階実行」に従う)。
6. 置いた境界ごとに、対応する layout に従って内部を組む。
7. 各境界の実装は、[implementation](./implementation.md) の順序で進める。

## 確認点

project の実装単位と言語の対応が入力として明示され、共通の skeleton と使用する各言語の規律が適用されていることを確かめる。
機構の固定の時点で、採用する道具が [tools](../tools/) と [languages](../languages/) の採用と一致していることを確かめる。
機構の初期化後に、[structure/libs](../structure/libs/layout.md) に従い、機構の技術契約、公開面、`spec.md` の機構名と検査対象が対応していることを確かめる。
独立した repository から取り込んだ場合は、記録した origin、path、exact commit と、`libs/<mechanism>` に置いたコードおよび `spec.md` が一致していることを確かめる。
target 内で管理する機構には、外部の origin、exact commit、UPSTREAM や実際の公開を初期化の条件にしない。

## 範囲外

体制と調達は扱わない。
