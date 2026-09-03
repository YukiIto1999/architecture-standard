# CSharpier

用途は、表記を道具の既定で一意に揃える formatter である。
採用は、C# は CSharpier である。
判断基準は、既定の設定で出力が一意に決まることである。
CSharpier は、設定項目を少数に絞った opinionated な formatter で、整形の細部を設定で変える余地が狭い。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と oxfmt の安定版のリリースを再評価のトリガーとする。

## 命名と整形を道具に委ねる

### 要求
production project の命名は、.NET の命名規約に従う。
test project では、test attribute が付いた entry method だけを .NET の命名規約の例外とし、検証する仕様を文で表す英語の snake_case にする。
test project の test entry method 以外の命名は、.NET の命名規約に従う。
ファイル名は、そのファイルの変更単位の型の名前に PascalCase で一致させる。
整形は、CSharpier の既定に従う。

### 根拠
[verification](../../principles/verification.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、CSharpier で応える。
ファイル名を変更単位の型に PascalCase で一致させると、型を名前で探すときにファイルが一意に定まる。
test entry の名前は API でなく仕様の見出しなので、文として読める snake_case が失敗一覧の走査を速くする。
test helper まで snake_case にすると、同じ役割の method の命名が production と test で分かれる。

### 完了条件
production project の命名が、.NET の命名規約に従っている。
test project で test attribute が付いた entry method の名前が、仕様を表す英語の snake_case の文になっている。
test project の test entry method 以外の命名が、.NET の命名規約に従っている。
ファイル名が、変更単位の型の名前に PascalCase で一致している。
整形が、CSharpier の既定で一意に決まっている。

### 禁止事項
整形を、手で揃えること。
ファイル名を、変更単位の型と違う名前や、kebab-case などの別の表記にすること。
test entry に、production project と同じ method 命名規則を適用すること。
test project の entry 以外の method を、snake_case にすること。

### 行動
production project では、SonarAnalyzer.CSharp の命名規則を適用する。
test project では、SonarAnalyzer.CSharp の命名規則を適用し、test entry と競合する method 命名規則だけを抑止する。
test project では、命名 analyzer で test attribute が付いた entry method を snake_case として検査する。
test project では、命名 analyzer で entry 以外の method を .NET の命名規約として検査する。
CSharpier を、既定の設定で適用する。
ファイル名を、変更単位の型の PascalCase の名前に一致させる。
