# progenitor

用途は、契約から Rust の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、Rust は progenitor であり、build 時の `Generator` が作る source を prettyplease で印字して contracts/generated へ書き出す。
判断基準は、`@typespec/openapi3` が出力する OpenAPI から contracts/generated の client と具体的なデータ型を生成でき、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成能力、依存単位の分離、応答の分類を満たし、client が接続先と reqwest の instance を引数で受け取り、同じ入力と同じ版から同じ出力を得て drift をリポジトリの検証入口の gate にできることである。
HTTP と JSON Schema の経路のデータ型と deserialize は、[typify](./typify.md) が定める同じ生成規律に従う。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、`@typespec/openapi3` が出力する OpenAPI の版を受け取れなくなること、同じ入力と同じ版から異なる出力を出すようになることを再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の Rust の client と型は、[tools/build/typespec](../../tools/build/typespec.md) が採用した経路で生成し、利用を client・型と drift・conformance の検査に限る。
生成は build 時の `Generator` で行い、印字した source を contracts/generated の file として commit する。
データ型と serde の処理は、reqwest を使う client とは別 crate に出力し、提供側と core の composition はデータ型の crate だけへ依存する。
生成経路の判別付き直和と未知フィールド捕捉は [typify](./typify.md) に従う。
契約は、全ての response に具体の status code を明示し、成功を 2xx、失敗を 4xx と 5xx に限り、[structure/contracts/http](../../structure/contracts/http.md) の「応答の status」に従う。
契約は、一つの operation の成功の response を、全て同じ型の JSON、全て `ByteStream`、全て body なしのいずれか一つに揃える。
構造化データの成功の response の body は `application/json` で、失敗の response の body は `application/problem+json` で宣言し、ファイルの成功の response は [structure/contracts/http](../../structure/contracts/http.md) の「ファイルの表現」が定める media type で宣言する。
判別付き直和は、各 variant の schema が判別子の property を required かつ単一の固定値として持つ形で書く。
認証の header は、契約の header parameter として宣言するか、呼び出し側が渡す reqwest の instance の既定 header で与える。
生成物を、手で編集しない。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
progenitor は生成物を file として出せるので、再生成の差分を検証入口の gate にできる。
progenitor は operation ごとに、成功と失敗のそれぞれで body の型と種別を一つずつしか扱えず、status code を持たない response は成功の集合と失敗の集合を同じ集合へ混ぜるため、生成そのものが失敗する。
成功の response は、型の違う JSON、body を持つものと持たないもの、型を付けるものと付けないものの、どの組でも `response_types.len() <= 1` の assert で生成が失敗する。
progenitor が型を付けて decode するのは `application/json` の body だけで、他の media type の body は型を付けずに `ByteStream` で返す。
失敗の body はどれも `application/problem+json` の `ByteStream` で一つの種別なので、status ごとに schema が違っても生成できる。
`InvalidResponsePayload` は status を持たないので、失敗の body を `application/json` で宣言すると、502・503・504 の判定ができない。
判別付き直和の入力から variant を一意に選ぶ処理と、選んだ variant の未知キーを捕捉する処理を生成経路が所有すれば、生成器の既定の union 表現を提供側の decode の保証と混同しない。
利用側の診断は応答の payload を保持する client の error 型が、提供側の未知項目の検知は生成 decoder と surface の報告境界が担う。
認証の header を生成物の中に固定すると、接続の設定が生成物へ閉じ込められる。

### 完了条件
client と型が、契約から progenitor で生成され、contracts/generated に commit されている。
再生成した出力が commit した出力と一致し、一致しないことがビルドの失敗になっている。
契約の全ての response に status code が書かれている。
各 operation の成功の response が、全て同じ型の JSON、全て `ByteStream`、全て body なしのいずれか一つに揃い、構造化データの成功の body が `application/json`、ファイルの成功の body が宣言した media type、失敗の body が `application/problem+json` で宣言されている。
判別付き直和の各 variant が判別子を required かつ単一の固定値として持ち、生成した型で判別子が一度だけ serialize され、往復で payload が保たれている。
client が、接続先と reqwest の instance を引数で受け取っている。
認証の header が、契約の header parameter か、呼び出し側が渡す reqwest の instance の既定 header で与えられている。
データ型の crate の依存 closure に reqwest と通信 runtime がなく、server と core の composition がその crate だけを利用している。
全 variant と入れ子の object の未知キーが捕捉され、必須項目や判別子の不正が拒否されることを生成物で検証している。

