# Dapper

用途は、手書き SQL の実行結果を型へ薄く写す永続化アクセス層である。
採用は、C# は Npgsql の上の Dapper である。
判断基準は、SQL を隠さず、結果を型へ写す処理の実行時間と割当量が project の性能要件を満たし、変更追跡を持ち込まないことである。
フル ORM は SQL を不透明にしたり、変更追跡で確定の時点を暗黙にしたりするため採らない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 型付き SQL

### 要求
永続化は、SQL を隠さず結果を型へ薄く写す。
これを Npgsql の上の Dapper で満たす。
SQL の値は parameter で渡し、文字列の連結で組み立てない。
フル ORM と変更追跡を持ち込まない。
DapperAOT の対応範囲で SQL 結果から型への写像を生成し、採用する SQL dialect で実際に適用される診断だけを補助検査として使う。
SQL の placeholder と parameter member の対応、および列の型と nullable の対応は、schema と SQL と parameter の型と DTO を突き合わせる照合テストで、DB を起動せずに検証する。
schema の変更は grate で、up の one-time script として forward-only に適用する。

### 根拠
Dapper は ADO.NET provider 越しに SQL を実行し、Npgsql で受けた PostgreSQL の結果を型へ写す。
値を parameter で渡せば、値が SQL として解釈されず、injection を防げる。
DapperAOT は対応する呼出しの写像をビルド時に生成し、SQL の利用に対する診断も提供する。
DapperAOT の SQL Server 向けの構文解析を、PostgreSQL の SQL に対する保証として数えない。
DapperAOT の診断だけでは PostgreSQL の parameter 対応や DB の schema に基づく列の型と nullable の対応を保証しないため、schema、SQL、parameter の型、DTO の照合で補う。
写像の生成、SQL の補助診断、型と nullable の照合は異なる保証であり、性能の比較と最適化は [concerns/performance](../../concerns/performance/README.md) に従う。
grate は素の SQL を CLI で適用し、履歴に記録された one-time script を再実行せず、適用後の改変を既定で失敗にする。
migration を言語の class に包まないので、schema の変更が SQL のまま履歴に残る。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が、Npgsql の上の Dapper の薄い写像で書かれている。
SQL の値が parameter で渡され、文字列の連結で組み立てられていない。
変更追跡を、持ち込んでいない。
DapperAOT が対応する呼出しの写像に適用され、生成が適用された呼出しと通常の Dapper に残る呼出しを区別できる。
適用される補助診断がエラーとして扱われ、SQL と parameter の型の名前対応と、schema と SQL と DTO の型と nullable の対応が、DB を起動しない照合テストで検証されている。
schema の変更が、grate の up の one-time script として forward-only に適用されている。
適用済み one-time script の改変が、grate の既定設定で失敗する。

### 禁止事項
SQL の値を、文字列の連結や補間で組み立てること。
変更追跡で、確定の時点を暗黙にすること。
SQL の補助診断だけで、schema と SQL と DTO の型および nullable の対応を検証済みとすること。
列の型と nullable の対応を、DB 起動を要する検証だけに委ねること。
適用済み one-time script の改変を、警告または無視へ弱めること。

### 行動
SQL を Dapper で書き、値を parameter で渡す。
DapperAOT が生成した写像の適用箇所を確認し、採用する dialect で実際に適用される診断をエラーへ昇格する。
schema の変更は up の one-time script として書き、grate の CLI をリポジトリの検証入口から非対話で実行する。
適用済み one-time script の改変を失敗にする既定設定を維持する。
schema と SQL と parameter の型と DTO を突き合わせる照合テストを書き、リポジトリの検証入口で実行する。

### 例
値を SQL 文字列へ連結すると、値が SQL として解釈される。

```csharp
var sql = $"SELECT * FROM users WHERE email = '{email}'";
var user = connection.QueryFirstOrDefault<User>(sql);
```

parameter で渡せば、値は SQL として解釈されない。

```csharp
var user = connection.QueryFirstOrDefault<User>(
    "SELECT * FROM users WHERE email = @Email", new { Email = email });
```
