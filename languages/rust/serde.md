# serde

用途は、値を wire 形式と相互に直列化・逆直列化する機構である。
採用は、Rust は serde である。
判断基準は、値の直列化と逆直列化を型に基づいて行え、境界の DTO の宣言と一体で使えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
公開契約の入力は、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成 DTO と生成した `Deserialize` の処理で受ける。
worker が durable queue から受ける job の payload も境界の入力であり、実際に受信する経路で、payload が宣言する版の契約の生成 DTO により decode と検証を行う。
deserialize は契約の形式と制約を検証し、生成 DTO からコンテキストの application 入力への写像は [structure/contracts/adapters](../../structure/contracts/adapters.md) に置く。
コンテキストの application は、自らの入力構築を検証付きの domain の constructor へ通し、検証を通った業務型だけを処理へ渡し、内側で同じ性質を再検証しない。
`TryFrom` は実装先の crate が対象の型を所有し、依存方向も守れる変換に使う。
生成 DTO とコンテキストの型がともに別 crate の型である場合は、contracts/adapters に `Result` を返す mapper 関数を置き、foreign な型同士の `TryFrom` を surface に実装しない。
未知のフィールドは弾かず、生成した deserialize の処理で object の位置とキーを捕捉し、境界でログに出す。
捕捉は全 variant と入れ子の object に及ぼし、未知のキーを既知の field や判別子として扱わず、必須項目、値の制約、variant の対応の検証を維持する。
未知の追加項目の受容は、選択した版の必須項目の欠落、契約が許さない null、既知項目の不正、判別子の不整合の受容を意味せず、これらは deserialize または application 入力構築の失敗として拒否し、業務処理を始めない。
必須項目の欠落と契約が許さない null の拒否を、`default` 属性による補完や `Option` への読み替えで外さない。
`Option` による不在は契約が定める意味と範囲で使い、旧版との互換のためだけに必須項目を任意にしない。
未指定と null は [canonical](../../structure/contracts/canonical.md) の「値の不在」に対応させ、契約上必要な区別を生成 DTO と deserialize の過程で失わない。
旧版の payload を受ける互換構造は境界に閉じ、旧版の契約から導けない事実を既定値で作らず、現在の構造へ写してから、内側へ現在の検証済みの型だけを渡す。
保持する履歴の旧版の読み出し変換は、[persistence](../../concerns/persistence/read-time-upcasting.md) の「追記した事実の版を読み出しで現在へ変換する」に従い、保持・監査・回復の契約が旧版の解釈を必要とする間は存続する。
配送の一時的な互換対応の撤去は、[messaging](../../concerns/messaging/event-contract-versioning.md) の「イベント契約を版で進化させ、寛容に読む」に従い、履歴の読み出し変換の存続とは別に判断する。
ドメイン型には直列化の derive を直接付けず、外部表現の命名や形式は生成 DTO と binding 側に置く。

### 根拠
ドメイン型に `Deserialize` の derive を素で付けると、検証を経ない値がそのまま内部へ入る。
生成 DTO の decode と、application の入力構築から domain の検証付き constructor への変換を分ければ、契約の保証と業務の保証の所有者を混同しない。
内側で再検証しないのは、境界で証明が済んでいるからである。
未知のフィールドを弾く既定は、送り手と受け手の版が配備で一時的に重なる瞬間の後方互換を壊すので、寛容な読み手にする。
検知した未知のフィールドをログに出せば、送り手が契約へ追加した項目を境界で観測できる。
未知のキーが恒常的に届くことだけでは、旧い処理が残っている証拠にならない。
ドメイン型に直列化を付けると、外部表現の都合がドメインの形を縛る。
両方が foreign な型への `TryFrom` を境界に強制せず、core の外側にある contracts/adapters の mapper を使えば、domain を公開したり core へ外部契約を import したりせずに検証を一点に保てる。
未知フィールドの捕捉を `flatten` を付けられる形に限定せず、契約から生成する deserialize の処理へ持たせれば、判別付き直和にも同じ受容と検知の保証を適用できる。
未知の追加項目を受容しても、必須項目の欠落や不正な null を `default` 属性や `Option` で通せば、欠けた値が既定値として業務処理へ入り、拒否すべき入力が正常に処理される。
queue の job には旧い版の発行元が積んだものや再投入されたものが混ざるので、実際に受信する経路で版の契約を検証しなければ、内部の入力であることを理由に不正な payload が素通りする。
互換構造を境界に閉じ、旧版に存在しない値を作らなければ、内側の型は現在の保証を保ち、保存も配送もされなかった事実を変換が創作しない。
保持・監査・回復の契約が旧版の解釈を必要とする間は旧版の履歴を読み続ける必要があり、配送の一時的な互換対応と同じ条件で撤去すると、保持する事実を解釈できなくなる。

