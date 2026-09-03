# 検証の順序

検証は、変更の影響から段階的に広げ、失敗した段で止める。
検証の技法と検証手段への割当は [structure/tests/methods](../structure/tests/methods.md)、test の配置と実行環境は [structure/tests/layout](../structure/tests/layout.md) に従う。

## 順序

1. 変更の影響を受ける型検査、静的検査、Small test を最初に実行し、触れた境界の Medium test まで広げる。
2. 検証は、Small・Medium・Large の順で実行する。前の段が落ちたら、後の段を実行しない。
3. 契約、migration、認証・認可、供給網、検証入口そのものを変えた場合は、対応する全境界の検証を実行する。
4. Large test、全 mutation、全 SLO 計測は、影響が及ぶ変更、定期実行、release 前の検証で実行する。
5. 失敗後の修正では、失敗した検証と、修正した source の依存先と逆依存の consumer に対応する検証を再実行する。

## 確認点

同じ source、command、環境、入力の成功結果は、その同一性を確認できる間は再利用し、同じ検証を重ねて実行しない。
検証を省いたのでなく、影響がないことを差分と依存関係から示せない検証は実行する。
検証の合否は、root の [README](../README.md) の適用の4則に従い、repository に記録した検証入口の実測で判定する。

## 範囲外

検証の技法の選択と検証手段への割当は扱わない([structure/tests/methods](../structure/tests/methods.md) が正本である)。
