# conventions

## 概要
conventions は、C# で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment.md) が定めるドキュメントコメントの契約を、C# の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・retention・coordination・publication・inspection の全てに一様に適用する。

## 命名と整形を道具に委ねる

### 要求
命名と整形は .NET の命名規約と CSharpier の既定に従い、手で揃えない。
ファイル名は、そのファイルの変更単位の型の名前に PascalCase で一致させる。

### 根拠
[verification](../../principles/verification.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、CSharpier で応える。
ファイル名を変更単位の型に PascalCase で一致させると、型を名前で探すときにファイルが一意に定まる。

### 完了条件
命名が、.NET の命名規約に従っている。
ファイル名が、変更単位の型の名前に PascalCase で一致している。
整形が、CSharpier の既定で一意に決まっている。

### 禁止事項
整形を、手で揃えること。
ファイル名を、変更単位の型と違う名前や、kebab-case などの別の表記にすること。

### 行動
.NET の命名規約に従い、CSharpier を既定の設定で適用する。
ファイル名を、変更単位の型の PascalCase の名前に一致させる。

## ドキュメントコメントを書く

### 要求
宣言した型とメンバに XML ドキュメントコメントを付ける。
対象が持つ param・typeparam・returns・value・exception を省かない。
想定された失敗は returns の Result の型に現し、exception は欠陥に限る。
summary の最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、体言止めで一行に書き、句読点を使わない。

### 根拠
XML ドキュメントコメントは、利用者が実装を読まずに、IntelliSense と生成文書から用途と契約を読めるようにする。
param は、コンパイラが引数との対応を検証し、記述漏れを警告する。
exception は、戻り値に現れない欠陥としての送出を宣言し、想定された失敗は returns の Result の型に現す。
最初の一行は検索や一覧で要素の目的を示す要約として再利用されるので、体言止めと句読点の排除は短い断片を一覧で走査しやすくする。

### 完了条件
宣言した型とメンバに、用途と契約を述べる XML ドキュメントコメントがある。
対象が持つ param・typeparam・returns・value・exception が、網羅されている。
summary の最初の一行が、名前の直訳でなく利用者が用途を判断できる目的を、句読点なしの体言止めで一行に示している。

### 禁止事項
宣言した型やメンバの契約を、未記述で放置すること。
対象が持つ param・typeparam・returns・value・exception を、省くこと。
summary の最初の一行を、句読点や動詞終わりの完結した文で書くこと。

### 行動
宣言ごとに目的の summary を一行で書き、引数・型引数・戻り値・プロパティ値・送出する例外のうち該当するものをすべて記す。
summary の最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、句読点のない体言止めで書く。

### 例
```csharp
/// <summary>検証済みカートの確定と在庫引当</summary>
/// <param name="cart">確定対象の検証済みカート</param>
/// <returns>確定済みの注文または在庫不足の失敗</returns>
/// <exception cref="InvalidOperationException">保存済みの注文が不変条件に違反している</exception>
public Result<Order, OrderError> Place(ValidCart cart) { /* ... */ }
```

## 型名の接尾辞を役割で揃える

### 要求
永続化から読んだ行を表す型には Record を付ける。
境界の wire の型には Request・Response を付ける。
一方の型からもう一方への変換を担う型には Mapper を付ける。

### 根拠
役割ごとに接尾辞を揃えると、型の名前だけで永続化の行か境界の wire か変換かが区別でき、同じ業務概念を指す型が複数あっても取り違えない。

### 完了条件
永続化から読んだ行の型名が、Record で終わっている。
境界の wire の型名が、Request または Response で終わっている。
変換を担う型の名前が、Mapper で終わっている。

### 禁止事項
役割の異なる型に、同じ接尾辞を付けること。
接尾辞なしに、役割を型名から判別できない名前を付けること。

### 行動
永続化の行の型は `<対象>Record`、境界の wire の型は `<対象>Request`・`<対象>Response` の名前にする。
変換を担う型は `<対象>Mapper` の静的クラスにする。

### 例
```csharp
// 役割が名前から読み取れない
public sealed record Order { /* DB の行 */ }
public sealed record OrderIn { /* wire */ }

// 接尾辞で役割を揃える
public sealed record OrderRecord { /* 永続化の行 */ }
public sealed record CreateOrderRequest { /* 境界の入力 */ }
public sealed record OrderResponse { /* 境界の出力 */ }
public static class OrderMapper { public static OrderResponse ToResponse(OrderRecord record) => new(/* ... */); }
```

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment.md)、型の規律は [types](../../concerns/types.md)、整形の機械化は [verification](../../principles/verification.md) に従う。
永続化から読んだ行の型は [retention](./retention.md)、境界の wire の型は [translation](./translation.md) に従う。
