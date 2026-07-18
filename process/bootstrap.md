# 新規構築の順序

新規構築は、境界の決定から内部の実装まで、外から内へ進める。
境界の正本は [structure/skeleton](../structure/skeleton.md)、判断の照合先は [principles](../principles/) と [concerns](../concerns/) に従う。
設計判断の都度、[design](./design.md) の順序で進め、principles と関係する concerns の完了条件・禁止事項に照合する。
決定は、project の ADR に記録しながら進める。

## 順序

1. project の関心を列挙し、[structure/skeleton](../structure/skeleton.md) の条件で root と surface の境界集合を決める。
2. core の言語を一つ選ぶ([tools/language](../tools/language.md) の選定と ADR への記録に従う)。
3. [languages](../languages/) の7つの実現軸と全域規律 conventions で、言語の機構を固定する。
4. [structure/tests](../structure/tests/layout.md) の機械検証を、skeleton の依存方向表を駆動元にして設置する。
5. 骨格だけの最薄の一線を、タスク実行の正本と段階実行で CI の緑にする([tools/README](../tools/README.md) のタスク実行と [structure/tests](../structure/tests/layout.md) の段階実行に従う)。
6. 置いた境界ごとに、対応する layout に従って内部を組む。
7. 各境界の実装は、[implementation](./implementation.md) の順序で進める。

## 確認点

内部を組む前に、[structure/skeleton](../structure/skeleton.md) の依存方向表を駆動元とする機械検証が動いていることを確かめる。
機構の固定の時点で、採用する道具が [tools](../tools/) の採用と一致していることを確かめる。

## 範囲外

体制と調達は扱わない。
