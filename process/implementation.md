# 実装の順序

実装は、作業単位の宣言から始め、テストリストと red・green・refactor の反復で進める。
作業単位は、独立した反復の並びでなく、一つの範囲へ段階的に及ぶ一続きの過程である。
反復のたびに及ぶ範囲は外へ広がり、確かめ終えた内側は型と検証に委ねて固める。
範囲に含まれる複数の関心は、初めに分けて別々に閉じるのでなく、一つずつ加えながら組み上げる。
テストの規律は [principles/verification](../principles/verification.md) と [principles/naming](../principles/naming.md) に、コードの表現は [principles/legibility](../principles/legibility.md) と [principles/comment](../principles/comment.md) に、変更の作法は [principles/evolution](../principles/evolution.md) と [principles/documentation](../principles/documentation.md) に従う。

## 順序

1. 作業単位の名前と範囲を宣言する([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
2. 変更がどのアクターのどのユースケースに属するかを答え、答えられなければ [design](./design.md) へ戻る([principles/separation](../principles/separation.md) の変更理由で分けるに従う)。
3. 着手時点で分かっている、検証すべき振る舞いを、テストリストに列挙する。
4. 初回は、公開 interface を越して確かめられる最小の振る舞いをリストから選ぶ。
5. 選んだ振る舞いについて、[principles/construction](../principles/construction.md) の新しい要素を最後に選ぶの段を記載順に適用し、要求を満たす最初の段で止める。
6. 選んだ振る舞いに、新しい依存を表す型か想定内の失敗を表す型が必要かを判断する([concerns/effect](../concerns/effect.md) の要求と想定内失敗を型に現すに従う)。
7. 新しい依存を表す型か失敗の型が必要な場合は、最小の新しい型を宣言し、その型を利用側の公開 signature か consumer へ接続する変更を同じ段階で行って型検査を実行する。
8. 手順7では、既存の implementation か caller が新しい型と不整合になった型検査の失敗だけを最初の赤として扱う。
9. 既存の型で足りる場合か手順7で対象の不整合が起きない場合は、振る舞いのテストを書き、そのテストを最初の赤にする([principles/verification](../principles/verification.md) のテストを設計の道具にするに従う)。
10. 手順8の型検査を最初の赤にした場合は、振る舞いのテストを書き、振る舞いを満たさない最小の変更で既存の implementation と caller を新しい型へ適合させ、型検査を通してから振る舞いのテストが赤になることを確かめる。
11. 振る舞いのテストが赤にならなければ、テストの検証力を疑って書き直す。
12. テストを通す最小の実装を書いて緑にし、形を整える判断は次の段へ譲る。
13. 緑の間に感じた痛みと臭いを手がかりに、触れた範囲の構造を改善する([refactoring](./refactoring.md) に従う)。
14. 緑になった項目を外し、直前の反復が明らかにした依存と痛みを手がかりに次の振る舞いを選び、作業が明らかにした振る舞いを加えたリストが空になるまで、5 から 13 を繰り返す。
15. 出荷の前に、作業中に生まれた差分から目的に属するものだけを選別し、振る舞いの変更と構造の改善を別のコミットに分ける([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。各コミットには、[principles/documentation](../principles/documentation.md) に従い、変更を行う直接の目的を記録する。
16. 変更が触れた規律の完了条件・禁止事項と、[structure/tests](../structure/tests/layout.md) の機械検証に照合する。

## 確認点

新しい依存を表す型か想定内の失敗を表す型が必要な場合は、最小の新型の宣言と利用側の公開 signature か consumer への接続を同じ段階で行ったことを確かめる。
新しい型・関数・ファイル・抽象・設定・依存に、[principles/construction](../principles/construction.md) の新しい要素を最後に選ぶで先行する段を退ける根拠があることを確かめる。
型宣言を利用側へ接続せずに追加することと、未定義の型を参照することを、型検査の赤として扱わない。
最初の型検査の赤が、既存の implementation か caller と新しい型との不整合から生じていることを確かめる。
新型を利用側へ接続しても対象の不整合が起きない場合は、振る舞いのテストを最初の赤にしたことを確かめる。
初回の振る舞いのテストが、公開 interface を越す最小のユースケースを検証していることを確かめる。
想定内の失敗を、成功の値の側の閉じた型へ入れていないかを確かめる([concerns/effect](../concerns/effect.md) の要求と想定内失敗を型に現すに照合する)。失敗の型が空のまま全ての計算が成功しうる形になっていれば、赤の立て方が誤っている。
作業中に気づいた振る舞いは、その場で実装せず、テストリストへ足す。
テスト名とテスト本体が、内部実装でなく、検証対象、条件、外から観測できる期待結果を表すことを確かめる([principles/naming](../principles/naming.md) と [principles/verification](../principles/verification.md) に照合する)。
アクターとユースケースへの帰属は、テストを書く段で確かめ、refactor の段へ先送りしない([principles/separation](../principles/separation.md) の変更理由で分けるに照合する)。
直和へ新しい場合を追加するときは、新しい arm を足し、既存の arm の本文が変わっていないことを確かめる([principles/construction](../principles/construction.md) の業務判断を型と多態で構造化するに照合する)。
緑にする作業を機械に任せた場合も、痛みと臭いの知覚と言語化を省かない([principles/evolution](../principles/evolution.md) の触れた範囲を構造改善するに従う)。
実装を書いた後のアクターと処理の図示照合は、[design](./design.md) の確認点に従う。
変更したコードを、[principles/legibility](../principles/legibility.md) の「コードを第一級の文書として明瞭に書く」の完了条件と禁止事項に照合する。
コメントを、[principles/comment](../principles/comment.md) の各規律の完了条件と禁止事項に照合する。
テストの技法と有効性の検査は [structure/tests/methods](../structure/tests/methods.md) に従う。

## 範囲外

リリースの可否は扱わない。
