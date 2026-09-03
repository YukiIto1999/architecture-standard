# process

process は、どの順で作り、どこで確かめるかを定める。
作業の種別ごとに、順序と確認点を置く。
process は、順序と確認点だけを所有し、性質の規範を再定義しない。
規範の内容は [principles](../principles/) と [concerns](../concerns/) に従い、順序の入力と確認点の照合先として [structure](../structure/)・[tools](../tools/)・[tools](../tools/) を指す。

## 書式

各単位は、導入の参照文、順序、確認点、範囲外で書く。
順序は番号付きの手順で書き、各手順は一つの作業を指す。
確認点は、どの規律の完了条件と禁止事項をいつ照合するかと、照合の判定に使う基準を書く。
必須5節の書式は使わない。
性質の規範は各層の正本にある。

## 単位

| ファイル | 作業 |
|---|---|
| [bootstrap](./bootstrap.md) | 新規構築 |
| [recovery](./recovery.md) | 既存システムの意味回収 |
| [design](./design.md) | 設計 |
| [implementation](./implementation.md) | 実装 |
| [refactoring](./refactoring.md) | 構造改善 |
| [review](./review.md) | レビュー |
| [audit](./audit.md) | 監査 |
| [migration](./migration.md) | 移行 |
| [verification](./verification.md) | 検証の実行 |
| [release](./release.md) | release と配備 |

## 判定の枠

遵守は、順序が守られたことと、確認点の照合が行われたことで判定する。
検証の合否の判定は、root の [README](../README.md) の適用の4則に従う。

## 範囲外

プロジェクト運営は扱わない。
スコープ・費用・期間・体制・デリバリーの周期は、project が決める。
AI への指示の技法は扱わない。
手順は、実行者が人でも AI エージェントでも同じである。
