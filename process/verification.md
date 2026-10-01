# 検証の順序

検証は、時間の予算で分けた T0 から T3 の段で行い、変更の影響から広げ、失敗した段で止める。
検証の技法と検証手段への割当は [structure/tests/methods](../structure/tests/methods.md)、test の配置と実行環境とタスク定義の置き場は [structure/tests/layout](../structure/tests/layout.md) に従う。

| 段 | 実行する時点 | 予算の上限 | 入口の task 名 | 中身 |
|---|---|---|---|---|
| T0 | 編集と保存のたび | 10 秒 | なし | 変更した file の型検査、analyzer、lint、formatter の検査、構造の静的検査 |
| T1 | agent が作業を止める前と commit の前 | 2 分 | `verify` | 変更の影響を受ける範囲の T0 の検査、Small test、反復数を絞った property-based testing、契約の検証 |
| T2 | push の前の作業機 | 15 分 | `verify-push` | 影響範囲の実 datastore を使う test、変更した行の mutation、影響する scenario |
| T3 | project が選んだ契機 | なし | `verify-full` | 全量の mutation、全量の Large test と e2e、全量の SLO 計測 |

## 順序

1. T0 を、編集と保存のたびに実行する。
2. T1 を、agent が作業を止める前と commit の前に `verify` で実行する。
3. T2 を、git の pre-push hook から T2 の入口を起動して作業機で実行する。
4. 契約、migration、認証・認可、供給網、検証入口そのものを変えた場合は、対応する全境界の検証を T2 の影響範囲に含める。
5. 各段の中では、Small・Medium・Large の順で実行し、前が落ちたら後を実行しない。
6. T3 は、変更ごとの経路の外で T3 の入口から実行し、gate にしない。
7. T3 の結果は前回の T3 の結果と比べ、新たな失敗と検出されなかった mutant を、テストまたは仕様の修正候補として backlog へ記録する。
8. T3 を実行する契機は、release の前、変更の量、作業機の資源の空きなどから project が選び、決定の記録に残す。
9. CI は、commit の規約の検査、secret の漏洩の検査、T1 だけを実行し、T2 を実行しない。
10. 失敗後の修正では、失敗した検証と、修正した source の依存先と逆依存の consumer に対応する検証を再実行する。

## 確認点

各段の予算は上限であり、入口の実測の所要時間が予算を超えた段は失敗とする。
予算を超えた検証は、より安い検証器へ置き換えるか、後の段へ移す。
T3 の周期は、標準でなく project の決定の記録が定める。
入口を package.json の scripts に定める場合は、T2 と T3 の入口の task 名を `verify:push`・`verify:full` とし、pre-push hook はその名で T2 の入口を起動する。
影響範囲は、task graph、crate、project の参照の依存関係から決める。
同じ source、command、環境、入力の成功結果は、その同一性を確認できる間は再利用し、同じ検証を重ねて実行しない。
検証を省いたのでなく、影響がないことを差分と依存関係から示せない検証は実行する。
検証の合否は、root の [README](../README.md) の適用の4則に従い、repository に記録した T1 と T2 の検証入口の実測で判定する。

## 範囲外

検証の技法の選択と検証手段への割当は扱わない([structure/tests/methods](../structure/tests/methods.md) が正本である)。
