# translation

## 概要
translation は、C# で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、C# の機構で満たす。
problem+json への写しの規律は [aspnet-core](./aspnet-core.md) が、共通の生成経路は [tools/build/typespec](../../tools/build/typespec.md) が定める。

## 境界で一度だけ parse してドメイン型へ移す

### 要求
HTTP などの公開入力と、worker が内部の durable queue から受ける payload は、生成した型と codec で受ける。
System.Text.Json の serializer と接続する場合は source generation と生成 converter を使い、公開契約の codec と別の検証経路を作らない。
JSON の字句解析は System.Text.Json の reader 等の BCL 機構を再利用し、grammar を独自実装しない。
生成 converter は明示的な走査状態と非公開の完成処理を用い、serializer の再帰や既定の深さ制限で契約値を狭めない。
wire の受入条件は [structure/contracts/layout](../../structure/contracts/layout.md) の「JSON の相互運用 profile」に従い、BCL の既定挙動だけで充足したとは扱わない。
生成型のプロパティ、外部名、必須性、不在、値の制約は共有の生成器の IR から導き、同じ意味の record を手書きで定義しない。
生成 DTO とコンテキストの application 入出力との写像は [structure/contracts/adapters](../../structure/contracts/adapters.md) に置き、コンテキストの入力構築から値オブジェクトの factory へ検証を集め、失敗は Result で表す。
検証を通った値だけを業務処理へ渡し、内側で同じ性質を再検証しない。
未知の追加フィールドは弾かず、生成 codec が受理値とは別の診断に位置とキーを記録し、境界でログに出す。
未知の追加フィールドの受容で、既知項目の検証を緩めない。
必須項目の欠落、契約が許さない null、既知項目の値の不正、判別子と payload の不一致は、生成 codec と構築で拒否し、既定値や空の値で補って業務処理へ渡さない。
未指定と null は [canonical](../../structure/contracts/canonical.md) の「値の不在」に対応させ、三状態を必要とする項目は存在状態を表す生成型と専用 converter で保持する。
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
BCL の字句解析へ生成 codec を接続し、捕捉と既知項目の検証も IR から生成する。serializer 統合には source generation と同じ codec へ接続する converter を使う。
全 variant と入れ子の object の未知キーを捕捉し、境界で位置とキーを警告としてログに出し、値はログに載せない。
生成能力の不足は共有の生成器の repository の profile・IR・C# emitter で直し、同義 DTO で回避しない。
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

## 生成した契約値の構築と所有権を守る

### 要求
distinct scalar は private storage を持つ readonly value type とし、alias は同じ生成型への参照として扱う。
通常の field 制約は所有する生成モデルの構築と decode で検証し、制約名だけを理由に別の値型を作らない。
判別付き直和と操作の各結果は、生成側が variant を閉じた sealed record 階層にし、variant 固有の payload を検証付き構築で保持する。
閉じた階層は [formation](./formation.md) の「不正な状態を構築できなくする」に従って標識し、生成器が出す consumer の診断設定でも TYPMOD021 を error として有効にする。
生成モデルは非公開 constructor と get-only property を持ち、local 構築と decode は受理値または位置・規則を持つ構造化した違反情報を返す。
契約上不正になる struct の default は識別可能にし、accessor から正常な primitive 値として返さず、モデル構築・encode・操作入口でも通さない。
default が契約上有効なら、初期化 flag を増やさない。
非 null の位置の null と、可変な入力 collection の別参照による検証後の変更を防ぐ。
既に不変な子は共有し、外部の可変 storage だけを完成時に切り離して、変更できない形で保持する。
decimal と日時の生成表現は、契約が指定した受理値域・同値性・精度・scale・offset を保存し、System.Decimal や DateTimeOffset の範囲を契約の上限としない。
深い値の全経路は [structure/contracts/generated](../../structure/contracts/generated.md) の「生成能力」に従い、record が合成する等価性・hash・文字列化も公開する場合は再帰に依存しない実装を生成する。

