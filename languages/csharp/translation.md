# translation

## 概要
translation は、C# で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信を、C# の機構で満たす。

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

## 公開するエラーを境界で problem+json へ写す

### 要求
`Result` から HTTP の応答への写像は handler の終端に置き、`ProblemDetails` の機構で RFC 9457 の problem+json へ写す。
未処理の例外は例外 handler の middleware が一括で problem+json へ変換する。
内部の実装の詳細を、応答に出さない。

### 根拠
エラーの写像を handler の各所に書くと、表現が揺れ重複する。
handler の終端に置き、未処理の例外を middleware で一括変換すれば、公開するエラーの形が一箇所で決まる。
problem+json の標準の形に従えば、利用側が機械的に扱える。
内部の詳細を応答に出すと、攻撃の手がかりを与える。

### 完了条件
失敗が、problem+json へ写されている。
写像が handler の終端と例外 handler の middleware に集約され、各所に散っていない。
応答に、内部の実装の詳細が出ていない。

### 禁止事項
エラーの写像を、handler の各所に散らすこと。
内部の実装の詳細を、応答に出すこと。

### 行動
`Result` から応答への写像を handler の終端に置き、`ProblemDetails` で problem+json へ写す。
未処理の例外を例外 handler の middleware で一括変換する。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の C# の client と型は NSwag で生成し、利用を client・型と drift・conformance の検査に限る。
server の stub 生成に使わず、server の実装は Minimal API を保つ。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
server の stub を生成すると、生成の都合が server の構造を縛るので、server は Minimal API を保つ。

### 完了条件
client と型が、NSwag で生成されている。
NSwag の利用が、生成と検査に限られ、server の stub 生成に使われていない。

### 禁止事項
NSwag を、server の stub 生成に使うこと。

### 行動
NSwag で client と型を生成し、server は Minimal API で実装する。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、未知フィールドの残存と収縮は [evolution](../../principles/evolution.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
