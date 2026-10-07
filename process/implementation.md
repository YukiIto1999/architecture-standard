# 実装の順序

実装は、作業単位の宣言から始め、テストリストと red・green・refactor の反復で進める。
着手する作業単位は、一つの目的と一つの取り消し理由を持ち、検証して commit できる範囲にする。
一つの作業単位の中では、型と振る舞いの検証で確かめながら段階的に組み上げる。
別の目的や取り消し理由が現れたら、現在の単位を検証して確定してから次の単位へ進み、全ての作業を終えた後の差分選別へ分割を先送りしない。
テストの規律は [principles/verification](../principles/verification/README.md) と [principles/naming](../principles/naming/README.md) に、コードの表現は [principles/legibility](../principles/legibility/README.md) と [principles/comment](../principles/comment/README.md) に、変更の作法は [principles/evolution](../principles/evolution/README.md) と [principles/documentation](../principles/documentation/README.md) に従う。

## 順序

1. 一つの目的と取り消し理由を持つ作業単位の名前と範囲を宣言する([principles/evolution](../principles/evolution/improve-touched-scope.md) の「触れた範囲を構造改善する」と [principles/documentation](../principles/documentation/commit-purpose.md) の「変更の目的を commit log に残す」に従う)。
2. 変更がどのアクターのどのuse-caseに属するかを答え、答えられなければ [design](./design.md) へ戻る([principles/separation](../principles/separation/split-by-change-reason.md) の「変更理由で分ける」に従う)。
3. 着手時点で分かっている、検証すべき振る舞いを、テストリストに列挙する。
4. 初回は、公開 interface を越して確かめられる最小の振る舞いをリストから選ぶ。
5. 選んだ振る舞いについて、[principles/construction](../principles/construction/reuse-before-new.md) の「新しい要素を最後に選ぶ」の段を記載順に適用し、要求を満たす最初の段で止める。
6. 選んだ振る舞いに、新しい依存を表す型か想定内の失敗を表す型が必要かを判断する([concerns/effect](../concerns/effect/typed-requirements-failures.md) の「要求と想定内失敗を型に現す」に従う)。
7. 新しい依存を表す型か失敗の型が必要な場合は、最小の新しい型を宣言し、その型を利用側の公開 signature か consumer へ接続する変更を同じ段階で行って型検査を実行する。
8. 手順7では、既存の implementation か caller が新しい型と不整合になった型検査の失敗だけを最初の赤として扱う。
9. 既存の型で足りる場合か手順7で対象の不整合が起きない場合は、振る舞いのテストを書き、そのテストを最初の赤にする([principles/verification](../principles/verification/tests-as-design.md) の「テストを設計の道具にする」に従う)。
10. 手順8の型検査を最初の赤にした場合は、振る舞いのテストを書き、振る舞いを満たさない最小の変更で既存の implementation と caller を新しい型へ適合させ、型検査を通してから振る舞いのテストが赤になることを確かめる。
11. 振る舞いのテストが赤にならなければ、テストの検証力を疑って書き直す。
12. テストを通す最小の実装を書いて緑にし、形を整える判断は次の段へ譲る。
13. 緑の間に感じた痛みと臭いを手がかりに、現在の目的に必要な構造改善を [refactoring](./refactoring.md) に従って進める。
    異なる取り消し理由を持つ改善は別の作業単位へ分け、現在の単位を 15 から 19 で検証して確定した後に着手する。
14. 緑になった項目を外し、同じ目的に必要な残りの振る舞いは 5 から 13 を繰り返す。
    現在の目的を満たしたら 15 から 19 へ進み、異なる目的の振る舞いは次の作業単位へ分ける。