### 禁止事項
生成物を手で編集すること。
生成物を、client・型と drift・conformance の検査以外に使うこと。
生成物を file として残さない経路で生成すること。
status code を明示しない response を契約に置くこと。
一つの operation に、成功の response として型の違う JSON、`ByteStream`、body なしを混ぜて置くこと、または失敗の response の body の種別を二つ以上置くこと。
判別子を持たない直和、または判別子が単一の固定値でない直和を契約に置くこと。
接続先と reqwest の instance を、生成物の中に固定すること。
未知項目の捕捉不足を、生成 DTO と同じ意味の手書き DTO や生成後の手修正で補うこと。

### 行動
`@typespec/openapi3` が出力した OpenAPI を入力に、build 時の `Generator` で source を作り、prettyplease で印字して contracts/generated へ書き出す。
書き出した file を commit し、検証入口で再生成して差分が出たら失敗させる。
契約は、全ての response に具体の status code を書き、成功を 2xx、失敗を 4xx と 5xx に限り、operation ごとに成功の response を全て同じ型の JSON、全て `ByteStream`、全て body なしのいずれかに、失敗の body を `application/problem+json` に揃える。
判別付き直和は、各 variant に判別子の property を required かつ単一の固定値で置く。
型と serde の処理を通信 client から分け、[typify](./typify.md) が定める schema 駆動の生成処理を同じ task から実行する。
TLS は [reqwest](./reqwest.md) の採用に従い、呼び出し側が rustls を有効にした reqwest の instance を渡す。

## 生成 client の応答を失敗の種類で分類する

### 要求
progenitor の client が返す `Error` を、[structure/contracts/generated](../../structure/contracts/generated.md) の「応答の分類」が定める種類へ、契約が宣言した応答の集合との照合で割り当てる。
`ErrorResponse` は宣言した失敗の status の応答であり、body は `ByteStream` で返るので、adapter が status を先に、次に body を、契約から生成した型で decode する。
502・503・504 で body が契約の型に一致しなければ通信の失敗として、それ以外の status で一致しなければ契約に無い応答と decode の失敗として扱い、一致すれば operation の想定内の失敗の型へ写して Result の Err で返す。
`UnexpectedResponse` は宣言していない status の応答であり、502・503・504 なら通信の失敗として、それ以外なら契約に無い応答として扱う。
宣言した成功の status で body を契約の型へ decode できない `InvalidResponsePayload` は、契約に無い応答と decode の失敗として扱う。
契約に無い応答と decode の失敗は、[connection](./connection.md) の「失敗を Result に、欠陥を panic にする」に従って panic にする。
`reqwest::Error::is_builder` が真の `CommunicationError` と `InvalidRequest` は、要求の組立の失敗として panic にする。
それ以外の `CommunicationError` と、`ResponseBodyError`、`InvalidUpgrade`、`ByteStream` の読取の失敗は、reqwest や OS が自ら設けた timeout を含め、通信の失敗として port の失敗の型へ写して Result の Err で返す。
時間上限の超過と取り消しは `Error` の値にならず、[tokio-util](./tokio-util.md) の「取り消し」に従って終え、時間上限の超過は port の失敗の型の通信の失敗と別の値の Err で返す。
`Custom` は応答に由来しないので、応答の分類の対象にせず、[effect](../../concerns/effect/value-origin-classification.md) の「失敗と欠陥を値の出所で判別する」に従って終了を決める。
`Error` の分類は、`status()` の範囲や `is_success()` で行わない。

