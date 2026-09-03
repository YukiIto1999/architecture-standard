# serde

用途は、値を wire 形式と相互に直列化・逆直列化する機構である。
採用は、Rust は serde である。
判断基準は、値の直列化と逆直列化を型に基づいて行え、境界の DTO の宣言と一体で使えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

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
