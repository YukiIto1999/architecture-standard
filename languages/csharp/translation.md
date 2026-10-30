# translation

## 概要
translation は、C# で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、C# の機構で満たす。
problem+json への写しの規律は [aspnet-core](./aspnet-core.md) が、契約生成と drift 検査と、生成 client の応答の分類の規律は [nswag](./nswag.md) が持つ。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
HTTP などの公開入力と、worker が内部の durable queue から受ける payload は、生成 DTO で受け、source generation の `JsonSerializerContext` を通す。
生成 DTO のプロパティ、外部名、必須性、不在、値の制約を canonical と binding から導き、同じ意味の record を手書きで定義しない。
生成 DTO とコンテキストの application 入出力との写像は [structure/contracts/adapters](../../structure/contracts/adapters.md) に置き、コンテキストの入力構築から値オブジェクトの factory へ検証を集め、失敗は Result で表す。
検証を通った値だけを業務処理へ渡し、内側で同じ性質を再検証しない。
未知の追加フィールドは弾かず、生成した `[JsonExtensionData]` の捕捉と serializer の処理で位置とキーを記録し、境界でログに出す。
未知の追加フィールドの受容で、既知項目の検証を緩めない。
必須項目の欠落、契約が許さない null、既知項目の値の不正、判別子と payload の不一致は、既定値や空の値で補って業務処理へ渡さず、生成 DTO の `required` と生成した converter により拒否する。
未指定と null は [canonical](../../structure/contracts/canonical.md) の「値の不在」に対応させ、契約上必要な区別を生成 DTO と converter で失わない。
この拒否と業務処理の非開始は、宣言の存在から推定せず、公開入力では endpoint が実際に受ける経路、内部の durable queue では [wolverine](./wolverine.md) が定める実際の受信経路へ入力を渡して確かめる。
業務上の真の不明は、その意味と許す操作を正本のモデルで定めた型で表し、技術互換のための不要な任意化と区別する。
旧版や送り手の都合で生じる不足は、現在の契約の必須項目や業務型の任意化でも、写像の既定値や架空の値でも隠さない。
旧版を一時的に受ける間は、旧版の契約から生成した DTO から現在の application 入力への変換を contracts/adapters の写像に置き、内側へは現在の検証済みの入力だけを渡す。
保持の契約が旧版の事実を必要とする間は、保存行を書き換えず、読み出しの境界の変換で現在の型へ写す。
変換は、保存や送信で存在しなかった事実を作らず、必要な保証を満たせない入力を拒否する。
外部表現の命名や形式は生成 DTO と binding 側に置き、ドメイン型を直接直列化しない。

### 根拠
ドメインのエンティティに直接デシリアライズすると、検証を経ない値がそのまま内部へ入る。
生成 DTO の契約の検証と、契約 adapter から application の入力構築を通す業務型の検証を分ければ、それぞれの保証を所有者の一点に集められる。
source generation は実行時のリフレクションを避け、契約を明示する。
未知のフィールドを弾く既定は送り手と受け手の配備が一時的に重なるときの互換を壊すので、未知の追加フィールドは受容する。
未知の追加の受容と既知項目の保証は別の問いである。
必須項目の欠落や不正な null を既定値で受けると、存在しない事実を持つ入力が業務処理へ入り、拒否すべき入力が正常な結果に見える。
不足を任意化で隠すと、真に不明な事実と、送り手や旧版の都合で欠けた事実を、後から区別できない。
旧版の変換を境界に置けば、内側の型は現在の保証を保ち、旧版の分岐が内側へ広がらない。
検知した未知のフィールドをログに出せば、送り手と受け手の契約の差を追える。
未知のフィールドが恒常的に届くことは、それだけでは旧方式が残っている証拠にならない。
一時的な旧版対応を撤去できるかは、未知のフィールドの到着でなく、旧版の発行と再投入の停止と未完了の旧版の不在で決まる。
保持の契約が旧版の事実を必要とする間の変換は、撤去すべき互換の残存でなく、保持された事実の解釈である。
ドメイン型を直接直列化すると、外部表現の都合がドメインの形を縛る。

