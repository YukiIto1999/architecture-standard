# retention

## 概要
retention は、C# で永続化と共有される状態を扱う実現軸である。
principles の [data](../../principles/data.md) が定める事実の追記と、concerns の [persistence](../../concerns/persistence.md) が定める永続データの設計・[transaction](../../concerns/transaction.md) が定める一つの書き込みパスと確定点を、C# の機構で満たす。
並行更新の表面は、状態の遷移をイベントの追記として表し、version の一意制約で衝突を検出する。

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
grate は素の SQL を専用の CLI で適用し、up の script を一度だけ実行して、適用済み script の改変を既定で失敗にする。
migration を言語の class に包まないので、schema の変更が SQL のまま履歴に残る。
forward-only の規律そのものは [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。

### 完了条件
永続化が、Npgsql の上の Dapper の薄い写像で書かれている。
SQL の値が parameter で渡され、文字列の連結で組み立てられていない。
変更追跡を、持ち込んでいない。
DapperAOT が有効になっており、SQL 中の変数と parameter の対応が検査されている。
列の型と nullable の対応が、DB を起動しない照合テストで検証されている。
schema の変更が、grate の up の one-time script として forward-only に適用されている。

### 禁止事項
SQL の値を、文字列の連結や補間で組み立てること。
変更追跡で、確定の時点を暗黙にすること。
parameter の対応検証を、単一のツールで完結すると称すること。
列の型と nullable の対応を、DB 起動を要する検証だけに委ねること。

### 行動
SQL を Dapper で書き、値を parameter で渡す。
DapperAOT を導入し、名前対応の診断をエラーへ昇格する。
schema の変更は up の one-time script として書き、grate の CLI を CI から非対話で実行する。
SQL から抽出した列挙と DTO のプロパティを突き合わせる照合テストを書き、CI で実行する。

### 例
```csharp
// 文字列の連結。値が SQL として解釈され injection を招く
var sql = $"SELECT * FROM users WHERE email = '{email}'";
var user = connection.QueryFirstOrDefault<User>(sql);

// parameter で渡す。値は SQL として解釈されない
var user = connection.QueryFirstOrDefault<User>(
    "SELECT * FROM users WHERE email = @Email", new { Email = email });
```

## 並行更新の表面

### 要求
版の衝突は、状態の遷移をイベントとして追記し、version への一意制約違反として検出する。
制約違反は競合の Result に写す。

### 根拠
状態カラムを compare-and-set の UPDATE で上書きすると、遷移の事実そのものが行として残らず、persistence が定める事実を追記する規律に反する。
遷移をイベントとして追記し `(OrderId, Version)` に一意制約を課せば、同じ version への同時挿入はどちらか一方だけが通り、他方は制約違反になる。
Npgsql は制約違反を `PostgresException` で送出し、`SqlState` が `PostgresErrorCodes.UniqueViolation` のとき一意制約違反と判別できる。
制約違反を検出して競合の Result に写せば、競合が型に現れ呼び出し側が扱える。

### 完了条件
version の衝突が、`(OrderId, Version)` の一意制約違反として検出されている。
競合が、Result で返されている。
状態の遷移が、行の追記で表されている。

### 禁止事項
状態カラムを直接 UPDATE で上書きし、遷移の事実を追記せずに競合を検出すること。
version の一意制約違反を、検出せずに上書きすること。

### 行動
状態の遷移を `order_events` のようなイベント表への INSERT で表し、version を `(OrderId, Version)` の一意制約の対象に含める。
挿入が一意制約違反で失敗したら、競合の Result に写す。

### 例
```csharp
// 競合を型付きの失敗として表す閉じた階層
public abstract record WriteError { private WriteError() { } public sealed record Conflict : WriteError; }

// 遷移をイベントとして追記し、(OrderId, Version) の一意制約で衝突を検出する
try
{
    await connection.ExecuteAsync(
        "INSERT INTO order_events (order_id, version, payload) VALUES (@OrderId, @Version, @Payload)",
        new { OrderId = id, Version = expectedVersion + 1, Payload = payload }, transaction);
    return Result.Success<Order, WriteError>(order);
}
catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
{
    return Result.Failure<Order, WriteError>(new WriteError.Conflict()); // UNIQUE(order_id, version) 違反を競合に写す
}
```

## 書き込みパス

### 要求
composition が所有する UnitOfWork は Npgsql の transaction で実装し、store は受け取った transaction の中で書く。

### 根拠
store が transaction を握ると、業務判断と確定の制御が混ざり、複数の store をまたぐ一つの確定ができない。
composition が transaction を所有し store が受け取った transaction の中で書けば、確定点が一つに定まる。
一つの確定点に集めれば、状態とイベントを同一のパスで記録できる。

### 完了条件
UnitOfWork が、composition の所有する Npgsql の transaction で実装されている。
store が、受け取った transaction の中で書いている。
確定点が、一つである。

### 禁止事項
store が、transaction の begin・commit を所有すること。

### 行動
composition で transaction を begin し、store に渡して書かせ、composition で commit する。

### 例
```csharp
// composition が transaction を所有する。確定点は一つ
await using var connection = await _dataSource.OpenConnectionAsync();
await using var transaction = await connection.BeginTransactionAsync();
await orderStore.InsertAsync(connection, transaction, order);
await outbox.AddAsync(connection, transaction, new OrderPlaced(order.Id)); // 状態とイベントを同一パスで
await transaction.CommitAsync();                                       // 唯一の確定点
```

## 一時データ

### 要求
session や cache のような寿命の短い共有状態は永続化の DB と分けて扱い、Valkey への接続は StackExchange.Redis で行う。

### 根拠
寿命の短い一時データを永続化の DB に混ぜると、寿命の違うデータが同じ確定点と制約に縛られる。
Valkey に分け、接続を StackExchange.Redis の一つの機構に固定すれば、寿命の短い共有状態を独立に扱える。

### 完了条件
寿命の短い一時データが、永続化の DB と分けて Valkey で扱われている。
Valkey への接続が、StackExchange.Redis で行われている。

### 禁止事項
寿命の短い一時データを、永続化の DB に置くこと。

### 行動
一時データを Valkey に置き、接続を StackExchange.Redis で行う。

## 参照
事実の追記は [data](../../principles/data.md)、永続データの設計は [persistence](../../concerns/persistence.md)、確定点は [transaction](../../concerns/transaction.md)、永続化の置き場は [structure/core/infrastructure](../../structure/core/infrastructure.md) に従う。
