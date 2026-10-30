# NSwag

用途は、契約から C# の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、C# は NSwag であり、HTTP を持たない契約は NSwag の JSON Schema 入力で型を生成する。
判断基準は、contracts/generated の client と具体的なデータ型を契約から生成でき、`@typespec/json-schema` が出力する JSON Schema からも型を生成でき、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成能力、依存単位の分離、応答の分類を満たし、drift をリポジトリの検証入口の gate にできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、契約記述言語の生成器が JSON Schema 入力を含めて同じ判断基準を満たすようになることを再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の C# の client と型は NSwag で生成し、利用を client・型と drift・conformance の検査に限る。
server の stub 生成に使わず、server の実装は Minimal API を保つ。
データ型と serializer の処理は HTTP client を持つ client とは別の assembly に出力し、server と contracts/adapters はデータ型の assembly だけを使い、core は生成物を参照しない。
不変な入出力、必須項目と値の制約の検証、全 variant と入れ子の object の未知キー捕捉を生成器の設定と template に含め、同じ入力から再生成できる状態にする。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
server の stub を生成すると、生成の都合が server の構造を縛るので、server は Minimal API を保つ。

### 完了条件
client と型が、NSwag で生成されている。
NSwag の利用が、生成と検査に限られ、server の stub 生成に使われていない。
提供側と contracts/adapters が生成 DTO を使い、core に生成物への依存がなく、データ型の assembly の依存 closure に通信 client とその実行機構が入っていない。
生成 DTO の serializer が [translation](./translation.md) の契約の検証と未知項目の捕捉を満たしている。

### 禁止事項
NSwag を、server の stub 生成に使うこと。
同じ意味の手書き DTO や生成物の手修正で、契約の検証や未知項目の捕捉を補うこと。

### 行動
NSwag で client とデータ型を別 assembly に生成し、server は生成 DTO を Minimal API で受け渡す。
serializer の処理を含む生成能力を検査し、不足は canonical、binding、生成器の設定と template で直す。

## 生成 client の応答を失敗の種類で分類する

### 要求
NSwag の client が投げる例外を、[structure/contracts/generated](../../structure/contracts/generated.md) の「応答の分類」が定める種類へ、契約が宣言した応答の集合との照合で分類する。
`ApiException<T>` は `ApiException` の派生なので、`ApiException` より先に判定する。
`ApiException<T>` は、`StatusCode` が宣言した失敗の status なら宣言した失敗とし、宣言した成功の status なら `Result` を成功の値とする。
非 generic の `ApiException` は、`StatusCode` が body を持たない宣言した応答の status なら、その宣言した応答として、成功なら成功に、失敗なら宣言した失敗にする。
非 generic の `ApiException` は、`StatusCode` が 502・503・504 なら、宣言の有無に関わらず通信の失敗とし、port の失敗の型で Failed にする。
それ以外の非 generic の `ApiException` は、宣言していない status、宣言した status での decode の失敗、null の body であり、契約に無い応答と decode の失敗として、[connection](./connection.md) の「終了を成功と失敗と欠陥と取り消しに分ける」に従って Defected にする。
`ApiException` に包まれずに client から出る `JsonException` は、要求の直列化の失敗であり、要求の組立の失敗として Defected にする。
宣言した失敗は、例外のまま上位へ送らず、operation の想定内の失敗の型へ写して Failed にする。
`HttpRequestException` と、応答の本文の読取で投げられる `IOException`(.NET 8 以降の `HttpIOException` を含む)は通信の失敗とし、port の失敗の型で Failed にする。
呼び出しごとの時間上限と `OperationCanceledException` の帰属は、[coordination](./coordination.md) の「取り消し」に従う。
時間上限の超過は port の失敗の型の通信の失敗と別の値で Failed にし、取り消しは Canceled にし、どちらでもない `OperationCanceledException` は通信の失敗にして Failed にする。
`StatusCode` は、宣言した status の集合との一致の照合と、502・503・504 の判定にだけ使い、4xx や 5xx といった範囲で分類しない。
上のいずれにも当たらない例外は、通信の失敗へ畳まず、そのまま上位へ伝える。

