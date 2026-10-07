# conventions

## 概要
conventions は、TypeScript で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment/README.md) が定めるドキュメントコメントの契約を、TypeScript の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・coordination・publication・inspection の全てに一様に適用する。

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
最初の一行とドキュメントコメントの記述の形は、principles の [comment](../../principles/comment/declaration-contracts.md) の「ドキュメントコメントは宣言の契約を書く」と、[documentation](../../principles/documentation/sentence-endings.md) の「文末の形を記述の種類で分ける」に従う。

### 根拠
TSDoc は、ツールが一貫して解釈できる統一文法で、利用者が実装を読まずに用途と契約を読めるようにする。
可視性に応じて外部契約と内部契約を分ければ、呼び出し側が依存してよい保証の範囲が明らかになる。
@param・@returns は、引数と戻り値を契約として宣言し、想定された失敗は戻り値の Result の型に現す。
`@microsoft/tsdoc` は `{@link ErrorType}` を link として parse でき、compiler の semantic model は link の参照先と throw 式の型を解決できる。
当該宣言から外へ出る直接の throw と try/catch で吸収される throw は、構文上の包含関係で分けられる。
呼出先や rejected Promise から伝播する欠陥が当該宣言の契約かは、呼出関係と契約の意味を読む必要がある。

### 完了条件
宣言した要素に、用途と契約を述べる TSDoc のドキュメントコメントがある。
module 外の利用側へ公開される要素が外部契約を、同一境界内だけで利用できる要素が内部契約を述べている。
@typeParam・@param・@returns が、対象の持つものを網羅している。
@throws が、`@throws {@link ErrorType} 条件` の書式で書かれている。
当該宣言から外へ伝播すると機械判定できる直接の throw に、送出型と link の参照先が一致する @throws が付いている。
当該宣言内の try/catch で吸収される throw が、@throws の機械検査対象から除かれている。
呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥に、公開範囲を問わずレビューで @throws が付いている。

### 禁止事項
宣言した要素の契約を、未記述で放置すること。
module 外の利用側へ公開される要素の契約を、同一境界内だけに通用する内部契約として書くこと。
対象が持つ @typeParam・@param・@returns を、省くこと。
当該宣言の契約になる欠陥の @throws を、省くこと。
@throws の error type を、`{@link ErrorType}` で参照せず平文だけで書くこと。
直接の throw の送出型と異なる symbol を、@throws の link で参照すること。
当該宣言内の try/catch で吸収される throw に、当該宣言の契約にない @throws を機械的に要求すること。
呼出先または rejected Promise から伝播する欠陥の網羅を、構造検査だけで保証できるとみなすこと。

### 行動
要素ごとに目的の summary を書き、型引数・引数・戻り値を @typeParam・@param・@returns のうち該当するものに記す。
実効的な可視境界を確かめ、module 外へ公開される要素は外部の利用側が、同一境界内だけの要素は内部の呼び出し側が依存してよい保証を書く。
当該宣言から外へ伝播する直接の throw の型を semantic model で解決する。
解決した型を `@throws {@link ErrorType} 条件` の `ErrorType` で参照する。
当該宣言内の try/catch で吸収される throw を、機械検査の対応から除く。
公開範囲を問わず、呼出先と rejected Promise から伝播する欠陥をレビューし、当該宣言の契約になるものを @throws に記す。

### 例
```typescript
/**
 * 在庫引当を伴う検証済みカートの注文確定
 * @param cart - 注文として確定する品目と数量
 * @returns 在庫不足を失敗とする確定済みの注文
 * @throws {@link InvariantViolation} 保存済みの注文の不変条件違反
 */
function place(cart: ValidCart): Result<Order, OrderError> { /* ... */ }
```

## 型名の接尾辞を役割で揃える

### 要求
永続化から読んだ行に相当する値を表す型には Record を付ける。
binding 固有の wire envelope の型には Request・Response を付け、生成 DTO は canonical の command・query・result・view の意味の名前を保つ。
一方の型からもう一方への変換を担うオブジェクトや関数には mapper を含む名前を付ける。

### 根拠
役割ごとに接尾辞を揃えると、型の名前だけで永続化の行相当か境界の wire か変換かが区別でき、同じ業務概念を指す型が複数あっても取り違えない。

### 完了条件
永続化から読んだ行に相当する型名が、Record で終わっている。
binding 固有の wire envelope の型名が Request または Response で終わり、生成 DTO の意味の名前が canonical と対応している。
変換を担うオブジェクトや関数の名前が、mapper を含んでいる。

### 禁止事項
役割の異なる型に、同じ接尾辞を付けること。
接尾辞なしに、役割を型名から判別できない名前を付けること。

### 行動
永続化の行に相当する型は `<対象>Record`、binding 固有の wire envelope は `<対象>Request`・`<対象>Response` の名前にする。
生成 DTO は canonical の意味の名前を使い、接尾辞を揃えるためだけの同義 DTO や alias を追加しない。
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

## 命名と整形を道具に委ねる

### 要求
命名は標準的な TypeScript の規約に従い、型は PascalCase、値と関数は camelCase にする。
整形は oxfmt の既定に従い、手で揃えない。
ファイル名は kebab-case で統一し、oxlint の `unicorn/filename-case` で揃える。
ファイル名の規則は、コードの識別子の規則とは独立に定める。
ファイルの種別の標識は、名前の末尾に第二拡張子として付ける。

### 根拠
[verification](../../principles/verification/README.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、oxfmt で応える。
TypeScript はファイル名の標準の規約を持たないため、一つの表記に固定しないと表記が揺れる。
kebab-case に固定して `unicorn/filename-case` で揃えれば、ファイル名が一意に決まる。
型と値の命名規約(PascalCase・camelCase)自体を検査する規則は oxlint に無いため、TypeScript compiler API による命名照合をリポジトリの検証入口で実行する。
ファイル名はモジュールを指す名前であり、コードの識別子である値や型の名前とは指す対象が異なる。
指す対象が異なるファイル名とコードの識別子を、同じ命名規約に揃える理由はない。
種別を第二拡張子に置けば、内容を開かずに名前の走査だけで種別を判定できる。

### 完了条件
命名が、型は PascalCase、値と関数は camelCase になっている。
ファイル名が、kebab-case で統一され `unicorn/filename-case` で検査されている。
整形が、oxfmt の既定で一意に決まっている。
ファイル名の規則が、コードの識別子の規則と独立に定められている。
ファイルの種別の標識が、名前の末尾の第二拡張子として付けられている。

### 禁止事項
整形を、手で揃えること。
ファイル名の表記を、混在させること。
ファイル名の規則を、コードの識別子の規則に合わせること。
ファイルの種別の標識を、第二拡張子以外の位置に書くこと。

### 行動
型を PascalCase、値と関数を camelCase で名付ける。
ファイル名を kebab-case にし、oxfmt と oxlint を既定で適用する。
ファイルの種別は、`.test.ts`・`.spec.ts` のように名前の末尾に第二拡張子として付ける。

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment/README.md)、型の規律は [types](../../concerns/types/README.md) に従う。
境界の wire の型は [translation](./translation.md) に従う。