### 完了条件
公開契約の入力が、HTTP などの公開入力でも内部の durable queue の payload でも、canonical と binding から生成した具体的な DTO で受けられている。
contracts/adapters の写像からコンテキストの入力構築と値オブジェクトの factory へ検証が集まり、失敗が Result で表されている。
未知フィールドの位置とキーが全 variant と入れ子の object で捕捉され、境界のログへ届いている。
捕捉した値が domain や応答へ流れていない。
未知の追加フィールドを加えても、必須項目の欠落と既知項目の不正の拒否が失われていない。
必須項目の欠落、契約が許さない null、値の制約違反、判別子と payload の不一致が、既定値で補われず、実際の受信経路で拒否され、業務処理が始まっていない。
業務上の真の不明が正本のモデルで定めた不在として表され、旧版や送り手の都合による不足が、任意化や既定値で隠されていない。
旧版を受ける互換の変換が contracts/adapters の写像に閉じ、保持する旧版の事実の変換が読み出しの境界に閉じ、内側が現在の検証済みの型だけを受けている。
保持する旧版の事実の変換で保存行が書き換えられず、保存や送信で存在しなかった事実が作られていない。
ドメイン型が、直接直列化されていない。

### 禁止事項
ドメインのエンティティに、直接デシリアライズすること。
境界を通った値を、内側で再び検証すること。
未知のフィールドを、既定で弾くこと。
未知のフィールドの検知を、ログに出さず握りつぶすこと。
生成 DTO の不足を、同じ意味の手書き DTO や生成物の手修正で補うこと。
必須項目の欠落や契約が許さない null を、既定値や空の値で補って業務処理へ渡すこと。
未知の追加フィールドの受容を理由に、既知項目の検証を緩めること。
旧版や送り手の都合のために、現在の契約の必須項目や業務型を任意にして不足を隠すこと。
変換で、保存や送信で存在しなかった事実を作ること。
未知のフィールドが恒常的に届くことだけを、旧方式が残っている証拠として扱うこと。

### 行動
生成 DTO を `JsonSerializerContext` に登録し、捕捉と既知項目の検証も生成経路に含める。
全 variant と入れ子の object の未知キーを捕捉し、境界で位置とキーを警告としてログに出し、値はログに載せない。
生成経路が捕捉や検証を実現できなければ、[nswag](./nswag.md) の生成器の設定と template を直し、同義 DTO で回避しない。
contracts/adapters の Mapper は、生成 DTO の field を core が公開する application 入力構築へ渡し、ドメイン型を直接参照しない。
必須項目の欠落、契約が許さない null、既知項目の不正、判別子の不一致の入力と、未知の追加フィールドだけを加えた入力を、endpoint と内部の durable queue の実際の受信経路へ別々に渡し、前者の拒否と業務処理の非開始、後者の受容を観測する。
不足を項目ごとに、真の業務上の不明か、旧版や送り手の都合かに分け、後者は任意化や既定値でなく、互換を宣言した境界の変換か拒否で扱う。
旧版を受ける互換の変換は contracts/adapters の写像へ、保持する旧版の事実の変換は読み出しの境界へ集め、内側の型へ旧版の項目や分岐を足さない。

### 例
外部入力をドメインエンティティへ直接デシリアライズすると、未検証の値が内側へ入る。

```csharp
var user = JsonSerializer.Deserialize<User>(json);
```

`Generated.CreateUserCommand` は契約からの生成 DTO であり、`Users.CreateUserCommand.Create` はコンテキストの公開 application 入力構築で、内部の値オブジェクトの検証を所有する。
以下の contracts/adapters の Mapper は、その公開入力構築へ写像し、ドメイン型へ直接到達しない。

```csharp
internal static class CreateUserMapper
{
    internal static Result<Users.CreateUserCommand, Users.CreateUserError> Map(
        Generated.CreateUserCommand input) =>
        Users.CreateUserCommand.Create(input.Email);
}
```

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
互換の隔離と業務上の不明の扱いは [separation](../../principles/separation/compatibility-isolation.md) の「正本を互換から独立させる」に従う。
一時的な旧版対応の撤去は [messaging](../../concerns/messaging/event-contract-versioning.md) の「イベント契約を版で進化させ、寛容に読む」、保持する旧版の事実の解釈は [persistence](../../concerns/persistence/read-time-upcasting.md) の「追記した事実の版を読み出しで現在へ変換する」に従う。
