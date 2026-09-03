# レビューの順序

レビューは、境界の特定から規律の照合へ進める。
照合は、変更を書いた実行者から独立した実行者が行う。
照合の入力は、差分、対象 repo の現在の内容、生成物、設定、変更されていない consumer、project の ADR に記録された準拠 commit の標準本文、許容済みとして提示された逸脱の ADR である。
照合に使う機械検証の結果は、独立した実行者が対象 repo で実行して得たものである。
提供された機械検証の結果は参考に留め、照合の根拠として盲信しない。
変更の経緯と実行者の記憶は、照合の入力にしない。
適用の4則と判定の枠は root の [README](../README.md) に従う。

## 順序

1. 独立した実行者が、対象 repo に記録された検証入口から静的解析と機械検証を実行し、以降の照合を残りに絞る([principles/verification](../principles/verification.md) の「重要な制約を機械検証に固定する」に従う)。
2. 変更対象がどの境界に属すかを、[structure/skeleton](../structure/skeleton.md) の境界集合で特定する。
3. 差分だけでなく、対象 repo の現在の内容、生成物、設定、変更されていない consumer を読み、変更の影響範囲を特定する。
4. その境界の layout と、変更が触れる [principles](../principles/)・[concerns](../concerns/) を読む。
   source の変更では [principles/legibility](../principles/legibility.md)、[principles/naming](../principles/naming.md)、[principles/comment](../principles/comment.md) を、テストの変更では [principles/verification](../principles/verification.md) と naming の「テスト名は仕様を表す」を、commit の件名では [principles/documentation](../principles/documentation.md) の「変更の目的を commit log に残す」を含める。
5. 対象言語の該当する実現軸と conventions([languages](../languages/))で、使う機構と全域規律を確かめる。
6. 変更で使う道具を、[tools](../tools/) の採用と判断基準に照合する。
7. 逸脱の ADR を、root の [README](../README.md) が要求する採用理由、撤回条件、単一採用、置き換える標準規律の file、逸脱の前提となる技術的制約の実証に照合する。
8. 追加された型・関数・ファイル・抽象・設定・依存を変更の要求へ対応付け、[principles/construction](../principles/construction.md) の「新しい要素を最後に選ぶ」で先行する段が十分でなかったかを照合する。
9. 判定の枠で照合し、指摘は [audit](./audit.md) の列挙の形で、該当規律の本文の引用と file を添えて返す。

## 確認点

照合の判定が、変更時の記憶や経緯でなく、差分と標準の本文から導かれていることを確かめる。
差分の外にある現在の実装、生成物、設定、変更されていない consumer を照合したことを確かめる。
機械検証の結果は、独立した実行者が対象 repo で再実行して得たことを確かめる。
標準本文は、project の ADR に記録された準拠 commit から読み、引用と file を独立に照合する。
逸脱の ADR に、採用理由、撤回条件、単一採用、置き換える標準規律の file、逸脱の前提となる技術的制約の実証が全て記録されていることを確かめる。
逸脱の技術的制約を現在の対象 repo と実行環境で再検証し、実証が現在も有効な場合だけ照合へ反映する。
撤回条件が成立した場合か技術的制約が解消した場合は、逸脱を許容せず、標準へ戻す指摘を返す。
対象言語の conventions と、変更で使う tools の採用と判断基準を読み飛ばしていないことを確かめる。
source の変更では、[principles/legibility](../principles/legibility.md) と [principles/comment](../principles/comment.md) の完了条件と禁止事項に照合したことを確かめる。
変更を書いた実行者の自己照合は、レビューの照合を代替しない。
機械で検証できる指摘は、人手の指摘で終えず、検証の追加として返す([principles/verification](../principles/verification.md) の「重要な制約を機械検証に固定する」に従う)。
標準本文の矛盾と改訂提案の扱いは、[audit](./audit.md) の確認点に従う。
現在の要求に対応しない将来用の抽象・設定・依存を、改善案として要求していないことを確かめる。

## 範囲外

標準そのものの監査は扱わない。
標準リポジトリの保守が行う。
