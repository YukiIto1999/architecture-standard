# 新規構築の順序

新規構築は、境界の決定から内部の実装まで、外から内へ進める。
境界の正本は [structure/skeleton](../structure/skeleton.md)、判断の照合先は [principles](../principles/) と [concerns](../concerns/) に従う。
設計判断の都度、[design](./design.md) の順序で進め、principles と関係する concerns の完了条件・禁止事項に照合する。
決定は、project の ADR に記録しながら進める。

## 順序

1. project の関心を列挙し、[structure/skeleton](../structure/skeleton.md) の条件で root と surface の境界集合を決める。
2. project の実装単位と言語の対応を入力として確定し、[tools](../tools/) の各 ecosystem の README が定める言語の採用に照合する。
3. [tools](../tools/) の6つの実現軸と全域規律 conventions で、言語の機構を固定する。
4. 必要な共有ライブラリを、[tools/build/vendoring](../tools/build/vendoring.md) が定める取得機構で target の `libs/<mechanism>` へ初期化し、target が記録した exact commit のコードと `spec.md` を materialize する。
5. 骨格だけの最薄の一線を、タスク実行の正本と段階実行で検証入口の合格状態にする([structure/tests](../structure/tests/layout.md) の「タスク実行の正本」と「段階実行」に従う)。
6. 置いた境界ごとに、対応する layout に従って内部を組む。
7. 各境界の実装は、[implementation](./implementation.md) の順序で進める。

## 確認点

project の実装単位と言語の対応が入力として明示され、共通の skeleton と使用する各言語の規律が適用されていることを確かめる。
機構の固定の時点で、採用する道具が [tools](../tools/) の採用と一致していることを確かめる。
共有ライブラリの初期化後に、target が記録した origin、path、exact commit と、`libs/<mechanism>` に materialize された commit および `spec.md` が一致していることを確かめる。

## 範囲外

体制と調達は扱わない。
