# SonarAnalyzer.CSharp

用途は、規則の違反をビルドで止める linter である。
採用は、C# は SonarAnalyzer.CSharp である。
判断基準は、[csharp](./inspection.md)・[rust](../rust/inspection.md)・[typescript](../typescript/inspection.md) の inspection が割り当てる規則を全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Vite Plus の統合 CLI(vp)の 1.0 到達を再評価のトリガーとする。

## 予防

### 要求
linter は SonarAnalyzer.CSharp を使い、nullable reference types と analyzer の警告を検証入口でエラーとして扱う。
ファイル・関数の大きさとネストの深さのしきい値は SonarAnalyzer.CSharp の S104(ファイル)・S138(関数)・S134(ネスト)の規則として定め、既定値から緩める変更は project の ADR に明記する。
認知的複雑さは SonarQube の cognitive complexity(S3776)で測り、SonarAnalyzer.CSharp のビルド時 lint 側では複雑度の規則を重ねて有効にしない。
SonarQube の profile は cognitive complexity(S3776)に絞り、ローカル lint と同目的の規則を重ねない。

### 根拠
nullable reference types と analyzer の警告をエラーにすれば、不在の取り違えや規則の違反がビルドで止まる。
S104・S138・S134 は、ファイル・関数の大きさとネストの深さを早く気づかせる。
S3776 を SonarQube の quality gate と SonarAnalyzer.CSharp のビルド時 lint の双方で有効にすると同じ規則を二重に測ることになるため、複雑度は SonarQube 側だけで測る。
SonarQube の cognitive complexity は switch の構造化を一度だけ加点し case の数に比例しないので、閉じた階層の網羅的な switch を罰しない。
SonarQube の profile を cognitive complexity だけに絞れば、SonarAnalyzer.CSharp が既に検査する命名や未使用変数などの規則を SonarQube 側で重ねて測ることがない。
既定から緩める判断を ADR に残せば、緩和の理由が追える。

### 完了条件
nullable reference types と analyzer の警告が、検証入口でエラーとして扱われている。
SonarAnalyzer.CSharp が、linter として使われている。
ファイル・関数の大きさとネストの深さのしきい値が、S104・S138・S134 の規則として定められている。
緩和が、project の ADR に明記されている。
SonarAnalyzer.CSharp のビルド時 lint 側で、複雑度の規則が有効になっていない。
SonarQube の profile が、cognitive complexity に絞られている。

### 禁止事項
大きさと複雑さのしきい値を、既定から黙って緩めること。
閉じた階層の網羅的な switch を、複雑度の加点対象にする指標を採ること。
cognitive complexity を、SonarAnalyzer.CSharp のビルド時 lint と SonarQube の quality gate の両方で有効にすること。
SonarQube の profile に、ローカル lint と同目的の規則を重ねて有効にすること。

### 行動
nullable reference types を有効にし、警告を検証入口でエラーにする。
SonarAnalyzer.CSharp を linter として導入し、S104・S138・S134 のしきい値を定める。
複雑度は SonarQube の quality gate に一本化し、緩和は ADR に明記する。
SonarQube の profile は cognitive complexity だけに絞る。
