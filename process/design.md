# 設計の順序

設計は、問題から目的とドメイン型を定め、その型と操作の契約から構造と実装へ進める。
性質の規律は [principles](../principles/) と [concerns](../concerns/) に従う。

## 順序

1. 解くべき問題を、観測された事実と解釈を分け、判断を左右する主張の根拠と決定状態を記録して定める([principles/requirements](../principles/requirements/purpose-driven-requirements.md) の「目的から要件を導く」と [evidence-decision-separation](../principles/requirements/evidence-decision-separation.md) の「根拠と決定状態を分ける」に従う)。既存システムの意味が確立していなければ [recovery](./recovery.md) へ戻る。
2. 候補の手段から上位の目的へ遡り、目的から例を挙げて要件へ降りる([principles/requirements](../principles/requirements/purpose-driven-requirements.md) の「目的から要件を導く」に従う)。
3. 要件と完了条件を定める([principles/requirements](../principles/requirements/verifiable-requirements.md) の「検証できる形で要件と制約を定める」に従う)。
4. 対象コンテキストの語彙を確かめる([principles/naming](../principles/naming/unified-vocabulary.md) の「語彙を統一する」の行動に従う)。
5. 値・区分・集合の業務知識と操作を洗い出し、型の構築・入力・結果に保証を定める([principles/modeling](../principles/modeling/meaning-in-types.md) の「業務の意味を型に封じる」、[principles/construction](../principles/construction/decisions-as-types.md) の「業務判断を型と多態で構造化する」、[named-collection-operations](../principles/construction/named-collection-operations.md) の「集合処理を名前のある操作で表す」に従う)。
   状態と制約は [principles/modeling](../principles/modeling/illegal-states-unrepresentable.md) の「不正な状態を表現できなくする」の行動に従って洗い出す。
   暗黙の制約がある場合は、[structure/tests/methods](../structure/tests/methods.md) の「反実仮想で検証を選ぶ」に従い、合理的な小変更から利用者が観測する失敗と検出手段までを辿る。
6. アクターと処理の接続を図示し、複数のアクターが一つの処理へつながっていないかを確かめる([principles/separation](../principles/separation/split-by-change-reason.md) の「変更理由で分ける」に従う)。
7. 境界と依存の方向を決める([principles/separation](../principles/separation/README.md)、[structure/skeleton](../structure/skeleton.md) に従う)。
8. 境界を決めてから、[principles/construction](../principles/construction/reuse-before-new.md) の「新しい要素を最後に選ぶ」の段を適用し、設計したドメイン型と操作を実現する機構を選ぶ。境界の決定を飛ばして言語の機構やパターンだけを選ばない([languages](../languages/) に従う)。

## 確認点

構造を確定する前に、principles の modeling・construction・separation の完了条件・禁止事項と、変更が触れる concerns の完了条件・禁止事項に照合する。
業務の計算・判断・集合処理がある箇所では、その知識を持つ型と操作の所在を、該当する値・区分・集合の規律に照合する。
意味を伴う適合判断は、root の [README](../README.md) の適用判断に照らし、対象の事実と規律の条件から結論を導いた根拠が設計の記録から追えることを確かめる。
採用する道具は、[tools](../tools/) と [languages](../languages/) の採用に従う。
実装へ渡す判断の対象、採る案、その理由と帰結を定め、後の保守に必要な意味の所在を確かめる([principles/documentation](../principles/documentation/decision-records.md) の「設計判断の理由を決定の記録に残す」に従う)。
アクターと処理の図示は、設計の時点と、実装を書いた後の検証の両方で行い、[principles/separation](../principles/separation/split-by-change-reason.md) の「変更理由で分ける」の完了条件に照合する。
新しい型・抽象・設定・依存を選んだ場合は、[principles/construction](../principles/construction/reuse-before-new.md) の「新しい要素を最後に選ぶ」の完了条件と禁止事項に照合する。
暗黙の制約を反実仮想で検討した場合は、[structure/tests/methods](../structure/tests/methods.md) の「反実仮想で検証を選ぶ」に照らし、仮定と観測事実、強制する保証、検出済みか未実行かを区別して完了条件へ渡す。

## 範囲外

見積りと体制は扱わない。
