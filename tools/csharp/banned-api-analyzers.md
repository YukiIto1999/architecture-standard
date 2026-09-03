# Microsoft.CodeAnalysis.BannedApiAnalyzers

用途は、禁止した API の呼び出しを、ビルドで検出する検査である。
採用は、C# は Microsoft.CodeAnalysis.BannedApiAnalyzers である。
判断基準は、禁止の一覧を設定として宣言でき、違反をリポジトリの検証入口でエラーとして扱えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 直読と自由文出力を禁止 API で止める

### 要求
BannedSymbols.txt に System.Environment.GetEnvironmentVariable と System.Console の書き込み API を登録し、違反を検証入口のエラーとして扱う。
設定の読み込みは、組立点の設定 provider だけに許可する。
console への出力は、console surface の出力層だけに許可する。
許可は、該当 project にだけ別の BannedSymbols.txt を置く形で表す。

### 根拠
環境変数の直読は [single-config-source](../../concerns/configuration/single-config-source.md) の「定めた源からまとめて読む」に反する散在を作るため、禁止 API の一覧がビルドで止める。
自由文の console 出力は [structured-events](../../concerns/observability/structured-events.md) の「事実をイベントとして表し、構造化して出す」を素通りするため、同じ一覧で止める。
許可を project 単位の BannedSymbols.txt の分離で表せば、逸脱の範囲が設定として可視化される。

### 完了条件
System.Environment.GetEnvironmentVariable と System.Console の書き込み API が、BannedSymbols.txt に登録されている。
違反が、検証入口でエラーとして扱われている。
許可が、設定 provider を持つ組立点と console surface の出力層の project に限られている。

### 禁止事項
組立点の外で環境変数を直読すること。
telemetry を経ない自由文の console 出力を業務コードに置くこと。
禁止の一覧を空にして検査を無効化すること。

### 行動
BannedSymbols.txt へ禁止 API を登録し、違反箇所は設定の注入と telemetry の port へ直す。
許可が要る project には、範囲を絞った BannedSymbols.txt を置き、理由を project の ADR に記録する。