### 完了条件
公開契約の入力が、具体的な field と variant を持つ生成 DTO で受けられている。
queue から受ける job の payload が、実際に受信する経路で、payload が宣言する版の契約の生成 DTO により decode と検証をされている。
生成 DTO から application 入力への mapper が contracts/adapters にあり、コンテキストの入力構築が検証付きの domain の constructor を通る。
変換の impl が crate の型所有と依存方向に従い、両型が foreign な場合は mapper 関数になっている。
未知のフィールドが全 variant と入れ子の object で拒否されず、位置とキーが捕捉されてログに出ている。
未知フィールドを受け入れても、選択した版の必須項目の欠落、契約が許さない null、値の制約を含む既知項目の不正、判別子と variant の対応の不正が拒否され、拒否した入力で業務処理が始まらない。
必須項目の欠落と契約が許さない null の拒否が、`default` 属性による補完や `Option` への読み替えで外れておらず、不在の意味と範囲が契約に一致している。
旧版の互換構造が境界に閉じ、保存も送信もされていない事実が架空の値で補われず、内側へ現在の検証済みの型だけが渡されている。
保持する履歴の旧版の読み出し変換が、旧版の解釈を必要とする契約が残る間は存続し、配送の一時的な互換対応の撤去と別に判断されている。
ドメイン型に、直列化の derive が付いていない。

### 禁止事項
ドメイン型に、`Deserialize` の derive を直接付けること。
境界を通った値を、内側で再び検証すること。
未知のフィールドを、既定で弾くこと。
未知のフィールドの検知を、ログに出さず握りつぶすこと。
必須項目の欠落、契約が許さない null、既知項目の不正を、未知項目の受容を理由に受け入れること。
必須項目を、`default` 属性による補完や、旧版との互換のためだけの `Option` への読み替えで受け入れること。
旧版の契約から導けない事実を、変換で既定値として作ること。
旧版の互換構造を、境界の外へ公開して内側の処理から参照させること。
配送の一時的な互換対応の撤去を理由に、保持・監査・回復の契約が必要とする履歴の読み出し変換を撤去すること。
生成 DTO と同じ意味の DTO を手書きで定義し、捕捉や検証を補うこと。
生成 DTO の捕捉不足を理由に、未知フィールドの検知を省くこと。
surface から非公開のドメイン型へ変換するために、domain を公開したり依存の向きを逆転したりすること。

### 行動
canonical と binding から、具体的な DTO と、既知の項目を検証し未知キーを捕捉する `Deserialize` の処理を生成する。
判別付き直和は schema の判別子で variant を選び、その variant の既知キーに照らして未知キーを捕捉する。
生成経路が捕捉を実現できなければ、生成器の設定や schema 駆動の出力処理を直し、手書き DTO や unknown-field policy の抑止で回避しない。
境界は捕捉した位置とキーを警告として記録し、値そのものや未知の資格情報をログに載せない。
queue の job は、受信経路の decode で payload が宣言する版の生成 DTO を選び、公開契約の入力と同じ検証を通してから mapper へ渡す。
未知キーを加えた入力と、必須項目の欠落、契約が許さない null、既知項目の不正、判別子の不整合を加えた入力を、実際の受信経路へ別々に渡し、前者の受容と後者の拒否および業務処理の非開始を確かめる。
旧版の都合だけで任意になっている項目は、互換構造を境界に置き、現在の型を必須のまま保つ。
旧版の撤去は、履歴の読み出し変換と配送の一時的な互換対応を分け、それぞれの存続条件で判断する。
contracts/adapters の mapper は、生成 DTO の field を core が公開する application 入力構築へ渡し、ドメイン型を直接参照しない。
出力は application の公開 result・outcome から生成 DTO への mapper で写し、生成 DTO の `Serialize` で直列化する。

### 例
ドメイン型に `Deserialize` を付けると、任意の入力が検証なしで内側へ入る。

```rust
#[derive(Deserialize)]
pub struct Email { address: String }
```

生成 DTO と application の型が別 crate にある場合は、contracts/adapters の関数で写像する。
以下の `generated::CreateUserCommand` は生成物であり、`users::CreateUserCommand::try_new` はコンテキストの公開 application 入力構築で、内部の業務型の検証を所有する。
deserialize と未知キーの検知は mapper より上流の生成 decoder で行い、この関数は同じ検証を繰り返さない。

```rust
fn create_user_mapper(
    input: generated::CreateUserCommand,
) -> Result<users::CreateUserCommand, users::CreateUserError> {
    users::CreateUserCommand::try_new(input.email)
}
```
