# http-client-js

用途は、契約から TypeScript の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、TypeScript は `@typespec/http-client-js` である。
判断基準は、契約から contracts/generated の client と型を生成でき、判別付き直和が判別子つきの union になり、生成した client が transport の実装を引数で受け取り、同じ入力と同じ版から同じ出力を得て drift をリポジトリの検証入口の gate にできることである。
生成物が製品が採用する TypeScript の型検査を通ることと、生成器が製品の型検査 toolchain へ版の制約を広げないことを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、transport の注入点の廃止、生成物が製品が採用する TypeScript の型検査を通らなくなること、安定版の到達を再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の TypeScript の client と型は、契約から `@typespec/http-client-js` で生成する。
データ型の公開入口を transport と通信 client から分離し、[structure/contracts/generated](../../structure/contracts/generated.md) が定める具体的な field と variant と依存単位の分離を満たす。
生成物を、手で編集しない。
生成した client は、host が実装する transport を引数で受け取る。
client の既定の transport と既定の再試行・redirect・logging の設定に、依存しない。
生成した client の利用は、[connection](./connection.md) の「生成型を型としてのみ使い、通信を port に通す」に従い、viewer の ui port または extension の host port を実装する host の adapters に限る。
viewer と extension は、生成物の型だけを型として import する。
生成器は製品の型検査 toolchain と別の package で動かし、置き場と生成入口は [structure/contracts](../../structure/contracts/layout.md) の「生成の toolchain」に従う。
生成物は、製品が採用する TypeScript の型検査へ通す。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、path・method・status と body の対応が契約から導かれ、host ごとに書き写さずに済む。
transport を引数で受け取れば、TLS・proxy・timeout・再試行のような host ごとに変わる判断を、契約から生成した成果物の外に置ける。
既定の transport に依存すると、host が変わるたびに契約から生成した成果物の中の設定を変えることになる。
viewer は ui port、extension は host port を通して通信するため、生成した client を viewer や extension が import する理由がない。
生成器は契約の compiler の上で動き、製品の TypeScript を要求しないので、型検査の toolchain と版の制約が分かれる。

### 完了条件
client と型が、契約から `@typespec/http-client-js` で生成され、contracts/generated に commit されている。
再生成した出力が commit した出力と一致し、一致しないことがビルドの失敗になっている。
判別付き直和が、判別子つきの union として生成され、網羅の検査が型で成立している。
生成した client が、host の実装した transport を引数で受け取っている。
生成した client の import が、viewer の ui port または extension の host port を実装する host の adapters に限られている。
viewer と extension が、生成物の型だけを型として import している。
生成物が、製品が採用する TypeScript の型検査を通っている。
データ型だけの公開入口の runtime 依存 closure に、通信 client と transport の実行機構が入っていない。

### 禁止事項
生成物を手で編集すること。
生成物を、client・型と drift・conformance の検査以外に使うこと。
生成した client の既定の transport を、そのまま製品の経路に使うこと。
viewer と extension から、生成した client を import すること。
生成した client を、viewer の ui port または extension の host port を実装する host の adapters 以外で使うこと。
生成器が要求する版の制約を、製品の型検査 toolchain の依存解決へ広げること。

### 行動
契約から `@typespec/http-client-js` で client と型を生成し、contracts/generated へ書き出して commit する。
データ型の公開入口を通信 client とは独立して生成し、接尾辞のための同義 DTO や alias を追加しない。
公開契約の runtime 検証は [valibot](./valibot.md) が定める生成 schema に接続し、その生成処理を同じ contracts 生成 task に含める。
検証入口で再生成し、差分が出たら失敗させる。
host の transport を client の引数へ渡し、TLS・proxy・timeout・再試行の判断を host 側に置く。
host の adapters が viewer の ui port または extension の host port の実装から生成 client を呼び、viewer と extension は対応する port を通して通信する。
viewer と extension では、生成物の型だけを `import type` で取り込む。

## 生成 client の応答を失敗の種類で分類する

### 要求
生成した client は、status と content-type が契約の宣言した成功に一致した応答の body を、契約の型と照合せずに返す。
宣言した失敗を含む他の応答は、status と body を持つ生成した `RestError` で throw する。
media type が厳密に `application/json` の body を JSON として読めない応答は、生成した client に届く前に、ts-http-runtime が `code` が `PARSE_ERROR` で `statusCode` を持つ `RestError` で throw する。
生成した client の operation は signal を引数に持たないので、呼び出しごとの signal は、transport が request の `abortSignal` に載せる形で与える。
adapter は、client が返した成功の body と、throw された `RestError` と `PARSE_ERROR` の error を、[valibot](./valibot.md) の「受け取ったエラーを parse し、想定された失敗と欠陥を分ける」に従い、status を先に、次に body の順に契約の schema と照合する。
生成した `RestError` の `status` は文字列なので、数値へ変換して契約の schema と照合する。
宣言した成功の status で body が契約の型に一致した応答は、`RestError` として届いても成功として返し、その変換は `Result.wrapAsync` に渡す関数リテラルの内側で行って、一致しない `RestError` は再 throw して `mapErr` の mapper へ回す。
宣言した失敗の status で body が契約の型に一致した応答は、宣言した失敗の Result で返す。
502・503・504 で body が契約の型に一致しない応答は、宣言の有無に関わらず、通信の不成立と同じ想定された失敗にする。
それ以外の status で、宣言していない応答と、宣言した status で body が契約の型に一致しない応答(`PARSE_ERROR` の error を含む)は、欠陥として投げる。
応答を伴わない通信の不成立は、host の transport が自身の error 型で reject したものだけとし、transport の error 型は [coordination](./coordination.md) の「取り消し」に従い、生成した `RestError` と混ぜず、[ts-results-es](./ts-results-es.md) の「非同期 API の送出を AsyncResult へ変換する」の error mapper で想定された失敗へ写す。
要求の組立で throw された error は、通信の不成立にせず、欠陥として投げる。
`RestError` と `PARSE_ERROR` の error は受け取り終えた応答なので、中断の判定より先に分類し、中断の識別と扱いは、coordination の「取り消し」に従う。
`RestError` の分類は、status の範囲で行わない。

