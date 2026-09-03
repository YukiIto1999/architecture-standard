# 設計の順序

設計は、問題から構造へ、目的を経由して進める。
性質の規律は [principles](../principles/) と [concerns](../concerns/) に従う。

## 順序

1. 解くべき問題を、観測された事実と解釈を分け、判断を左右する主張の根拠と決定状態を記録して定める([principles/requirements](../principles/requirements.md) の「目的から要件を導く」と「根拠と決定状態を分ける」に従う)。既存システムの意味が確立していなければ [recovery](./recovery.md) へ戻る。
2. 候補の手段から上位の目的へ遡り、目的から例を挙げて要件へ降りる([principles/requirements](../principles/requirements.md) の「目的から要件を導く」に従う)。
3. 要件と完了条件を定める([principles/requirements](../principles/requirements.md) の「検証できる形で要件と制約を定める」に従う)。
4. 対象コンテキストの語彙を確かめる([principles/naming](../principles/naming.md) の「語彙を統一する」の行動に従う)。
5. 概念・状態・制約を洗い出す([principles/modeling](../principles/modeling.md) の「不正な状態を表現できなくする」の行動に従い、欠けている制約まで出す)。
6. アクターと処理の接続を図示し、複数のアクターが一つの処理へつながっていないかを確かめる([principles/separation](../principles/separation.md) の「変更理由で分ける」に従う)。
7. 境界と依存の方向を決める([principles/separation](../principles/separation.md)、[structure/skeleton](../structure/skeleton.md) に従う)。
8. 境界を決めてから、[principles/construction](../principles/construction.md) の「新しい要素を最後に選ぶ」の段を適用し、必要な型とパターンの戦術を選ぶ。境界の決定を飛ばして戦術だけを適用しない([tools](../tools/) に従う)。

## 確認点

構造を確定する前に、principles の modeling・separation の完了条件・禁止事項と、変更が触れる concerns の完了条件・禁止事項に照合する。
採用する道具は、[tools](../tools/) の採用に従う。
決定は、project の ADR に記録する([principles/documentation](../principles/documentation.md) の「設計判断の理由を決定の記録に残す」に従う)。
アクターと処理の図示は、設計の時点と、実装を書いた後の検証の両方で行い、[principles/separation](../principles/separation.md) の「変更理由で分ける」の完了条件に照合する。
新しい型・抽象・設定・依存を選んだ場合は、[principles/construction](../principles/construction.md) の「新しい要素を最後に選ぶ」の完了条件と禁止事項に照合する。

## 範囲外

見積りと体制は扱わない。
