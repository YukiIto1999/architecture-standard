# progenitor

用途は、契約から Rust の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、Rust は progenitor であり、build 時の `Generator` が作る source を prettyplease で印字して contracts/generated へ書き出す。
判断基準は、`@typespec/openapi3` が出力する OpenAPI から contracts/generated の client と型を生成でき、判別付き直和の判別子と payload を往復で保て、client が接続先と reqwest の instance を引数で受け取り、同じ入力と同じ版から同じ出力を得て drift をリポジトリの検証入口の gate にできることである。型の生成が typify で行われ、JSON Schema から生成する Rust の型と同じ規則になることを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、`@typespec/openapi3` が出力する OpenAPI の版を受け取れなくなること、同じ入力と同じ版から異なる出力を出すようになることを再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の Rust の client と型は、[tools/build/typespec](../../tools/build/typespec.md) が採用した経路で生成し、利用を client・型と drift・conformance の検査に限る。
生成は build 時の `Generator` で行い、印字した source を contracts/generated の file として commit する。
契約は、全ての response に status code を明示する。
契約は、一つの operation の成功の body 型を一つに、失敗の body 型を一つに揃える。
判別付き直和は、各 variant の schema が判別子の property を required かつ単一の固定値として持つ形で書く。
認証の header は、契約の header parameter として宣言するか、呼び出し側が渡す reqwest の instance の既定 header で与える。
生成物を、手で編集しない。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
progenitor は生成物を file として出せるので、再生成の差分を検証入口の gate にできる。
progenitor は operation ごとに成功と失敗の body 型を一つずつしか扱えず、status code を持たない response は成功の型と失敗の型を同じ集合へ混ぜるため、生成そのものが失敗する。
判別付き直和は判別子で分岐しない表現へ写るため、判別子が required かつ単一の固定値でないと、payload の形が近い variant へ黙って吸われる。
判別子で分岐しない表現の失敗は variant ごとの理由を残さないため、診断は応答の生の payload を保持する client の error 型が担う。
認証の header を生成物の中に固定すると、接続の設定が生成物へ閉じ込められる。

### 完了条件
client と型が、契約から progenitor で生成され、contracts/generated に commit されている。
再生成した出力が commit した出力と一致し、一致しないことがビルドの失敗になっている。
契約の全ての response に status code が書かれている。
各 operation の成功の body 型と失敗の body 型が、それぞれ一つに揃っている。
判別付き直和の各 variant が判別子を required かつ単一の固定値として持ち、生成した型で判別子が一度だけ serialize され、往復で payload が保たれている。
client が、接続先と reqwest の instance を引数で受け取っている。
認証の header が、契約の header parameter か、呼び出し側が渡す reqwest の instance の既定 header で与えられている。

### 禁止事項
生成物を手で編集すること。
生成物を、client・型と drift・conformance の検査以外に使うこと。
生成物を file として残さない経路で生成すること。
status code を明示しない response を契約に置くこと。
一つの operation に、成功の body 型または失敗の body 型を二つ以上置くこと。
判別子を持たない直和、または判別子が単一の固定値でない直和を契約に置くこと。
接続先と reqwest の instance を、生成物の中に固定すること。

### 行動
`@typespec/openapi3` が出力した OpenAPI を入力に、build 時の `Generator` で source を作り、prettyplease で印字して contracts/generated へ書き出す。
書き出した file を commit し、検証入口で再生成して差分が出たら失敗させる。
契約は、全ての response に status code を書き、operation ごとに成功と失敗の body 型を一つずつに揃える。
判別付き直和は、各 variant に判別子の property を required かつ単一の固定値で置く。
TLS は [reqwest](./reqwest.md) の採用に従い、呼び出し側が rustls を有効にした reqwest の instance を渡す。
