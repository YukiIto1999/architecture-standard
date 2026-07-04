# translation

## 概要
translation は、Rust で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信・[effect](../../concerns/effect.md) が定めるエラーモデルを、Rust の機構で満たす。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
境界の入力は wire の型(DTO)で受け、deserialize した DTO を `TryFrom` でドメイン型へ一度だけ検証変換する。
検証を通った値だけを内部へ渡し、内側で再検証しない。
契約にない未知のフィールドは `#[serde(deny_unknown_fields)]` で既定で弾く。
ドメイン型には直列化の derive を直接付けず、外部表現の命名や形式は境界の DTO 側に置く。

### 根拠
ドメイン型に `Deserialize` の derive を素で付けると、検証を経ない値がそのまま内部へ入る。
wire の DTO に受けてから `TryFrom` で変換すれば、検証が境界の一点に集まり、ドメイン型を持つこと自体が検証済みの証になる。
内側で再検証しないのは、境界で証明が済んでいるからである。
未知のフィールドを既定で弾くのは、境界の外を信頼しないためである。
ドメイン型に直列化を付けると、外部表現の都合がドメインの形を縛る。

### 完了条件
境界の入力が、wire の型で受けられている。
ドメイン型への変換が `TryFrom` の一点に集まり、検証を通らない値が内部に入らない。
未知のフィールドが、既定で弾かれている。
ドメイン型に、直列化の derive が付いていない。

### 禁止事項
ドメイン型に、`Deserialize` の derive を直接付けること。
境界を通った値を、内側で再び検証すること。

### 行動
境界に wire の DTO を `#[derive(Deserialize)]` で定義し、deserialize した DTO を `TryFrom` でドメイン型へ検証変換する。
ドメイン型には直列化の derive を付けない。出力はドメイン型から DTO への明示の写像で行い、DTO に `Serialize` を付ける。

### 例
```rust
// ドメイン型に直接 Deserialize。任意の入力が検証なしで内側へ入る
#[derive(Deserialize)]
pub struct Email { address: String }

// wire の DTO だけが Deserialize を持つ。named field の struct でなければ deny_unknown_fields は効かない
// (単一フィールドの tuple struct は newtype として直接 deserialize され、フィールドの照合を経ない)
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]                  // 契約に無いキー(例: "domain")があれば弾く
pub struct EmailDto { address: String }
#[derive(Debug, Clone, PartialEq, Eq, Hash)]   // ドメイン型は直列化の derive を持たない
pub struct Email(String);
impl TryFrom<EmailDto> for Email {
    type Error = EmailError;
    fn try_from(value: EmailDto) -> Result<Self, EmailError> { Email::try_new(value.address) }
}
// 境界: let email = Email::try_from(serde_json::from_str::<EmailDto>(input)?)?;
```

## 公開するエラーを境界で problem+json へ写す

### 要求
公開するエラーは境界で RFC 9457 の problem+json へ写し、写像を `IntoResponse` の実装に集約して handler へ散らさない。
内部の実装の詳細を、応答に出さない。

### 根拠
エラーの写像を handler ごとに書くと、表現が揺れ重複する。
`IntoResponse` に集約すれば、公開するエラーの形が一箇所で決まる。
problem+json の標準の形に従えば、利用側が機械的に扱える。
内部の詳細を応答に出すと、攻撃の手がかりを与える。

### 完了条件
公開エラーが、problem+json へ写されている。
写像が `IntoResponse` の実装に集約され、handler に散っていない。
応答に、内部の実装の詳細が出ていない。

### 禁止事項
エラーの写像を、handler ごとに散らすこと。
内部の実装の詳細を、応答に出すこと。

### 行動
ドメインのエラー型を thiserror で定義し、`IntoResponse` の実装で problem+json へ写す。
`detail` に内部の詳細を載せない。

### 例
```rust
// 公開エラーの写像を handler ごとに書く。表現が揺れる
async fn handler() -> Response { /* ここで個別に problem+json を組む */ }

// IntoResponse に集約する
impl IntoResponse for ApiError {
    fn into_response(self) -> Response { /* RFC 9457 の problem+json を一箇所で組む */ }
}
```

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の Rust の client と型は、TypeSpec から `@typespec/openapi3` で出力した OpenAPI を、openapi-generator の rust generator(library=reqwest)に渡して生成する。
server の実装と生成した契約との drift 検査と conformance を、CI の gate にする。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から生成すれば、client と型が契約に従う。
`@typespec/openapi3` は OpenAPI を安定した出力として持ち、openapi-generator の rust generator は任意の OpenAPI から生成でき、生成元を特定の emitter に縛らない。
drift と conformance を CI の gate にすれば、ずれが取り込まれる前に止まる。

### 完了条件
生成物が、contracts/generated に置かれている。
client と型が、TypeSpec から `@typespec/openapi3` を経て openapi-generator の rust generator で生成されている。
drift 検査と conformance が、CI の gate になっている。

### 禁止事項
生成した契約と実装の drift を、検査せずに取り込むこと。
contracts/generated の生成物を、手で編集すること。

### 行動
TypeSpec から `@typespec/openapi3` で OpenAPI を出力し、openapi-generator の rust generator(library=reqwest)で client と型を生成する。
drift 検査と conformance を CI の gate に置く。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
