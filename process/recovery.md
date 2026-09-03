# 意味回収の順序

意味回収は、既存システムの修正または評価より先に、判断に必要な目的・語彙・状態・責務・依存・実行時の流れを根拠付きで復元する。
根拠の扱いは [principles/requirements](../principles/requirements.md) の「根拠と決定状態を分ける」に、概念と状態の性質は [principles/modeling](../principles/modeling.md) と [principles/separation](../principles/separation.md) に従う。

## 順序

1. 対象 repo に記録された build・test・主要な実行例の入口を実行し、再現できた結果と再現できない範囲を記録する。入口の修復は行わない。
2. 判断または変更を左右する主張を抽出し、[principles/requirements](../principles/requirements.md) の「根拠と決定状態を分ける」に従って根拠の状態と決定の状態を分類する。
3. 一次資料、契約、入口の文書、利用者から、system purpose、actor、主要な use case、bounded context を回収する。
4. 主要概念を、コード・DB・API・UI・error・log・test の表現から横断して追い、一つのコンテキスト内の語彙と境界間の対応を回収する。
5. 判断に関わる state ごとに、意味、kind、authority、owner、writer、reader、lifecycle、derivation、invariant を回収する。
6. 現行の transition・pipeline・effect・外部 I/O・dependency を実行経路から回収する。pipeline の各段では、入力の保証、新たに得る保証、失う情報、失敗、effect を記録する。
7. 重要な値を出力から authority まで逆向きに追跡し、主要な操作を入力から decision・transition・effect まで順向きに追跡する。
8. 資料と実装の矛盾、複数の authority、到達不能または不可能な state、責務と依存の不一致を、確定した事実と `Unknown` に分ける。
9. 判断に必要な意味が回収できた範囲だけを、目的に応じて [audit](./audit.md)・[design](./design.md)・[refactoring](./refactoring.md)・[migration](./migration.md) へ渡す。

## 確認点

主張の分類が、[principles/requirements](../principles/requirements.md) の「根拠と決定状態を分ける」の完了条件を満たすことを確かめる。
一般的な慣習または領域知識で、システム固有の仕様を補っていないことを確かめる。
目的に必要な view だけを作り、該当しない map や空の節を定型で増やしていないことを確かめる。
重要な state と値について、authority、owner、lifecycle、derivation と、順方向・逆方向の実行経路を説明できることを確かめる。
判断に必要な主張が根拠付きで確定したか `Unknown` として残り、その `Unknown` に依存する判断が後続へ渡されていない時点で止める。

## 範囲外

実装の修正、目標構造の設計、移行順序の決定は扱わない。
現在の挙動を意図された仕様として確定しない。
