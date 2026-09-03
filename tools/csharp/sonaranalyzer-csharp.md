# SonarAnalyzer.CSharp

用途は、規則の違反をビルドで止める linter である。
採用は、C# は SonarAnalyzer.CSharp である。
判断基準は、[csharp](./inspection.md) の inspection が割り当てる規則を C# の全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Vite Plus の統合 CLI(vp)の 1.0 到達を再評価のトリガーとする。

## 予防

### 要求
linter は SonarAnalyzer.CSharp を使い、その警告を検証入口でエラーとして扱う。
ファイル・関数の大きさとネストの深さのしきい値は SonarAnalyzer.CSharp の S104(ファイル)・S138(関数)・S134(ネスト)の規則として定め、既定値から緩める変更は project の ADR に明記する。
集合の添字による裸ループは、S3267 で検出し、LINQ の名前のある操作へ直す。
認知的複雑さの測り方は、[sonarqube](../platforms/sonarqube.md) の「cognitive complexity を一箇所で測る」に従い、SonarAnalyzer.CSharp のビルド時 lint 側では複雑度の規則を重ねて有効にしない。

### 根拠
S104・S138・S134 は、ファイル・関数の大きさとネストの深さを早く気づかせる。
S3267 は [named-collection-operations](../../principles/construction/named-collection-operations.md) の「集合処理を名前のある操作で表す」を裸ループの検出として機械化する。
既定から緩める判断を ADR に残せば、緩和の理由が追える。

### 完了条件
SonarAnalyzer.CSharp が、linter として使われている。
ファイル・関数の大きさとネストの深さのしきい値が、S104・S138・S134 の規則として定められている。
S3267 が有効で、違反が検証入口でエラーとして扱われている。
緩和が、project の ADR に明記されている。
SonarAnalyzer.CSharp のビルド時 lint 側で、複雑度の規則が有効になっていない。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
cognitive complexity を、SonarAnalyzer.CSharp のビルド時 lint 側で有効にすること。

### 行動
SonarAnalyzer.CSharp を linter として導入し、S104・S138・S134 のしきい値を定める。