15. 公開 interface から観測できる振る舞いを変えた作業単位では、変えた振る舞いと、それと組み合わさる機能を対象に探索的テストを行う([structure/tests/methods](../structure/tests/methods.md) に従う)。
16. 探索で見つけた欠陥はテストリストへ足してリストが空になるまで 5 から 14 を繰り返し、仕様の漏れは [design](./design.md) へ戻す。
17. 手順16を終えた時点で、探索の記録を取り除く([structure/tests/methods](../structure/tests/methods.md) に従う)。
18. 変更が触れた規律の完了条件・禁止事項と、[structure/tests](../structure/tests/layout.md) の機械検証に照合する。
19. 現在の目的に属する差分だけを選別し、変更の Why を短い件名へ記録して commit する([principles/documentation](../principles/documentation/commit-purpose.md) に従う)。
    別の目的の変更と構造改善をまとめてから分割せず、単位ごとの検証と commit を積み上げる。

## 確認点

新しい依存を表す型か想定内の失敗を表す型が必要な場合は、最小の新型の宣言と利用側の公開 signature か consumer への接続を同じ段階で行ったことを確かめる。
新しい型・関数・ファイル・抽象・設定・依存に、[principles/construction](../principles/construction/reuse-before-new.md) の「新しい要素を最後に選ぶ」で先行する段を退ける根拠があることを確かめる。
型宣言を利用側へ接続せずに追加することと、未定義の型を参照することを、型検査の赤として扱わない。
最初の型検査の赤が、既存の implementation か caller と新しい型との不整合から生じていることを確かめる。
新型を利用側へ接続しても対象の不整合が起きない場合は、振る舞いのテストを最初の赤にしたことを確かめる。
初回の振る舞いのテストが、公開 interface を越す最小のuse-caseを検証していることを確かめる。
想定内の失敗を、成功の値の側の閉じた型へ入れていないかを確かめる([concerns/effect](../concerns/effect/typed-requirements-failures.md) の「要求と想定内失敗を型に現す」に照合する)。失敗の型が空のまま全ての計算が成功しうる形になっていれば、赤の立て方が誤っている。
作業中に気づいた振る舞いは、その場で実装せず、テストリストへ足す。
テスト名とテスト本体が、内部実装でなく、検証対象、条件、外から観測できる期待結果を表すことを確かめる([principles/naming](../principles/naming/README.md) と [principles/verification](../principles/verification/README.md) に照合する)。
アクターとuse-caseへの帰属は、テストを書く段で確かめ、refactor の段へ先送りしない([principles/separation](../principles/separation/split-by-change-reason.md) の「変更理由で分ける」に照合する)。
直和へ新しい場合を追加するときは、新しい arm を足し、既存の arm の本文が変わっていないことを確かめる([principles/construction](../principles/construction/decisions-as-types.md) の「業務判断を型と多態で構造化する」に照合する)。
緑にする作業を機械に任せた場合も、痛みと臭いの知覚と言語化を省かない([principles/evolution](../principles/evolution/improve-touched-scope.md) の「触れた範囲を構造改善する」に従う)。
実装を書いた後のアクターと処理の図示照合は、[design](./design.md) の確認点に従う。
変更したコードを、[principles/legibility](../principles/legibility/code-as-documentation.md) の「コードを第一級の文書として明瞭に書く」の完了条件と禁止事項に照合する。
コメントを、[principles/comment](../principles/comment/README.md) の各規律の完了条件と禁止事項に照合する。
テストの技法と有効性の検査は [structure/tests/methods](../structure/tests/methods.md) に従う。
公開 interface から観測できる振る舞いを変えた作業単位では、手順17で記録を取り除く前に、探索の記録が charter、触れた範囲、見つけた事象を持ち、見つけた欠陥がテストリストを経て自動の検証へ、仕様の漏れが [design](./design.md) へ移されていることを確かめる([structure/tests/methods](../structure/tests/methods.md) に照合する)。
作業単位の終わりに、読み手がその作業単位の中だけにいた文書が残っていないことを、[principles/documentation](../principles/documentation/separate-document-types.md) の「文書の種別を分け、読み手を定める」の完了条件に照合する。

## 範囲外

リリースの可否は扱わない。