### 根拠
NSwag の client は、200 の response を、なければ最初の 2xx の response を主たる成功とし、型が主たる成功と一致する 2xx だけを戻り値にする。
型が主たる成功と異なる宣言した 2xx は、例外として投げられる。
body の schema を持たない response の型は `void` なので、201 と 204 を宣言した契約では、204 は非 generic の `ApiException` として投げられ、204 を先に宣言すると 201 が `ApiException<T>` として投げられる。
body の schema を持つ例外扱いの response には `ApiException<T>` を、持たない response と、宣言していない status と、JSON の decode の失敗と、null の body には非 generic の `ApiException` を投げる。
`ApiException<T>` は `ApiException` を継承するので、`ApiException` を先に判定すると宣言した失敗まで契約に無い応答として扱われる。
NSwag は応答の読取で `JsonException` だけを捕捉して `ApiException` に包み、要求の直列化の `JsonException` と、`HttpClient` の通信の例外と、本文の読取の例外は包まずに伝える。
本文の途中で接続が切れると `HttpIOException` が投げられ、`HttpIOException` は `IOException` の派生であり、`HttpRequestException` の派生ではない。
`HttpClient.Timeout` の超過は、`TimeoutException` を内包する `TaskCanceledException` として現れ、`CancelPendingRequests` や `Dispose` による内部の取り消しは、受け取った token が取り消されていない `TaskCanceledException` として現れる。
例外を一括して捕捉すると、取り消しや欠陥まで通信の失敗へ畳んでしまう。

### 完了条件
例外が、`ApiException<T>` を先に判定して、宣言した応答、契約に無い応答と decode の失敗、要求の組立の失敗、通信の失敗、時間上限の超過、取り消しへ分類されている。
宣言した成功の status の応答が、NSwag が例外として投げる第二の 2xx と body を持たない 204 を含め、全て成功として返されている。
宣言した失敗が、例外のまま上位へ送られず、operation の想定内の失敗の型で Failed になっている。
502・503・504 で body が契約の型に一致しない応答が、宣言の有無に関わらず、port の失敗の型の通信の失敗として Failed になっている。
502・503・504 以外で、宣言していない status と、宣言した status で契約の型に合わない body が、成功の応答の body を含め、Defected になっている。
要求の直列化の `JsonException` が、Defected になっている。
通信の失敗が、port の失敗の型で Failed になっている。
呼び出しごとの時間上限と `OperationCanceledException` が、coordination の「取り消し」に従って判定され、時間上限の超過が通信の失敗と別の値の Failed に、取り消しが Canceled に、どちらでもない `OperationCanceledException` が通信の失敗の Failed になっている。
`StatusCode` が、宣言した status の集合との一致の照合と 502・503・504 の判定だけに使われ、範囲で例外を分類していない。
上のいずれにも当たらない例外が、通信の失敗へ畳まれていない。
宣言した各 status、宣言していない 502・503・504 とそれ以外の status、502・503・504 を含む宣言した status で契約の型に合わない body、本文の途中での切断、接続の拒否、要求の直列化の失敗、自身の上限の超過、受け取った token の取り消し、`HttpClient` の内部の取り消し、その client が持つ場合の下位の層の timeout の各場合が、実際の HTTP 応答で意図した分類になることが検証されている。

### 禁止事項
`ApiException` の判定で、`ApiException<T>` まで契約に無い応答として扱うこと。
宣言した成功の status の応答を、例外の型だけで契約に無い応答として Defected にすること。
502・503・504 で body が契約の型に一致しない応答を、欠陥にすること。
`StatusCode` を、宣言した status の集合との照合でなく範囲で使い、例外を分類すること。
例外の一括捕捉で、取り消しや欠陥を通信の失敗へ畳むこと。

### 行動
adapter で NSwag の例外を `ApiException<T>`、`ApiException`、`JsonException`、`HttpRequestException`、`IOException`、`OperationCanceledException` の順に判定し、`StatusCode` を宣言した status の集合と照合して種類を決める。
宣言した失敗を operation の想定内の失敗の型で Failed に、通信の失敗と時間上限の超過を port の失敗の型の別の値で Failed に、契約に無い応答と decode の失敗と要求の組立の失敗を Defected に、受け取った token の取り消しを Canceled にする。
実際の HTTP 応答で、宣言した全ての status、宣言していない 502・503・504 とそれ以外の status、契約の型に合わない body、本文の途中での切断、接続の拒否、要求の直列化の失敗、自身の上限の超過、受け取った token の取り消し、`HttpClient` の内部の取り消し、その client が持つ場合の下位の層の timeout を起こし、分類を検証する。
