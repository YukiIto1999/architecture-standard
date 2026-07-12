# conventions

## 概要
conventions は、Rust で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment.md) が定めるドキュメントコメントの契約を、Rust の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・retention・coordination・publication・inspection の全てに一様に適用する。

## 命名と整形を道具に委ねる

### 要求
命名と整形は言語の標準の命名規約と rustfmt の既定に従い、手で揃えない。
ファイルとモジュールの名前は、標準の命名規約の snake_case にする。

### 根拠
[verification](../../principles/verification.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、rustfmt で応える。
ファイルとモジュールを snake_case にすると、`mod` の宣言とファイルが一意に対応する。

### 完了条件
命名が、標準の命名規約に従っている。
ファイルとモジュールの名前が、snake_case である。
整形が、rustfmt の既定で一意に決まっている。

### 禁止事項
整形を、手で揃えること。
ファイルやモジュールの名前を、snake_case 以外の表記にすること。

### 行動
標準の命名規約に従い、rustfmt を既定の設定で適用する。
ファイルとモジュールを、snake_case で名付ける。

## ドキュメントコメントを書く

### 要求
宣言した要素に `///` のドキュメントコメントを付ける。
対象が持つ `# Panics`・`# Errors`・`# Safety` を省かない。
crate とモジュールの概要は `//!` で書く。
最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、体言止めで一行に書き、句読点を使わない。

### 根拠
rustdoc のドキュメントコメントは、利用者が実装を読まずに用途と契約を読めるようにする。
`# Panics`・`# Errors`・`# Safety` は、パニックの条件・失敗・呼び出し側が守る安全の条件を契約として宣言する。
最初の一行は検索や一覧で要素の目的を示す要約として再利用されるので、体言止めと句読点の排除は短い断片を一覧で走査しやすくする。

### 完了条件
宣言した要素に、用途と契約を述べる `///` のドキュメントコメントがある。
パニック・失敗・安全の条件を持つ要素に、`# Panics`・`# Errors`・`# Safety` がある。
最初の一行が、名前の直訳でなく利用者が用途を判断できる目的を、句読点なしの体言止めで一行に示している。

### 禁止事項
宣言した要素の契約を、未記述で放置すること。
パニック・失敗・安全の条件を持つ要素で、`# Panics`・`# Errors`・`# Safety` を省くこと。
最初の一行を、句読点や動詞終わりの完結した文で書くこと。

### 行動
要素ごとに目的の一行を `///` で書き、パニック・失敗・安全の条件があれば `# Panics`・`# Errors`・`# Safety` に記す。
最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、句読点のない体言止めで書く。

### 例
```rust
/// 検証済みカートの確定と在庫引当
///
/// # Errors
/// 在庫不足のとき `OrderError::OutOfStock`
pub fn place(cart: ValidCart) -> Result<Order, OrderError> { /* ... */ }
```

## 型名の接尾辞を役割で揃える

### 要求
永続化から読んだ行を表す型には Record を付ける。
境界の wire の型には Request・Response を付ける。
一方の型からもう一方への変換を担う専用の関数やモジュールには mapper を含む名前を付ける。

### 根拠
役割ごとに接尾辞を揃えると、型の名前だけで永続化の行か境界の wire か変換かが区別でき、同じ業務概念を指す型が複数あっても取り違えない。

### 完了条件
永続化から読んだ行の型名が、Record で終わっている。
境界の wire の型名が、Request または Response で終わっている。
変換を担う専用の関数やモジュールの名前が、mapper を含んでいる。

### 禁止事項
役割の異なる型に、同じ接尾辞を付けること。
接尾辞なしに、役割を型名から判別できない名前を付けること。

### 行動
永続化の行の型は `<対象>Record`、境界の wire の型は `<対象>Request`・`<対象>Response` の名前にする。
`From`・`TryFrom` の実装でなく専用の変換関数やモジュールを置くときは、名前に mapper を含める。

### 例
```rust
// 役割が名前から読み取れない
struct Order { /* DB の行 */ }
struct OrderIn { /* wire */ }

// 接尾辞で役割を揃える
struct OrderRecord { /* 永続化の行 */ }
struct CreateOrderRequest { /* 境界の入力 */ }
struct OrderResponse { /* 境界の出力 */ }
mod order_mapper { // 変換を担うモジュールの名前に mapper を含める
    use super::*;
    pub fn to_response(record: OrderRecord) -> OrderResponse { /* ... */ }
}
```

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment.md)、型の規律は [types](../../concerns/types.md)、整形の機械化は [verification](../../principles/verification.md) に従う。
永続化から読んだ行の型は [retention](./retention.md)、境界の wire の型は [translation](./translation.md) に従う。
