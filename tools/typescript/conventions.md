# conventions

## 概要
conventions は、TypeScript で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment.md) が定めるドキュメントコメントの契約を、TypeScript の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・coordination・publication・inspection の全てに一様に適用する。
命名と整形の規律は [oxfmt](./oxfmt.md) が持つ。

## ドキュメントコメントを書く

### 要求
宣言した要素に TSDoc のドキュメントコメントを付ける。
実効的な可視境界を基準に、module 外の利用側へ公開される要素は外部契約を、同一境界内だけで利用できる要素は内部契約を述べる。
対象が持つ @typeParam・@param・@returns を省かない。
想定された失敗は戻り値の Result の型に現し、@throws は欠陥に限る。
@throws は、`@throws {@link ErrorType} 条件` の書式で書く。
当該宣言から外へ伝播すると compiler API で判定できる直接の throw に、送出型と一致する `ErrorType` の @throws を付ける。
当該宣言内の try/catch で吸収される throw は、@throws の機械検査対象にしない。
呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥に、公開範囲を問わずレビューで @throws を付ける。
summary の最初の一行は、一行で書き、句読点を使わない。
summary の最初の一行は、名前の直訳を避け、利用者が用途を判断できる目的を体言止めで書く。

### 根拠
TSDoc は、ツールが一貫して解釈できる統一文法で、利用者が実装を読まずに用途と契約を読めるようにする。
可視性に応じて外部契約と内部契約を分ければ、呼び出し側が依存してよい保証の範囲が明らかになる。
@param・@returns は、引数と戻り値を契約として宣言し、想定された失敗は戻り値の Result の型に現す。
`@microsoft/tsdoc` は `{@link ErrorType}` を link として parse でき、compiler の semantic model は link の参照先と throw 式の型を解決できる。
当該宣言から外へ出る直接の throw と try/catch で吸収される throw は、構文上の包含関係で分けられる。
呼出先や rejected Promise から伝播する欠陥が当該宣言の契約かは、呼出関係と契約の意味を読む必要がある。
最初の一行は検索や一覧で要素の目的を示す要約として再利用されるので、一行と句読点の排除は字面で検査できる。
名前の直訳でないこと、用途を判断できること、体言止めであることは意味と形態の判断を要する。

### 完了条件
宣言した要素に、用途と契約を述べる TSDoc のドキュメントコメントがある。
module 外の利用側へ公開される要素が外部契約を、同一境界内だけで利用できる要素が内部契約を述べている。
@typeParam・@param・@returns が、対象の持つものを網羅している。
@throws が、`@throws {@link ErrorType} 条件` の書式で書かれている。
当該宣言から外へ伝播すると機械判定できる直接の throw に、送出型と link の参照先が一致する @throws が付いている。
当該宣言内の try/catch で吸収される throw が、@throws の機械検査対象から除かれている。
呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥に、公開範囲を問わずレビューで @throws が付いている。
summary の最初の一行が、一行かつ句読点なしである。
summary の最初の一行が、名前の直訳でなく利用者が用途を判断できる目的を体言止めで示している。

### 禁止事項
宣言した要素の契約を、未記述で放置すること。
module 外の利用側へ公開される要素の契約を、同一境界内だけに通用する内部契約として書くこと。
対象が持つ @typeParam・@param・@returns を、省くこと。
当該宣言の契約になる欠陥の @throws を、省くこと。
@throws の error type を、`{@link ErrorType}` で参照せず平文だけで書くこと。
直接の throw の送出型と異なる symbol を、@throws の link で参照すること。
当該宣言内の try/catch で吸収される throw に、当該宣言の契約にない @throws を機械的に要求すること。
呼出先または rejected Promise から伝播する欠陥の網羅を、構造検査だけで保証できるとみなすこと。
summary の最初の一行を、複数行または句読点つきで書くこと。
summary の用途と体言止めを、字面の構造検査だけで保証できるとみなすこと。

### 行動
要素ごとに目的の summary を書き、型引数・引数・戻り値を @typeParam・@param・@returns のうち該当するものに記す。
実効的な可視境界を確かめ、module 外へ公開される要素は外部の利用側が、同一境界内だけの要素は内部の呼び出し側が依存してよい保証を書く。
当該宣言から外へ伝播する直接の throw の型を semantic model で解決する。
解決した型を `@throws {@link ErrorType} 条件` の `ErrorType` で参照する。
当該宣言内の try/catch で吸収される throw を、機械検査の対応から除く。
公開範囲を問わず、呼出先と rejected Promise から伝播する欠陥をレビューし、当該宣言の契約になるものを @throws に記す。
summary の最初の一行を、一行かつ句読点なしで書く。
レビューで、summary が名前の直訳でなく用途を判断できる体言止めになっていることを確かめる。

### 例
```typescript
/**
 * 検証済みカートの確定と在庫引当
 * @param cart - 確定対象の検証済みカート
 * @returns 確定済みの注文または在庫不足の失敗
 * @throws {@link InvariantViolation} 保存済みの注文が不変条件に違反している
 */
function place(cart: ValidCart): Result<Order, OrderError> { /* ... */ }
```

## 型名の接尾辞を役割で揃える

### 要求
永続化から読んだ行に相当する値を表す型には Record を付ける。
境界の wire の型には Request・Response を付ける。
一方の型からもう一方への変換を担うオブジェクトや関数には mapper を含む名前を付ける。

### 根拠
役割ごとに接尾辞を揃えると、型の名前だけで永続化の行相当か境界の wire か変換かが区別でき、同じ業務概念を指す型が複数あっても取り違えない。

### 完了条件
永続化から読んだ行に相当する型名が、Record で終わっている。
境界の wire の型名が、Request または Response で終わっている。
変換を担うオブジェクトや関数の名前が、mapper を含んでいる。

### 禁止事項
役割の異なる型に、同じ接尾辞を付けること。
接尾辞なしに、役割を型名から判別できない名前を付けること。

### 行動
永続化の行に相当する型は `<対象>Record`、境界の wire の型は `<対象>Request`・`<対象>Response` の名前にする。
変換を担うオブジェクトや関数は、名前に mapper を含める。

### 例
役割を表さない型名では、永続化の行と境界の wire を区別できない。

```text
Order
OrderIn
```

役割ごとに接尾辞を揃え、変換の名前に `mapper` を含める。

```text
OrderRecord
CreateOrderRequest
OrderResponse
orderMapper
```

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment.md)、型の規律は [types](../../concerns/types.md) に従う。
境界の wire の型は [translation](./translation.md) に従う。
