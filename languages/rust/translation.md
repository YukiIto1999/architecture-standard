# translation

## 概要
translation は、Rust で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信・[effect](../../concerns/effect.md) が定めるエラーモデルを、Rust の機構で満たす。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
境界の入力は wire の型(DTO)で受け、deserialize した DTO を `TryFrom` でドメイン型へ一度だけ検証変換する。
検証を通った値だけを内部へ渡し、内側で再検証しない。
契約にない未知のフィールドは弾かず、`#[serde(flatten)]` の捕捉フィールドで受け、値があればログに出す。
ドメイン型には直列化の derive を直接付けず、外部表現の命名や形式は境界の DTO 側に置く。

### 根拠
ドメイン型に `Deserialize` の derive を素で付けると、検証を経ない値がそのまま内部へ入る。
wire の DTO に受けてから `TryFrom` で変換すれば、検証が境界の一点に集まり、ドメイン型を持つこと自体が検証済みの証になる。
内側で再検証しないのは、境界で証明が済んでいるからである。
未知のフィールドを弾く既定は、送り手と受け手の版が配備で一時的に重なる瞬間の後方互換を壊すので、寛容な読み手にする。
検知した未知のフィールドをログに出せば残存が可視化され、恒常的に未知が流れ続ける状態は [evolution](../../principles/evolution.md) が定める収縮が終わっていない欠陥として扱える。
ドメイン型に直列化を付けると、外部表現の都合がドメインの形を縛る。

### 完了条件
境界の入力が、wire の型で受けられている。
ドメイン型への変換が `TryFrom` の一点に集まり、検証を通らない値が内部に入らない。
未知のフィールドが、弾かれず `#[serde(flatten)]` の捕捉フィールドで受けられている。
未知のフィールドを検知したら、ログに出ている。
ドメイン型に、直列化の derive が付いていない。

### 禁止事項
ドメイン型に、`Deserialize` の derive を直接付けること。
境界を通った値を、内側で再び検証すること。
未知のフィールドを、既定で弾くこと。
未知のフィールドの検知を、ログに出さず握りつぶすこと。

### 行動
境界に wire の DTO を `#[derive(Deserialize)]` で定義し、deserialize した DTO を `TryFrom` でドメイン型へ検証変換する。
DTO に `#[serde(flatten)] extra: HashMap<String, serde_json::Value>` のような捕捉フィールドを持たせ、非空なら警告としてログに出す。
ドメイン型には直列化の derive を付けない。出力はドメイン型から DTO への明示の写像で行い、DTO に `Serialize` を付ける。

### 例
ドメイン型に `Deserialize` を付けると、任意の入力が検証なしで内側へ入る。

```rust
#[derive(Deserialize)]
pub struct Email { address: String }
```

wire の DTO だけに `Deserialize` を付け、未知のフィールドは `flatten` で捕捉する。ドメイン型は直列化せず、入力境界から `TryFrom` の一点を通す。

```rust
#[derive(Deserialize)]
pub struct EmailRequest {
    address: String,
    #[serde(flatten)]
    extra: HashMap<String, serde_json::Value>,
}
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Email(String);
impl TryFrom<EmailRequest> for Email {
    type Error = EmailError;
    fn try_from(value: EmailRequest) -> Result<Self, EmailError> {
        if !value.extra.is_empty() { tracing::warn!(keys = ?value.extra.keys(), "未知のフィールドを検知した"); }
        Email::try_new(value.address)
    }
}
```

## 終了を surface の境界表現へ写す

### 要求
server、console、worker、host、extension の全 surface は、終了を成功、想定内の失敗、欠陥、取り消しに同じ基準で分類する。
想定内の失敗は、各 surface の契約が定める失敗表現へ境界で写す。
panic で表す欠陥は、各 surface の最上位の報告境界で記録して失敗させる。
取り消しは、想定内の失敗へ変換しない。
内部の実装の詳細は、surface の出力へ出さない。

### 根拠
終了の分類を surface ごとに変えると、同じ事象が入口によって失敗にも欠陥にもなり、回復方法が揺れる。
想定内の失敗だけを surface の契約へ写せば、利用側が処理できる終了と運用が扱う欠陥を分けられる。
取り消しを失敗へ変換すると、呼び出し側が諦めた計算を業務上の失敗と誤認する。
内部の詳細を出力すると、利用側を実装へ結合させ、攻撃の手がかりを与える。

### 完了条件
全 surface で、終了が成功、想定内の失敗、欠陥、取り消しに同じ基準で分類されている。
想定内の失敗が、各 surface の契約が定める失敗表現へ境界で写されている。
欠陥が、各 surface の最上位の報告境界で記録されている。
取り消しが、想定内の失敗へ変換されていない。
surface の出力に、内部の実装の詳細が出ていない。

### 禁止事項
同じ終了を、surface ごとに異なる基準で失敗または欠陥へ分類すること。
欠陥や取り消しを、想定内の失敗として surface の契約へ写すこと。
内部の実装の詳細を、surface の出力へ出すこと。

### 行動
成功、想定内の失敗、欠陥、取り消しを [effect](../../concerns/effect.md) の基準で分類する。
想定内の失敗だけを、各 surface の契約が定める表現へ境界で写す。
欠陥は最上位の報告境界で記録し、取り消しは失敗へ変換せず終了させる。
surface の出力から内部の詳細を除く。

### 例
各 surface は同じ分類を使い、想定内の失敗だけを自身の契約へ写す。panic は最上位で報告し、取り消しは `Err` へ変換しない。

```rust
match run(input).await {
    Ok(value) => surface.publish_success(value),
    Err(failure) => surface.publish_expected_failure(failure),
}
```

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の Rust の client と型は、[tools/build](../../tools/build.md) が採用した経路で生成する。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から生成すれば、client と型が契約に従う。
生成経路を tools の採用へ一本化すれば、言語文書は生成物の使い方だけを所有できる。

### 完了条件
client と型が、TypeSpec から `@typespec/openapi3` を経て openapi-generator の rust generator で生成されている。

### 禁止事項
契約から生成する client と型を手で書き写すこと、または tools と別の generator を選ぶこと。

### 行動
TypeSpec から `@typespec/openapi3` で OpenAPI を出力し、openapi-generator の rust generator(library=reqwest)で client と型を生成する。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、未知フィールドの残存と収縮は [evolution](../../principles/evolution.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
