# 実装の順序

実装は、作業単位の宣言から始め、テストリストと red・green・refactor の反復で進める。
作業単位は、独立した反復の並びでなく、一つの範囲へ段階的に及ぶ一続きの過程である。
反復のたびに及ぶ範囲は外へ広がり、確かめ終えた内側は型と検証に委ねて固める。
範囲に含まれる複数の関心は、初めに分けて別々に閉じるのでなく、一つずつ加えながら組み上げる。
テストの規律は [principles/verification](../principles/verification.md) に、変更の作法は [principles/evolution](../principles/evolution.md) に従う。

## 順序

1. 作業単位の名前と範囲を宣言する([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
2. 変更がどのアクターのどのユースケースに属するかを答え、答えられなければ [design](./design.md) へ戻る([principles/separation](../principles/separation.md) の変更理由で分けるに従う)。
3. 着手時点で分かっている、検証すべき振る舞いを、テストリストに列挙する。
4. リストから、直前の反復が明らかにした依存と痛みを手がかりに一つ選び、その振る舞いが要求する依存と想定内の失敗を先に型へ宣言する([concerns/effect](../concerns/effect.md) の要求と想定内失敗を型に現すに従う)。
5. 宣言した型が指す依存と失敗がまだ存在せず、型検査が通らないことを確かめる。これが最初の赤である。
6. 実装より先にテストを書く([principles/verification](../principles/verification.md) のテストを設計の道具にするに従う)。
7. テストが赤であることを確かめ、赤にならなければテストの検証力を疑って書き直す。
8. テストを通す最小の実装を書いて緑にし、形を整える判断は次の段へ譲る。
9. 緑の間に感じた痛みと臭いを手がかりに、触れた範囲の構造を改善する([refactoring](./refactoring.md) に従う)。
10. 緑になった項目を外し、作業が明らかにした振る舞いを加えたリストが空になるまで、4 から 9 を繰り返す。
11. 出荷の前に、作業中に生まれた差分から目的に属するものだけを選別し、振る舞いの変更と構造の改善を別のコミットに分ける([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
12. 変更が触れた規律の完了条件・禁止事項と、[structure/tests](../structure/tests/layout.md) の機械検証に照合する。

## 確認点

赤を型から立てたかを確かめる。振る舞いの検証だけを赤の起点にすると、要求する依存を宣言しないまま緑にでき、port の無い構造がそのまま残る。
想定内の失敗を、成功の値の側の閉じた型へ入れていないかを確かめる([concerns/effect](../concerns/effect.md) の要求と想定内失敗を型に現すに照合する)。失敗の型が空のまま全ての計算が成功しうる形になっていれば、赤の立て方が誤っている。
作業中に気づいた振る舞いは、その場で実装せず、テストリストへ足す。
アクターとユースケースへの帰属は、テストを書く段で確かめ、refactor の段へ先送りしない([principles/separation](../principles/separation.md) の変更理由で分けるに照合する)。
構造の拡張性は refactor の段で確かめ、緑の間に既存の分岐本体の修正が要ったなら、場合の追加で完結しない構造の兆候として改善する([principles/construction](../principles/construction.md) の業務判断を型と多態で構造化するに照合する)。
緑にする作業を機械に任せた場合も、痛みと臭いの知覚と言語化を省かない([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
実装を書いた後のアクターと処理の図示照合は、[design](./design.md) の確認点に従う。
テストの技法と有効性の検査は [structure/tests/methods](../structure/tests/methods.md) に従う。

## 範囲外

リリースの可否は扱わない。
