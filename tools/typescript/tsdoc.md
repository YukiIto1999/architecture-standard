# @microsoft/tsdoc

用途は、ドキュメントコメントの存在、構文、宣言と tag の機械判定できる対応、最初の一行と句読点を検査する道具である。
採用は、TypeScript は TypeScript compiler API と `@microsoft/tsdoc` を使う構造検査である。
判断基準は、comment の存在と構文、宣言と tag の対応、最初の一行と句読点を一律に検査し、違反をリポジトリの検証入口で止められることである。
撤回条件は、判断基準を満たさなくなることであり、Roslyn、TypeScript compiler API、`@microsoft/tsdoc` の互換性の変化を再評価のトリガーとする。

## ドキュメントコメントの検査

### 要求
TypeScript compiler API と `@microsoft/tsdoc` による構造検査を、ドキュメントコメントの検査入口にする。
宣言した要素のドキュメントコメントの存在を、構造検査で検査する。
TSDoc の構文と @typeParam・@param・@returns の宣言との対応を、構造検査で検査する。
@throws が `@throws {@link ErrorType} 条件` の書式であることを、構造検査で検査する。
当該宣言から外へ伝播すると compiler API で判定できる直接の throw の型と、@throws の link の参照先を semantic model で照合する。
当該宣言内の try/catch で吸収される throw は、@throws の構造検査対象から除く。
最初の一行が一行であり句読点を含まないことを、構造検査で検査する。
呼出先または rejected Promise から伝播する欠陥が当該宣言の契約かと、その @throws は、公開範囲を問わずレビューで確かめる。
最初の一行が名前の直訳でないこと、用途を判断できること、体言止めであることはレビューで確かめる。
内容が、実効的な可視境界を基準に、module 外へ公開される要素では外部契約を、同一境界内だけの要素では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致しているかは、レビューで確かめる。

### 根拠
TypeScript compiler API は宣言と型引数、引数、戻り値、直接の throw、try/catch の包含関係、対応するコメント範囲を構文木から取得できる。
TypeScript compiler API の semantic model は、throw 式の型と link が参照する symbol を解決できる。
`@microsoft/tsdoc` はコメントを TSDoc の構文として parse し、`{@link ErrorType}` を link として読める。
両者を組み合わせれば、存在、構文、宣言と tag の機械判定できる対応、外へ伝播する直接の throw の型と link、先頭行の一行と句読点を照合できる。
呼出先や rejected Promise から伝播する欠陥が当該宣言の契約かは、呼出関係と契約の意味を読む必要がある。
名前の直訳でないこと、用途を判断できること、体言止めであることは、字面だけでは判定できない。
内容が可視性に応じた外部契約または内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致しているかは、意味を読む必要があるため機械化しない。

### 完了条件
ドキュメントコメントの存在が、TypeScript compiler API による構造検査で検査されている。
TSDoc の構文が、`@microsoft/tsdoc` による構造検査で検査されている。
@typeParam・@param・@returns が宣言と対応することが、構造検査で検査されている。
@throws が、`@throws {@link ErrorType} 条件` の書式であることが構造検査で検査されている。
当該宣言から外へ伝播すると機械判定できる直接の throw の型と、@throws の link の参照先が semantic model で照合されている。
当該宣言内の try/catch で吸収される throw が、@throws の構造検査対象から除かれている。
最初の一行が一行であり句読点を含まないことが、構造検査で検査されている。
呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥と @throws の対応が、公開範囲を問わずレビューで確かめられている。
最初の一行が名前の直訳でなく用途を判断できる体言止めであることが、レビューで確かめられている。
内容が、module 外へ公開される要素では外部契約を、同一境界内だけの要素では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致していることが、レビューで確かめられている。

### 禁止事項
ドキュメントコメントの存在、構文、機械判定できる tag の対応、最初の一行と句読点を、レビューだけで検査すること。
@throws の error type を、`{@link ErrorType}` で参照せず平文だけで書くこと。
直接の throw の型と異なる symbol を、@throws の link で参照すること。
当該宣言内の try/catch で吸収される throw に、@throws を機械的に要求すること。
呼出先または rejected Promise から伝播する欠陥の @throws を、構造検査だけで網羅できるとみなすこと。
先頭行の用途と体言止めを、構造検査だけで保証できるとみなすこと。
内容の意味と統一した語彙との一致を、構造検査だけで保証できるとみなすこと。

### 行動
TypeScript compiler API で宣言とコメントを取得し、`@microsoft/tsdoc` でコメントを parse する構造検査を検証入口で実行する。
構造検査で、存在、構文、@typeParam・@param・@returns の宣言との対応、`@throws {@link ErrorType} 条件` の書式、最初の一行と句読点を照合する。
semantic model で当該宣言から外へ伝播する直接の throw の型と、@throws の link の参照先を照合する。
当該宣言内の try/catch で吸収される throw を、@throws の構造検査対象から除く。
公開範囲を問わず、呼出先または rejected Promise から伝播して当該宣言の契約になる欠陥と @throws の対応をレビューする。
レビューで、先頭行が名前の直訳でなく用途を判断できる体言止めであることを確かめる。
ドキュメントコメントが、実効的な可視境界を基準に、module 外へ公開される要素では外部契約を、同一境界内だけの要素では内部契約を述べ、名前や実装の言い換えでなく、統一した語彙と一致していることをレビューする。
