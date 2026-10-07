# serde

用途は、値を wire 形式と相互に直列化・逆直列化する機構である。
採用は、Rust は serde である。
判断基準は、値の直列化と逆直列化を型に基づいて行え、境界の DTO の宣言と一体で使えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
公開契約の入力は、[structure/contracts/generated](../../structure/contracts/generated.md) が定める生成 DTO と生成した `Deserialize` の処理で受ける。
deserialize は契約の形式と制約を検証し、生成 DTO からコンテキストの application 入力への写像は [structure/core/composition](../../structure/core/composition.md) に置く。
コンテキストの application は、自らの入力構築を検証付きの domain の constructor へ通し、検証を通った業務型だけを処理へ渡し、内側で同じ性質を再検証しない。
`TryFrom` は実装先の crate が対象の型を所有し、依存方向も守れる変換に使う。
生成 DTO とコンテキストの型がともに別 crate の型である場合は、composition に `Result` を返す mapper 関数を置き、foreign な型同士の `TryFrom` を surface に実装しない。
未知のフィールドは弾かず、生成した deserialize の処理で object の位置とキーを捕捉し、境界でログに出す。
捕捉は全 variant と入れ子の object に及ぼし、未知のキーを既知の field や判別子として扱わず、必須項目、値の制約、variant の対応の検証を維持する。
ドメイン型には直列化の derive を直接付けず、外部表現の命名や形式は生成 DTO と binding 側に置く。

### 根拠
ドメイン型に `Deserialize` の derive を素で付けると、検証を経ない値がそのまま内部へ入る。
生成 DTO の decode と、application の入力構築から domain の検証付き constructor への変換を分ければ、契約の保証と業務の保証の所有者を混同しない。
内側で再検証しないのは、境界で証明が済んでいるからである。
未知のフィールドを弾く既定は、送り手と受け手の版が配備で一時的に重なる瞬間の後方互換を壊すので、寛容な読み手にする。
検知した未知のフィールドをログに出せば残存が可視化され、恒常的に未知が流れ続ける状態は [evolution](../../principles/evolution/README.md) が定める収縮が終わっていない欠陥として扱える。
ドメイン型に直列化を付けると、外部表現の都合がドメインの形を縛る。
両方が foreign な型への `TryFrom` を境界に強制せず、依存が許される composition の mapper を使えば、domain を公開したりコンテキストへ外部契約を import したりせずに検証を一点に保てる。
未知フィールドの捕捉を `flatten` を付けられる形に限定せず、契約から生成する deserialize の処理へ持たせれば、判別付き直和にも同じ受容と検知の保証を適用できる。

### 完了条件
公開契約の入力が、具体的な field と variant を持つ生成 DTO で受けられている。
生成 DTO から application 入力への mapper が composition にあり、コンテキストの入力構築が検証付きの domain の constructor を通る。
変換の impl が crate の型所有と依存方向に従い、両型が foreign な場合は mapper 関数になっている。
未知のフィールドが全 variant と入れ子の object で拒否されず、位置とキーが捕捉されてログに出ている。
未知フィールドを受け入れても、必須項目、値の制約、判別子と variant の対応の不正が拒否される。
ドメイン型に、直列化の derive が付いていない。

### 禁止事項
ドメイン型に、`Deserialize` の derive を直接付けること。
境界を通った値を、内側で再び検証すること。
未知のフィールドを、既定で弾くこと。
未知のフィールドの検知を、ログに出さず握りつぶすこと。
生成 DTO と同じ意味の DTO を手書きで定義し、捕捉や検証を補うこと。
生成 DTO の捕捉不足を理由に、未知フィールドの検知を省くこと。
surface から非公開のドメイン型へ変換するために、domain を公開したり依存の向きを逆転したりすること。

### 行動
canonical と binding から、具体的な DTO と、既知の項目を検証し未知キーを捕捉する `Deserialize` の処理を生成する。
判別付き直和は schema の判別子で variant を選び、その variant の既知キーに照らして未知キーを捕捉する。
生成経路が捕捉を実現できなければ、生成器の設定や schema 駆動の出力処理を直し、手書き DTO や unknown-field policy の抑止で回避しない。
境界は捕捉した位置とキーを警告として記録し、値そのものや未知の資格情報をログに載せない。
composition の mapper は、生成 DTO の field をコンテキストの application 入力構築へ渡し、ドメイン型を直接参照しない。
出力は application の公開 result・outcome から生成 DTO への mapper で写し、生成 DTO の `Serialize` で直列化する。

### 例
ドメイン型に `Deserialize` を付けると、任意の入力が検証なしで内側へ入る。

```rust
#[derive(Deserialize)]
pub struct Email { address: String }
```

生成 DTO と application の型が別 crate にある場合は、composition の関数で写像する。
以下の `generated::CreateUserCommand` は生成物であり、`users::CreateUserCommand::try_new` はコンテキストの公開 application 入力構築で、内部の業務型の検証を所有する。
deserialize と未知キーの検知は mapper より上流の生成 decoder で行い、この関数は同じ検証を繰り返さない。

```rust
fn create_user_mapper(
    input: generated::CreateUserCommand,
) -> Result<users::CreateUserCommand, users::CreateUserError> {
    users::CreateUserCommand::try_new(input.email)
}
```
