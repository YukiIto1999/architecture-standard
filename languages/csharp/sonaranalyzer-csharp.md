# SonarAnalyzer.CSharp

用途は、規則の違反をビルドで止める linter である。
採用は、C# は SonarAnalyzer.CSharp である。
判断基準は、[csharp](./inspection.md) の inspection が割り当てる規則を C# の全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、許諾の範囲または配布条件の変更を再評価のトリガーとする。

## 予防

### 要求
linter は SonarAnalyzer.CSharp を使い、その警告を検証入口でエラーとして扱う。
規則の重大度は .editorconfig を正本とし、SonarAnalyzer の規則のしきい値 parameter だけを SonarLint.xml に置く。同じ関心を両方のファイルへ書かない。
ファイル・関数の大きさとネストの深さのしきい値は SonarAnalyzer.CSharp の S104(ファイル)・S138(関数)・S134(ネスト)の規則として定め、既定値から緩める変更は project の決定の記録に明記する。
集合の添字による裸ループは、S3267 で検出し、LINQ の名前のある操作へ直す。
未使用の要素と未使用の参照は、コンパイラと analyzer の到達可能性の診断を検証入口でエラーとして扱い検出する。
関数の複雑さは、[structure/tests の methods](../../structure/tests/methods.md) の「構造の検証」に従い、SonarAnalyzer.CSharp の S3776 で測る。
S3776 は既定で無効なので、.editorconfig で重大度を error にし、しきい値は SonarLint.xml の threshold parameter に置く。
基線台帳に記録した既存の違反は、その member の `SuppressMessage` で抑止し、Justification に理由を書く。

### 根拠
S104・S138・S134 は、ファイル・関数の大きさとネストの深さを早く気づかせる。
S3267 は [named-collection-operations](../../principles/construction/named-collection-operations.md) の「集合処理を名前のある操作で表す」を裸ループの検出として機械化する。
S3776 は switch を case の数によらず一度だけ加点するので、閉じた直和の網羅を罰さない。
S3776 をビルド時の analyzer で測れば、違反が検証入口の出力として変更の場で返る。
不要になった抑止を報告する IDE0079 はビルドで有効にできないため、直した後に残った抑止は基線台帳の照合で取り除く。
既定から緩める判断を決定の記録に残せば、緩和の理由が追える。

### 完了条件
SonarAnalyzer.CSharp が、linter として使われている。
ファイル・関数の大きさとネストの深さのしきい値が、S104・S138・S134 の規則として定められている。
S3267 が有効で、違反が検証入口でエラーとして扱われている。
未使用の要素と未使用の参照の診断が、検証入口でエラーとして扱われている。
緩和が、project の決定の記録に明記されている。
S3776 が .editorconfig で error になり、しきい値が [structure/tests の methods](../../structure/tests/methods.md) の値である。
S3776 の抑止が、基線台帳に記録した member の `SuppressMessage` に限られ、Justification を持っている。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
S3776 を、project・file の単位または NoWarn で抑止すること。
Justification のない `SuppressMessage` で、S3776 を抑止すること。

### 行動
SonarAnalyzer.CSharp を linter として導入し、S104・S138・S134 のしきい値を定める。
.editorconfig で S3776 を error にし、SonarLint.xml にしきい値を置き、基線台帳に記録した既存の違反の member に Justification 付きの `SuppressMessage` を付ける。
