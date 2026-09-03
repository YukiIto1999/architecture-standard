# translation

## 概要
translation は、C# で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信を、C# の機構で満たす。
problem+json への写しの規律は [aspnet-core](./aspnet-core.md) が、契約生成と drift 検査の規律は [nswag](./nswag.md) が持つ。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
境界の入力は DTO の record(`init` のプロパティと `[JsonPropertyName]`)で受け、source generation の `JsonSerializerContext` を通す。
ドメイン型へは値オブジェクトの factory で検証変換し、失敗は Result で表す。
検証を通った値だけを内部へ渡し、内側で再検証しない。
未知のフィールドは弾かず、`[JsonExtensionData]` で捕捉し、値があればログに出す。必須の項目は `required` で欠落を弾く。
外部表現の命名や形式は境界の DTO 側に置き、ドメイン型を直接直列化しない。

### 根拠
ドメインのエンティティに直接デシリアライズすると、検証を経ない値がそのまま内部へ入る。
境界の DTO に受けてから factory で検証変換すれば、検証が境界の一点に集まる。
source generation は実行時のリフレクションを避け、契約を明示する。
未知のフィールドを弾く既定は、送り手と受け手の版が配備で一時的に重なる瞬間の後方互換を壊すので、寛容な読み手にし、必須の項目だけ `required` で欠落を弾く。
検知した未知のフィールドをログに出せば残存が可視化され、恒常的に未知が流れ続ける状態は [evolution](../../principles/evolution.md) が定める収縮が終わっていない欠陥として扱える。
ドメイン型を直接直列化すると、外部表現の都合がドメインの形を縛る。

### 完了条件
境界の入力が、DTO の record で受けられている。
ドメイン型への変換が値オブジェクトの factory に集まり、失敗が Result で表されている。
未知のフィールドが、弾かれず `[JsonExtensionData]` で捕捉されている。
未知のフィールドを検知したら、ログに出ている。
必須の項目の欠落が、弾かれている。
ドメイン型が、直接直列化されていない。

### 禁止事項
ドメインのエンティティに、直接デシリアライズすること。
境界を通った値を、内側で再び検証すること。
未知のフィールドを、既定で弾くこと。
未知のフィールドの検知を、ログに出さず握りつぶすこと。

### 行動
境界に DTO の record を定義し、`JsonSerializerContext` に登録する。
DTO に `[JsonExtensionData]` の捕捉プロパティを持たせ、非空なら警告としてログに出す。
値オブジェクトの factory で検証変換し、`required` で境界を締める。

### 例
外部入力をドメインエンティティへ直接デシリアライズすると、未検証の値が内側へ入る。

```csharp
var user = JsonSerializer.Deserialize<User>(json);
```

境界の DTO record で受け、factory が検証したドメイン型へ写す。欠落は拒否し、未知のキーは捨てずに捕捉する。

```csharp
public sealed record CreateUserRequest
{
    [JsonPropertyName("email")] public required string Email { get; init; }
    [JsonExtensionData] public IDictionary<string, JsonElement>? Extra { get; init; }
}
Result<User> ToDomain(CreateUserRequest request)
{
    if (request.Extra is { Count: > 0 }) logger.LogWarning("未知のフィールドを検知した: {Keys}", request.Extra.Keys);
    return Email.Create(request.Email).Map(email => new User(email));
}
```

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、未知フィールドの残存と収縮は [evolution](../../principles/evolution.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
