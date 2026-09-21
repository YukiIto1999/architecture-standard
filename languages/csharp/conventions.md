# conventions

## 概要
conventions は、C# で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment/README.md) が定めるドキュメントコメントの契約を、C# の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・coordination・publication・inspection の全てに一様に適用する。

## ドキュメントコメントを書く

### 要求
宣言した型とメンバに XML ドキュメントコメントを付ける。
実効的な可視境界を基準に、境界外の利用側へ公開される宣言は外部契約を、同一境界内だけで利用できる宣言は内部契約を述べる。
対象が持つ param・typeparam・returns・value を省かない。
当該宣言内の直接の throw など、構文と semantic model で判定できる欠陥を exception に記す。
呼び出し先から伝播して当該宣言の契約になる欠陥を、公開範囲を問わずレビューで特定し、exception に記す。
想定された失敗は returns の Result の型に現し、exception は欠陥に限る。
summary の最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、体言止めで一行に書き、句読点を使わない。

### 根拠
XML ドキュメントコメントは、利用者が実装を読まずに、IntelliSense と生成文書から用途と契約を読めるようにする。
可視性に応じて外部契約と内部契約を分ければ、呼び出し側が依存してよい保証の範囲が明らかになる。
param は、コンパイラが引数との対応を検証し、記述漏れを警告する。
直接の throw などは構文と semantic model で対応する exception を検査できる。
呼び出し先から伝播する欠陥が当該宣言の契約に含まれるかは意味の判断を要するため、analyzer だけでは網羅できない。
exception は、戻り値に現れない欠陥としての送出を宣言し、想定された失敗は returns の Result の型に現す。
最初の一行は検索や一覧で要素の目的を示す要約として再利用されるので、体言止めと句読点の排除は短い断片を一覧で走査しやすくする。

### 完了条件
宣言した型とメンバに、用途と契約を述べる XML ドキュメントコメントがある。
境界外の利用側へ公開される宣言が外部契約を、同一境界内だけで利用できる宣言が内部契約を述べている。
対象が持つ param・typeparam・returns・value が、網羅されている。
当該宣言内で機械判定できる欠陥が、exception に記されている。
呼び出し先から伝播して当該宣言の契約になる欠陥が、公開範囲を問わずレビューで特定され exception に記されている。
summary の最初の一行が、名前の直訳でなく利用者が用途を判断できる目的を、句読点なしの体言止めで一行に示している。

### 禁止事項
宣言した型やメンバの契約を、未記述で放置すること。
境界外の利用側へ公開される宣言の契約を、同一境界内だけに通用する内部契約として書くこと。
対象が持つ param・typeparam・returns・value を、省くこと。
当該宣言内で機械判定できる欠陥を、exception から省くこと。
呼び出し先から伝播する欠陥まで、analyzer で網羅できるとみなすこと。
summary の最初の一行を、句読点や動詞終わりの完結した文で書くこと。

### 行動
宣言ごとに目的の summary を一行で書き、引数・型引数・戻り値・プロパティ値を記す。
実効的な可視境界を確かめ、境界外へ公開される宣言は外部の利用側が、同一境界内だけの宣言は内部の呼び出し側が依存してよい保証を書く。
当該宣言内で機械判定できる欠陥を、exception に記す。
全ての宣言で呼び出し先から伝播する欠陥をレビューし、当該宣言の契約に含まれる欠陥を exception に記す。
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
汎用的な名前では、永続化、境界入力、境界出力の役割を判別できない。

```text
Order
OrderIn
```

接尾辞で役割を揃える。

```text
OrderRecord
CreateOrderRequest
OrderResponse
OrderMapper
```

## 命名と整形を道具に委ねる

### 要求
production project の命名は、.NET の命名規約に従う。
test project では、test attribute が付いた entry method だけを .NET の命名規約の例外とし、検証する仕様を文で表す英語の snake_case にする。
test project の test entry method 以外の命名は、.NET の命名規約に従う。
ファイル名は、そのファイルの変更単位の型の名前に PascalCase で一致させる。
整形は、CSharpier の既定に従う。

### 根拠
[verification](../../principles/verification/README.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、CSharpier で応える。
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

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment/README.md)、型の規律は [types](../../concerns/types/README.md) に従う。
永続化から読んだ行の型は [dapper](./dapper.md)、境界の wire の型は [translation](./translation.md) に従う。