### 根拠
progenitor の `Error` は、文書化された失敗の `ErrorResponse`、API 記述に無い応答の `UnexpectedResponse`、期待した status の payload の decode に失敗した `InvalidResponsePayload`、要求の不整合の `InvalidRequest`、通信の `CommunicationError`・`ResponseBodyError`・`InvalidUpgrade` を別の variant にする。
契約が成功を 2xx、失敗を 4xx と 5xx に限り、全ての response に status を明示すれば、progenitor は宣言していない status を `ErrorResponse` でなく `UnexpectedResponse` として返す。
progenitor は query と body の直列化の失敗を要求の組立まで遅らせ、その失敗を `CommunicationError` に変換するので、要求の組立の失敗は `reqwest::Error::is_builder` が真の `CommunicationError` として現れる。
reqwest や OS が自ら設けた timeout の超過は、adapter が掛けた timeout の Elapsed ではないので、`CommunicationError` と `ResponseBodyError` の通信の失敗として現れる。

### 完了条件
`ErrorResponse` が、status を先に、次に body の順に契約から生成した型で decode され、一致した場合に operation の想定内の失敗の型の Err で返されている。
宣言していない 502・503・504 の `UnexpectedResponse` と、502・503・504 の `ErrorResponse` で body が契約の型に一致しないものが、port の失敗の型の通信の失敗として Err で返されている。
それ以外の宣言していない status の `UnexpectedResponse`、それ以外の status の `ErrorResponse` で body が契約の型に一致しないもの、宣言した成功の status で契約の型に合わない body の `InvalidResponsePayload` が、panic になっている。
`reqwest::Error::is_builder` が真の `CommunicationError` と `InvalidRequest` が、panic になっている。
それ以外の `CommunicationError`、`ResponseBodyError`、`InvalidUpgrade`、`ByteStream` の読取の失敗が、port の失敗の型の通信の失敗として Err で返されている。
呼び出しごとの時間上限の超過と取り消しが、tokio-util の「取り消し」に従って終えられ、時間上限の超過が通信の失敗と別の値の Err で返されている。
`Error` の分類が、variant と宣言した status の集合との照合に従い、`status()` の範囲と `is_success()` に従っていない。
宣言した各 status、宣言していない 502・503・504 とそれ以外の status、502・503・504 と宣言した失敗の status のそれぞれで契約の型に合わない `application/problem+json` の body、宣言した成功の status で契約の型に合わない body、本文の途中での切断、失敗の body の読取の途中での切断、接続の拒否、要求の組立の失敗、reqwest や OS が自ら設けた timeout の超過、自身の timeout の超過、取り消しの各場合が、実際の HTTP 応答で意図した分類になることが検証されている。

### 禁止事項
502・503・504 で body が契約の型に一致しない応答を、欠陥にすること。
宣言した失敗の status の `ErrorResponse` の body を、契約から生成した型で decode せずに宣言した失敗として返すこと。
`ErrorResponse` 以外を、宣言した失敗の型へ畳むこと。
`Error` の分類を、`status()` の範囲や `is_success()` で行うこと。
要求の組立の失敗を、通信の失敗として Result の Err で返すこと。
`Custom` を、応答の分類の種類へ割り当てること。

### 行動
`Error` を variant と宣言した status の集合で分類し、`UnexpectedResponse` は status が 502・503・504 かを照合してから種類を決め、`ErrorResponse` は status を先に、次に body の decode の結果で種類を決める。
`CommunicationError` は `reqwest::Error::is_builder` を先に調べ、要求の組立の失敗を panic にし、残りを通信の失敗として port の失敗の型へ写す。
呼び出しごとの時間上限の超過と取り消しは、tokio-util の「取り消し」に従って終え、時間上限の超過を port の失敗の型の別の値へ写す。
body が一致した `ErrorResponse` を operation の想定内の失敗の型へ写し、契約に無い応答と decode の失敗は panic にする。
実際の HTTP 応答で、宣言した全ての status、宣言していない 502・503・504 とそれ以外の status、契約の型に合わない body、本文の途中での切断、失敗の body の読取の途中での切断、接続の拒否、要求の組立の失敗、reqwest や OS が自ら設けた timeout の超過、自身の timeout の超過、取り消しを起こし、分類を検証する。
