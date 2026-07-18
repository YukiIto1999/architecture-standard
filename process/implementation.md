# 実装の順序

実装は、作業単位の宣言から始め、テストリストと red・green・refactor の反復で進める。
テストの規律は [principles/verification](../principles/verification.md) に、変更の作法は [principles/evolution](../principles/evolution.md) に従う。

## 順序

1. 作業単位の名前と範囲を宣言する([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
2. 変更がどのアクターのどのユースケースに属するかを答え、答えられなければ [design](./design.md) へ戻る([principles/separation](../principles/separation.md) の変更理由で分けるに従う)。
3. 検証すべき振る舞いを、テストリストとして列挙する。
4. リストから一つ選び、実装より先にテストを書く([principles/verification](../principles/verification.md) のテストを設計の道具にするに従う)。
5. テストが赤であることを確かめ、赤にならなければテストの検証力を疑って書き直す。
6. テストを通す最小の実装を書いて緑にし、形を整える判断は次の段へ譲る。
7. 緑の間に感じた痛みと臭いを手がかりに、触れた範囲の構造を改善する([refactoring](./refactoring.md) に従う)。
8. 緑になった項目をリストから外し、リストが空になるまで 4 から 7 を繰り返す。
9. 出荷の前に、作業中に生まれた差分から目的に属するものだけを選別し、振る舞いの変更と構造の改善を別のコミットに分ける([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
10. 変更が触れた規律の完了条件・禁止事項と、[structure/tests](../structure/tests/layout.md) の機械検証に照合する。

## 確認点

作業中に気づいた振る舞いは、その場で実装せず、テストリストへ足す。
緑の間に既存の分岐本体の修正が要ったなら、場合の追加で完結しない構造の兆候として、refactor の段で構造を改善する([principles/construction](../principles/construction.md) の業務判断を型と多態で構造化するに照合する)。
緑にする作業を機械に任せた場合も、痛みと臭いの知覚と言語化を省かない([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
実装を書いた後のアクターと処理の図示照合は、[design](./design.md) の確認点に従う。
テストの技法と有効性の検査は [structure/tests/methods](../structure/tests/methods.md) に従う。

## 範囲外

リリースの可否は扱わない。
project が判断し、記録する。
