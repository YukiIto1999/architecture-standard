# conventions

## 概要
conventions は、Rust で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment/README.md) が定めるドキュメントコメントの契約を、Rust の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・coordination・publication・inspection の全てに一様に適用する。

## 命名と整形を道具に委ねる

### 要求
命名と整形は言語の標準の命名規約と rustfmt の既定に従い、手で揃えない。
ファイルとモジュールの名前は、標準の命名規約の snake_case にする。

### 根拠
[verification](../../principles/verification/README.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、rustfmt で応える。
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
公開要素は可視境界の利用側への外部契約を、非公開要素は同一境界内の呼び出し側への内部契約を述べる。
対象が持つ `# Panics`・`# Errors`・`# Safety` を省かない。
crate とモジュールの概要は `//!` で書く。
署名の引数と型引数は名前を挙げ、戻り値は「戻り値」の語で示して、最初の一行に続く本文で述べる。
`()` を返す要素は、戻り値を持たないものとして扱う。
最初の一行とドキュメントコメントの記述の形は、principles の [comment](../../principles/comment/declaration-contracts.md) の「ドキュメントコメントは宣言の契約を書く」と、[documentation](../../principles/documentation/sentence-endings.md) の「文末の形を記述の種類で分ける」に従う。

### 根拠
rustdoc のドキュメントコメントは、利用者が実装を読まずに用途と契約を読めるようにする。
可視性に応じて外部契約と内部契約を分ければ、呼び出し側が依存してよい保証の範囲が明らかになる。
`# Panics`・`# Errors`・`# Safety` は、パニックの条件・失敗・呼び出し側が守る安全の条件を契約として宣言する。
rustdoc は引数と戻り値に専用の記法を持たないので、本文で名前を挙げて述べれば、記述と署名を対応づけて読める。

### 完了条件
宣言した要素に、用途と契約を述べる `///` のドキュメントコメントがある。
公開要素が外部契約を、非公開要素が内部契約を述べている。
パニック・失敗・安全の条件を持つ要素に、`# Panics`・`# Errors`・`# Safety` がある。
署名の引数、型引数、戻り値が、最初の一行に続く本文に述べられている。

### 禁止事項
宣言した要素の契約を、未記述で放置すること。
公開要素の契約を、同一境界内だけに通用する内部契約として書くこと。
パニック・失敗・安全の条件を持つ要素で、`# Panics`・`# Errors`・`# Safety` を省くこと。

### 行動
要素ごとに目的の一行を `///` で書き、続く本文で引数、型引数、戻り値を述べ、パニック・失敗・安全の条件があれば `# Panics`・`# Errors`・`# Safety` に記す。
公開要素は可視境界の利用側、非公開要素は同一境界内の呼び出し側が依存してよい保証を書く。

### 例
公開範囲にかかわらず、最初の一行で用途を示し、本文で引数と戻り値を述べ、該当する失敗条件を `# Errors` に書く。

```rust
/// 在庫引当を伴う検証済みカートの注文確定
///
/// - `cart`: 注文として確定する品目と数量
/// - 戻り値: 在庫を引き当てた確定済みの注文
///
/// # Errors
/// 在庫不足のとき `OrderError::OutOfStock`
pub fn place(cart: ValidCart) -> Result<Order, OrderError> { /* ... */ }
```

## 型名の接尾辞を役割で揃える

### 要求
永続化から読んだ行を表す型には Record を付ける。
binding 固有の wire envelope の型には Request・Response を付け、生成 DTO は canonical の command・query・result・view の意味の名前を保つ。
一方の型からもう一方への変換を担う専用の関数やモジュールには mapper を含む名前を付ける。

### 根拠
役割ごとに接尾辞を揃えると、型の名前だけで永続化の行か境界の wire か変換かが区別でき、同じ業務概念を指す型が複数あっても取り違えない。

### 完了条件
永続化から読んだ行の型名が、Record で終わっている。
binding 固有の wire envelope の型名が Request または Response で終わり、生成 DTO の意味の名前が canonical と対応している。
変換を担う専用の関数やモジュールの名前が、mapper を含んでいる。

### 禁止事項
役割の異なる型に、同じ接尾辞を付けること。
接尾辞なしに、役割を型名から判別できない名前を付けること。

### 行動
永続化の行の型は `<対象>Record`、binding 固有の wire envelope は `<対象>Request`・`<対象>Response` の名前にする。
生成 DTO は canonical の意味の名前を使い、接尾辞を揃えるためだけの同義 DTO や alias を追加しない。
`From`・`TryFrom` の実装でなく専用の変換関数やモジュールを置くときは、名前に mapper を含める。

### 例
役割を判別できない接尾辞では、同じ業務概念の型を取り違える。

```text
Order
OrderIn
```

永続化の行、境界の入出力、変換の役割を、接尾辞と module 名で区別する。

```text
OrderRecord
CreateOrderRequest
OrderResponse
order_mapper
```

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment/README.md)、型の規律は [types](../../concerns/types/README.md)、整形の機械化は [verification](../../principles/verification/README.md) に従う。
永続化から読んだ行の型は [sqlx](./sqlx.md)、境界の wire の型は [translation](./translation.md) に従う。
