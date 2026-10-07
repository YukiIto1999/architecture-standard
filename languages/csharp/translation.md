# translation

## 概要
translation は、C# で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、C# の機構で満たす。
problem+json への写しの規律は [aspnet-core](./aspnet-core.md) が、契約生成と drift 検査の規律は [nswag](./nswag.md) が持つ。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
公開契約の入力は生成 DTO で受け、source generation の `JsonSerializerContext` を通す。
生成 DTO のプロパティ、外部名、必須性、不在、値の制約を canonical と binding から導き、同じ意味の record を手書きで定義しない。
生成 DTO とコンテキストの application 入出力との写像は core の composition に置き、コンテキストの入力構築から値オブジェクトの factory へ検証を集め、失敗は Result で表す。
検証を通った値だけを業務処理へ渡し、内側で同じ性質を再検証しない。
未知のフィールドは弾かず、生成した `[JsonExtensionData]` の捕捉と serializer の処理で位置とキーを記録し、境界でログに出す。
必須項目の欠落と既知項目の不正は、生成 DTO の `required` と生成した converter により拒否する。
外部表現の命名や形式は生成 DTO と binding 側に置き、ドメイン型を直接直列化しない。

### 根拠
ドメインのエンティティに直接デシリアライズすると、検証を経ない値がそのまま内部へ入る。
生成 DTO の契約の検証と、composition から application の入力構築を通す業務型の検証を分ければ、それぞれの保証を所有者の一点に集められる。
source generation は実行時のリフレクションを避け、契約を明示する。
未知のフィールドを弾く既定は送り手と受け手の配備が一時的に重なるときの互換を壊すので、寛容な読み手にし、既知の項目の不正は拒否する。
検知した未知のフィールドをログに出せば残存が可視化され、恒常的に未知が流れ続ける状態は [evolution](../../principles/evolution/README.md) が定める収縮が終わっていない欠陥として扱える。
ドメイン型を直接直列化すると、外部表現の都合がドメインの形を縛る。

### 完了条件
公開契約の入力が、canonical と binding から生成した具体的な DTO で受けられている。
composition の写像からコンテキストの入力構築と値オブジェクトの factory へ検証が集まり、失敗が Result で表されている。
未知フィールドの位置とキーが全 variant と入れ子の object で捕捉され、境界のログへ届いている。
捕捉した値が domain や応答へ流れていない。
必須項目の欠落、値の制約違反、判別子と payload の不一致が拒否されている。
ドメイン型が、直接直列化されていない。

### 禁止事項
ドメインのエンティティに、直接デシリアライズすること。
境界を通った値を、内側で再び検証すること。
未知のフィールドを、既定で弾くこと。
未知のフィールドの検知を、ログに出さず握りつぶすこと。
生成 DTO の不足を、同じ意味の手書き DTO や生成物の手修正で補うこと。

### 行動
生成 DTO を `JsonSerializerContext` に登録し、捕捉と既知項目の検証も生成経路に含める。
全 variant と入れ子の object の未知キーを捕捉し、境界で位置とキーを警告としてログに出し、値はログに載せない。
生成経路が捕捉や検証を実現できなければ、[nswag](./nswag.md) の生成器の設定と template を直し、同義 DTO で回避しない。
composition の Mapper は、生成 DTO の field をコンテキストの公開 application 入力構築へ渡し、ドメイン型を直接参照しない。

### 例
外部入力をドメインエンティティへ直接デシリアライズすると、未検証の値が内側へ入る。

```csharp
var user = JsonSerializer.Deserialize<User>(json);
```

`Generated.CreateUserCommand` は契約からの生成 DTO であり、`Users.CreateUserCommand.Create` はコンテキストの公開 application 入力構築で、内部の値オブジェクトの検証を所有する。
以下の composition の Mapper は、その公開入口へ写像し、ドメイン型へ直接到達しない。

```csharp
internal static class CreateUserMapper
{
    internal static Result<Users.CreateUserCommand, Users.CreateUserError> Map(
        Generated.CreateUserCommand input) =>
        Users.CreateUserCommand.Create(input.Email);
}
```

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、未知フィールドの残存と収縮は [evolution](../../principles/evolution/README.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
