# typify

用途は、JSON Schema から Rust のデータ型を生成し、HTTP と非 HTTP の契約の decode と未知項目の捕捉の生成規律を定める道具である。
採用は、Rust は typify である。
判断基準は、`@typespec/json-schema` が出力する JSON Schema から具体的な field と variant を持つ contracts/generated の型を生成でき、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成能力と依存単位の分離を満たし、HTTP と JSON Schema の経路で同じ規律になり、同じ入力と同じ版から同じ出力を得て drift をリポジトリの検証入口の gate にできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、入力 Schema を受け取れなくなること、判別付き直和または未知項目の捕捉を生成経路で実現できなくなること、同じ入力と同じ版から異なる出力を出すようになることを再評価のトリガーとする。

## 契約から decode と未知項目の捕捉を生成する

### 要求
typify を使う生成 task は、型の生成に加え、canonical と binding の schema から serde の deserialize と未知項目の捕捉を生成する。
生成した `Deserialize` の処理は schema の判別子で variant を選び、全 variant と入れ子の object で未知のキーの位置を捕捉する。
既知の field、必須項目、不在、値の制約、判別子と payload の対応は schema に従って検証する。
未知のキーを受け入れるために既知項目の不正を通したり、variant を payload の形の推測だけで選んだりしない。
捕捉の記録は境界の報告へ渡し、契約の意味を持つ field として domain へ渡したり、応答へ反射したりしない。
serde の処理と DTO は、通信 client から独立したデータ型の crate に出力する。
生成器の既定の出力にこの能力がなければ、schema 駆動の出力処理を同じ生成 task に組み込み、入力と生成処理から再生成できる状態にする。

### 根拠
公開契約の意味を手書き DTO へ写すと、同じ field と variant の第二の正本が生まれる。
未知項目の受容と検知を生成経路が所有すれば、利用側の型の写しや生成後の編集なしに、全 object と variant に同じ保証を適用できる。
variant の識別とその既知キーを schema から導けば、未知項目の捕捉を直和の外側の `flatten` に依存させずに済む。

### 完了条件
公開契約の DTO と serde の処理が、canonical と binding から単一の task で再生成できる。
全 variant と入れ子の object で未知キーの位置が捕捉され、既知項目の不正と判別子の不正は拒否される。
捕捉したキーが境界のログへ届き、捕捉した値が domain や応答へ流れない。
HTTP と JSON Schema の両経路の生成物が同じ生成規律を満たし、データ型の crate が通信 client へ依存しない。

### 禁止事項
同じ意味の手書き DTO、手書き variant、生成後の手修正で生成能力を補うこと。
型生成器の既定の出力で捕捉できないことを理由に、未知項目の検知や既知項目の検証を省くこと。
汎用の map や `serde_json::Value` を公開契約の具体的な生成 DTO の代わりにすること。

### 行動
生成 task の入力に canonical、binding、生成器の版、設定、schema 駆動の出力処理を含める。
型と deserialize の生成を同じ schema に基づいて行い、生成物を contracts/generated に書き出す。
全 variant、入れ子の object、配列の要素の object に未知キーを追加した入力で、受容と捕捉の位置を検証する。
同じ入力集合について、必須項目の欠落、値の制約違反、判別子と payload の不一致を拒否することも検証する。
再生成の差分と生成能力の検査を repository の検証入口で失敗として扱う。