### 根拠
生成した client は、宣言した成功のうち status と content-type が一致する応答の body を、property を写すだけで返す。
生成器は、`@error` のモデルの応答を `RestError` で throw し、`@error` でないモデルの応答を成功の値として返す。
content-type は大文字と小文字を区別して `application/json` を含むかで調べるので、`Application/JSON` のように表記の違う宣言した成功の応答も `RestError` になる。
必須項目を欠く body や型の違う body も、そのまま返る。
ts-http-runtime が `PARSE_ERROR` を throw するのは、media type が厳密に `application/json` の body を読めない場合だけで、他の media type の読めない body は文字列のまま届く。
宣言した失敗と宣言していない応答は、同じ `RestError` で届くので、throw された `RestError` の status と body を契約の schema と照合しなければ、区別できない。
生成した `RestError` は応答を持つ失敗だけを表すので、応答を伴わない通信の不成立は、transport の reject として届く。
通信の不成立と時間上限の超過と取り消しは、応答を持たない別の事態なので、`RestError` の分類へ混ぜると、想定された失敗と欠陥と取り消しが取り違えられる。
生成した client の operation は、request の options に `onResponse` しか持たず、signal を受け取らない。
ts-http-runtime の既定の pipeline の retry policy は、request の `abortSignal` が abort 済みなら、transport が応答を返した後でも再試行の待機中でも、signal の reason も cause も持たない `AbortError` で reject し、`maxRetries` を 0 にしても変わらない。
この rejection は応答を adapter へ届けないので、`name` と signal の状態による中断の識別で中断になる。
`mapErr` は Err のときだけ mapper を呼んで Err へ写すので、`RestError` を成功の値へ戻す変換は、`Result.wrapAsync` に渡す関数リテラルの内側で行う。

### 完了条件
生成した client が返した成功の body が、生成した schema で検証され、契約と一致しない場合に欠陥として投げられている。
throw された `RestError` と `PARSE_ERROR` の error が、status を先に、次に body の順に契約の schema と照合され、成功、宣言した失敗の Result、通信の不成立、欠陥のいずれかに分類されている。
宣言した成功の status で body が契約の型に一致する `RestError` が、`Result.wrapAsync` に渡す関数リテラルの内側で成功の値に戻され、成功として返されている。
502・503・504 で body が契約の型に一致しない応答が、宣言の有無に関わらず、通信の不成立と同じ想定された失敗の Result になっている。
それ以外の status の宣言していない応答、宣言した status で body が契約の型に一致しない応答、`PARSE_ERROR` の error が、欠陥として投げられている。
host の transport が自身の error 型で reject した通信の不成立だけが、`RestError` の分類と混ざらず、想定された失敗として Result で返されている。
要求の組立で throw された error が、欠陥として投げられている。
呼び出しごとの signal が、transport が request の `abortSignal` に載せる形で与えられている。
`RestError` と `PARSE_ERROR` の error が中断の判定より先に分類され、中断が coordination の「取り消し」に従って扱われている。
宣言した各 status、宣言していない 502・503・504 とそれ以外の status、502・503・504 と宣言した成功・失敗の status のそれぞれで契約の型に合わない body、表記の違う content-type の宣言した成功の応答、body が JSON として読めない応答、本文の途中での切断、接続の失敗、要求の組立の失敗、自身の上限の超過、取り消し、応答を受け取り終えた後の取り消し、既定の pipeline の再試行の待機中の abort と応答の受領直後の abort、上流の期限の伝播として受け取った signal の abort、その transport が持つ場合の transport 自身の timeout と取り消しによる中断の各場合が、実際の HTTP 応答で意図した分類になることが検証されている。

### 禁止事項
成功の body を、検証せずに契約の型として信頼すること。
throw された `RestError` を、status と body を契約の schema と照合せずに、宣言した失敗または欠陥へ振り分けること。
`RestError` の status の範囲で、宣言した失敗と欠陥を分類すること。
502・503・504 で body が契約の型に一致しない応答を、欠陥にすること。
通信の不成立と時間上限の超過を、`RestError` の分類へ混ぜること。
中断の判定を、`RestError` の分類より先に行うこと。

### 行動
client の呼出しを `Result.wrapAsync` に渡す関数リテラルへ入れ、error mapper で、`RestError` を契約の schema と照合して宣言した失敗へ写す。
成功の body も生成した schema で検証し、宣言した成功に一致する `RestError` は関数リテラルの内側で成功の値に戻し、502・503・504 以外で契約と一致しない body、宣言していない応答、`PARSE_ERROR` の error を欠陥として再 throw する。
502・503・504 で body が契約の型に一致しない応答と通信の不成立を想定された失敗へ写す。
`RestError` と `PARSE_ERROR` の error を中断の判定より先に分類し、中断を coordination の「取り消し」に従って扱う。
実際の HTTP 応答で、宣言した各 status、宣言していない 502・503・504 とそれ以外の status、契約の型に合わない body、表記の違う content-type、JSON として読めない body、本文の途中での切断、接続の失敗、要求の組立の失敗、自身の上限の超過、取り消し、応答を受け取り終えた後の取り消し、既定の pipeline の再試行の待機中の abort と応答の受領直後の abort、上流の期限の伝播として受け取った signal の abort、その transport が持つ場合の transport 自身の timeout と取り消しによる中断を起こし、分類を検証する。
