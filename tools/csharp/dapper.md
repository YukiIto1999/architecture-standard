# Dapper

用途は、SQL を型で扱いながら書く永続化アクセス層である。
採用は、C# は Npgsql の上の Dapper である。
判断基準は、SQL を隠さず、事実の形がそのまま型に写ることである。フル ORM は SQL を不透明にしたり、変更追跡で確定の時点を暗黙にしたりするため採らない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 型付き SQL

### 要求
永続化は、SQL を隠さず結果を型へ薄く写す。これを Npgsql の上の Dapper で満たす。
SQL の値は parameter で渡し、文字列の連結で組み立てない。
フル ORM と変更追跡を持ち込まない。
SQL 中の変数と parameter の対応は DapperAOT を有効にして検査する。
列の型と nullable の対応は、SQL から抽出した列挙と DTO のプロパティを突き合わせる照合テストで、DB を起動せずに検証する。
schema の変更は grate で、up の one-time script として forward-only に適用する。

### 根拠
Dapper は SQL を隠さず、薄い写像で結果を型に移す。
値を parameter で渡せば、値が SQL として解釈されず、injection を防げる。
DapperAOT はソース生成に基づくビルド時解析で、DB へ接続せずに SQL 中の変数と parameter の対応を検査する。
PostgreSQL は DapperAOT の既定の照合にとどまり、SQL Server 向けの高精度な構文解析を持たないため、名前対応の検査が部分的にとどまる。
DapperAOT は DB のスキーマを参照しないため、列の型と nullable の対応は対象外であり、SQL と DTO を突き合わせる照合テストで別に埋める必要がある。
単一のツールで名前・型・nullable の対応すべてを検証できないため、二つの手段を組み合わせて観測可能にする。
grate は素の SQL を CLI で適用し、履歴に記録された one-time script を再実行せず、適用後の改変を既定で失敗にする。
migration を言語の class に包まないので、schema の変更が SQL のまま履歴に残る。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が、Npgsql の上の Dapper の薄い写像で書かれている。
SQL の値が parameter で渡され、文字列の連結で組み立てられていない。
変更追跡を、持ち込んでいない。
DapperAOT が有効になっており、SQL 中の変数と parameter の対応が検査されている。
列の型と nullable の対応が、DB を起動しない照合テストで検証されている。
schema の変更が、grate の up の one-time script として forward-only に適用されている。
適用済み one-time script の改変が、grate の既定設定で失敗する。

### 禁止事項
SQL の値を、文字列の連結や補間で組み立てること。
変更追跡で、確定の時点を暗黙にすること。
parameter の対応検証を、単一のツールで完結すると称すること。
列の型と nullable の対応を、DB 起動を要する検証だけに委ねること。
適用済み one-time script の改変を、警告または無視へ弱めること。

### 行動
SQL を Dapper で書き、値を parameter で渡す。
DapperAOT を導入し、名前対応の診断をエラーへ昇格する。
schema の変更は up の one-time script として書き、grate の CLI をリポジトリの検証入口から非対話で実行する。
適用済み one-time script の改変を失敗にする既定設定を維持する。
SQL から抽出した列挙と DTO のプロパティを突き合わせる照合テストを書き、リポジトリの検証入口で実行する。

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
