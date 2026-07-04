# translation

## 概要
translation は、C# で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界での変換と、concerns の [types](../../concerns/types.md) が定める境界での parse・[security](../../concerns/security.md) が定める境界の不信を、C# の機構で満たす。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
境界の入力は DTO の record(`init` のプロパティと `[JsonPropertyName]`)で受け、source generation の `JsonSerializerContext` を通す。
ドメイン型へは値オブジェクトの factory で詰め替え、失敗は Result で表す。
検証を通った値だけを内部へ渡し、内側で再検証しない。
未知のフィールドは `[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]` で弾き、必須の項目は `required` で欠落を弾く。
外部表現の命名や形式は境界の DTO 側に置き、ドメイン型を直接直列化しない。

### 根拠
ドメインのエンティティに直接デシリアライズすると、検証を経ない値がそのまま内部へ入る。
境界の DTO に受けてから factory で詰め替えれば、検証が境界の一点に集まる。
source generation は実行時のリフレクションを避け、契約を明示する。
未知のフィールドを弾き必須を強制するのは、境界の外を信頼しないためである。
ドメイン型を直接直列化すると、外部表現の都合がドメインの形を縛る。

### 完了条件
境界の入力が、DTO の record で受けられている。
ドメイン型への変換が値オブジェクトの factory に集まり、失敗が Result で表されている。
未知のフィールドが弾かれ、必須の項目の欠落が弾かれている。
ドメイン型が、直接直列化されていない。

### 禁止事項
ドメインのエンティティに、直接デシリアライズすること。
境界を通った値を、内側で再び検証すること。

### 行動
境界に DTO の record を定義し、`JsonSerializerContext` に登録する。
値オブジェクトの factory で詰め替え、`JsonUnmappedMemberHandling.Disallow` と `required` で境界を締める。

### 例
```csharp
// ドメインのエンティティに直接デシリアライズ。検証なしの値が内側へ
var user = JsonSerializer.Deserialize<User>(json);

// 境界の DTO record に受け、factory でドメイン型へ詰め替える
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]  // 未知を弾く
public sealed record CreateUserDto
{
    [JsonPropertyName("email")] public required string Email { get; init; }  // 欠落を弾く
}
Result<User> ToDomain(CreateUserDto dto) =>
    Email.Create(dto.Email).Map(email => new User(email));        // factory が検証
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
drift と conformance を CI の gate にする。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
server の stub を生成すると、生成の都合が server の構造を縛るので、server は Minimal API を保つ。
drift と conformance を CI の gate にすれば、ずれが取り込まれる前に止まる。

### 完了条件
client と型が、NSwag で生成されている。
NSwag の利用が、生成と検査に限られ、server の stub 生成に使われていない。
drift と conformance が、CI の gate になっている。

### 禁止事項
NSwag を、server の stub 生成に使うこと。
生成した契約と実装の drift を、検査せずに取り込むこと。

### 行動
NSwag で client と型を生成し、server は Minimal API で実装する。
drift と conformance を CI の gate に置く。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
