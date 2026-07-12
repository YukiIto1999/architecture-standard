# conventions

## 概要
conventions は、TypeScript で実現軸を横断する全域規律を扱う。
principles の [comment](../../principles/comment.md) が定めるドキュメントコメントの契約を、TypeScript の機構で満たす。
実現軸に紐づく置き場を持たず、formation・translation・connection・retention・coordination・publication・inspection の全てに一様に適用する。

## 命名と整形を道具に委ねる

### 要求
命名は標準的な TypeScript の規約に従い、型は PascalCase、値と関数は camelCase にする。
整形は oxfmt の既定に従い、手で揃えない。
ファイル名は kebab-case で統一し、oxlint の `unicorn/filename-case` で揃える。

### 根拠
[verification](../../principles/verification.md) が定める、コードスタイルの細則は人の合意でなく単一の formatter と linter に委ねるという要求に、oxfmt で応える。
TypeScript はファイル名の標準の規約を持たないため、一つの表記に固定しないと表記が揺れる。
kebab-case に固定して `unicorn/filename-case` で揃えれば、ファイル名が一意に決まる。
型と値の命名規約(PascalCase・camelCase)自体を検査する規則は oxlint に無く、この部分はレビューで確認する。

### 完了条件
命名が、型は PascalCase、値と関数は camelCase になっている。
ファイル名が、kebab-case で統一され `unicorn/filename-case` で検査されている。
整形が、oxfmt の既定で一意に決まっている。

### 禁止事項
整形を、手で揃えること。
ファイル名の表記を、混在させること。

### 行動
型を PascalCase、値と関数を camelCase で名付ける。
ファイル名を kebab-case にし、oxfmt と oxlint を既定で適用する。

## ドキュメントコメントを書く

### 要求
宣言した要素に TSDoc のドキュメントコメントを付ける。
対象が持つ @typeParam・@param・@returns・@throws を省かない。
想定された失敗は戻り値の Result の型に現し、@throws は欠陥に限る。
summary の最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、体言止めで一行に書き、句読点を使わない。

### 根拠
TSDoc は、ツールが一貫して解釈できる統一文法で、利用者が実装を読まずに用途と契約を読めるようにする。
@param・@returns は、引数と戻り値を契約として宣言し、想定された失敗は戻り値の Result の型に現す。
最初の一行は検索や一覧で要素の目的を示す要約として再利用されるので、体言止めと句読点の排除は短い断片を一覧で走査しやすくする。

### 完了条件
宣言した要素に、用途と契約を述べる TSDoc のドキュメントコメントがある。
@typeParam・@param・@returns・@throws が、対象の持つものを網羅している。
summary の最初の一行が、名前の直訳でなく利用者が用途を判断できる目的を、句読点なしの体言止めで一行に示している。

### 禁止事項
宣言した要素の契約を、未記述で放置すること。
対象が持つ @typeParam・@param・@returns・@throws を、省くこと。
summary の最初の一行を、句読点や動詞終わりの完結した文で書くこと。

### 行動
要素ごとに目的の summary を一行で書き、型引数・引数・戻り値・送出する欠陥を @typeParam・@param・@returns・@throws のうち該当するものに記す。
summary の最初の一行は、名前の直訳でなく利用者が用途を判断できる目的を、句読点のない体言止めで書く。

### 例
```typescript
/**
 * 検証済みカートの確定と在庫引当
 * @param cart - 確定対象の検証済みカート
 * @returns 確定済みの注文または在庫不足の失敗
 * @throws InvariantViolation 保存済みの注文が不変条件に違反している
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
```typescript
// 役割が名前から読み取れない
interface Order { /* 永続化の行に相当 */ }
interface OrderIn { /* wire */ }

// 接尾辞で役割を揃える
interface OrderRecord { /* 永続化の行に相当 */ }
interface CreateOrderRequest { /* 境界の入力 */ }
interface OrderResponse { /* 境界の出力 */ }
const orderMapper = { toResponse: (record: OrderRecord): OrderResponse => ({ /* ... */ }) };
```

## 参照
ドキュメントコメントの契約は [comment](../../principles/comment.md)、型の規律は [types](../../concerns/types.md)、整形の機械化は [verification](../../principles/verification.md) に従う。
境界の wire の型は [translation](./translation.md) に従う。
