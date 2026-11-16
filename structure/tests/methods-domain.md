# tests の方法: ドメインと権限

この file は、[methods](./methods.md) が対象別に分けた技法のうち、ドメイン型の計算・比較・区分判断・集合の操作と、権限の matrix の検証を定める。
検査の選択、性質と入力領域、規範から検証への割当は [methods](./methods.md) に従う。

## ドメイン型と操作

値の計算と比較は [principles/modeling](../../principles/modeling/meaning-in-types.md) の「業務の意味を型に封じる」に、区分に基づく判断は [principles/construction](../../principles/construction/decisions-as-types.md) の「業務判断を型と多態で構造化する」に、集合の業務操作は [named-collection-operations](../../principles/construction/named-collection-operations.md) の「集合処理を名前のある操作で表す」に照合する。
入力の取り違え、許されない操作、不正な状態の構築を型で拒める場合は、その拒否を型検査へ割り当てる。
型の操作が返す計算・比較・判断・集計の結果は、業務の契約から導く独立した期待値で検証し、型が付くことだけで意味の正しさを保証したとみなさない。
集合は、各要素が妥当でも集合として不正になる入力を、集合の構築と操作の拒否へ割り当てる。
区分の処理網羅は型検査または型情報を使う静的検査へ割り当て、業務分類の妥当性は、分類対象と分類条件から定めた入力と独立した期待値で検証する。
排他的な分類では、対象がちょうど一つの場合に属することを確かめ、宣言した区分値の列挙だけで分類条件の重なりと欠落を検証したとみなさない。
業務区分と公開区分・保存値の対応は、境界の変換結果を契約の意味へ照合し、生成物の drift と往復の成功だけで対応の意味まで検証したとみなさない。

## 権限

権限は、主体・操作・資源・条件と、期待する許可と拒否の組み合わせの matrix で検証する。
matrix は、公開された interface を越して検証する。
権限の matrix は、業務の振る舞いの検証として対象に含める。
権限の規律は [concerns/authorization](../../concerns/authorization/README.md) に従う。
