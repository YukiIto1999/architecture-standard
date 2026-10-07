# NSwag

用途は、契約から C# の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、C# は NSwag であり、HTTP を持たない契約は NSwag の JSON Schema 入力で型を生成する。
判断基準は、contracts/generated の client と具体的なデータ型を契約から生成でき、`@typespec/json-schema` が出力する JSON Schema からも型を生成でき、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成能力と依存単位の分離を満たし、drift をリポジトリの検証入口の gate にできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、契約記述言語の生成器が JSON Schema 入力を含めて同じ判断基準を満たすようになることを再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の C# の client と型は NSwag で生成し、利用を client・型と drift・conformance の検査に限る。
server の stub 生成に使わず、server の実装は Minimal API を保つ。
データ型と serializer の処理は、HTTP client を持つ client とは別の assembly に出力し、server と core の composition はデータ型の assembly だけを使う。
不変な入出力、必須項目と値の制約の検証、全 variant と入れ子の object の未知キー捕捉を生成器の設定と template に含め、同じ入力から再生成できる状態にする。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
server の stub を生成すると、生成の都合が server の構造を縛るので、server は Minimal API を保つ。

### 完了条件
client と型が、NSwag で生成されている。
NSwag の利用が、生成と検査に限られ、server の stub 生成に使われていない。
提供側と core の composition が生成 DTO を使い、データ型の assembly の依存 closure に通信 client とその実行機構が入っていない。
生成 DTO の serializer が [translation](./translation.md) の契約の検証と未知項目の捕捉を満たしている。

### 禁止事項
NSwag を、server の stub 生成に使うこと。
同じ意味の手書き DTO や生成物の手修正で、契約の検証や未知項目の捕捉を補うこと。

### 行動
NSwag で client とデータ型を別 assembly に生成し、server は生成 DTO を Minimal API で受け渡す。
serializer の処理を含む生成能力を検査し、不足は canonical、binding、生成器の設定と template で直す。