### 根拠
readonly value type は役割の型分離に参照型の allocation を要さないが、[struct の初期化](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/struct#struct-initialization-and-default-values)は constructor を経ない default を作れる。
get-only property と非公開の完成処理を組み合わせれば、public init・with・未検証の collection の共有で構築の保証を迂回させずに済む。

### 完了条件
役割の異なる scalar の代入が型検査で拒否され、alias の互換が保たれている。
local 構築と decode が同じ制約へ照合され、不正な default・null・元の collection の変更が受理済み値を壊さない。
三状態、decimal と日時の保持要件を満たし、生成先の既定型で表せない有効値も受理できる。
共通の wire profile と深さ・診断保持の検査が、[structure/tests/methods-contracts](../../structure/tests/methods-contracts.md) の「契約の意味と生成」へ接続されている。

### 禁止事項
公開 constructor・init・with、検証しない converter により契約値の検証を迂回すること。
IReadOnlyList という公開型の名前だけで、元の可変 collection との共有が安全だと扱うこと。
通常の構築・decode の違反を例外だけで返すこと。

### 行動
C# emitter に private storage、構築・decode の共通検証、default の検出、存在状態の converter と collection の所有処理を含める。
構築済み graph を public factory に戻して二度走査せず、検証と完成処理を共有する。
生成契約値は業務値と独立に所有し、contracts/adapters から application の公開入力構築へ写す。

## 生成した通信処理を既存の効果へ接続する

### 要求
型・構築・codec の assembly と、HttpClient を使う consumer transport および提供側 dispatch の実行機構を分離する。
純粋な構築と codec に Effect runtime を要求せず、通信操作は [connection](./connection.md) と [coordination](./coordination.md) の既存の Effect・Deadline・CancellationToken へ接続する。
生成 transport は [structure/contracts/generated](../../structure/contracts/generated.md) の「応答の分類」に従い、status と media type・識別情報を先に選び、対応する body の decode を完了してから結果を返す。
宣言した複数の成功と body のない結果を識別できる outcome にし、宣言した拒否は操作の想定内失敗として Failed に写す。
502・503・504 の中継由来の不一致と通信の不成立は通信の Failed、呼出しごとの上限超過は別の Failed、それ以外の契約不一致と要求組立の欠陥は Defected にする。
OperationCanceledException は coordination が定める token の帰属で分類し、取消を Canceled にし、受理と decode の完了後の結果を後着の取消で書き換えない。
提供側 handler・dispatch の生成 Interface は contracts 側で使い、手書き Adapter が独立した application Interface へ接続し、core は composition を含めて生成物を参照しない。

### 根拠
生成 transport が outcome と codec を所有すれば、利用側の Adapter に成功例外の補償や未 decode body の解釈を散らさず、Effect の既存の終了分類へ接続できる。
依存を assembly で分ければ、型と codec だけを使う側に HttpClient と通信実行機構を強制しない。

### 完了条件
純粋な生成型の依存 closure に通信 client と実行機構がなく、core の assembly から全生成 assembly への参照がない。
全ての宣言結果、契約不一致、通信・上限・取消が生成通信処理で分類され、利用側で schema の再解釈をしていない。
提供側 dispatch から手書き Adapter と独立した application Interface へ到達できる。

### 禁止事項
status の範囲だけで応答を分類し、複数の成功を一つの body 型へ潰すこと。
通信例外の一括捕捉で要求組立の欠陥や取消を Failed にすること。
生成 Interface を application に実装させること。

### 行動
生成 transport に接続先と HttpClient を注入し、codec と結果の判定を生成する。
実際の応答・本文途中切断・接続拒否・組立失敗・上限・取消の競合を inspection の検証へ接続する。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
互換の隔離と業務上の不明の扱いは [separation](../../principles/separation/compatibility-isolation.md) の「正本を互換から独立させる」に従う。
一時的な旧版対応の撤去は [messaging](../../concerns/messaging/event-contract-versioning.md) の「イベント契約を版で進化させ、寛容に読む」、保持する旧版の事実の解釈と意味を保つ保存形式の移行は [persistence](../../concerns/persistence/fact-preserving-migrations.md) の「保存済みの事実を意味と値を保って移行する」に従う。
