# formation

## 概要
formation は、C# で値・型・不変条件をモデリングする実現軸である。
principles の [modeling](../../principles/modeling.md) が定める業務意味の型封入と、concerns の [types](../../concerns/types.md) が定める型の規律を、C# の機構で満たす。

## 業務の値を型に封じる

### 要求
業務の値は record で表し、constructor を非公開にして検証付きの static の factory に構築を一点化する。
引数なしの構築を塞ぎ、検証を経ない既定値を作れないようにする。
不変条件を完全に守る値オブジェクトは record class にする。readonly record struct は引数なしの構築を隠せず既定値を作れてしまうため、不変条件を守る値には使わない。

### 根拠
record は値の等価と非破壊的変更と不変の既定を備え、値オブジェクトの土台になる。
公開の constructor を残すと、検証を経ない値オブジェクトを直接生成できてしまう。
constructor を非公開にし検証付きの factory だけを公開すれば、その型の値を持つこと自体が検証済みの証になる。
struct は引数なしの構築を隠せないので、塞がないと既定値で不正な値が生まれる。

### 完了条件
業務の値が、record で表されている。
constructor が非公開で、構築が検証付きの static factory に限られている。
引数なしの構築が塞がれ、検証を通らない値を作れない。

### 禁止事項
公開の constructor を残し、検証を経ない値オブジェクトを生成できる形にすること。
業務の値を、プリミティブのまま渡し回すこと。

### 行動
プリミティブで渡している業務概念を record にし、非公開の constructor と検証付きの static `Create` に構築を集める。
`Create` は検証の成否を Result で返し、不正なら成功を返さない。

### 例
```csharp
// 公開 ctor で、検証を経ない値オブジェクトを直接生成できる
public record Address(string Street, string ZipCode);

// 非公開 ctor と検証付き factory に一点化する
public sealed record Address
{
    public string Street { get; init; }
    public string ZipCode { get; init; }
    private Address(string street, string zipCode) => (Street, ZipCode) = (street, zipCode);
    public static Result<Address> Create(string street, string zipCode) =>
        IsValidZip(zipCode) ? Result.Success(new Address(street, zipCode)) : Result.Failure<Address>("zip");
}
```

## 不正な状態を構築できなくする

### 要求
場合分けのある概念は、外部の派生を封じた sealed record の階層で表す。
基底の constructor を非公開にして、バリアントをネストした sealed record に限る。
分岐は switch 式で網羅し、default のアームも discard のアームも置かない。
閉じた階層を認識して CS8509 を抑止する diagnostic suppressor を入れ、網羅の検査を保ったまま default と discard を不要にする。
網羅の警告をエラー扱いにし、バリアントの追加で漏れをビルドの失敗にする。
不在は nullable reference types を有効にして、型の上の nullable で表す。
階層の外からの派生は、ArchUnitNET の構造検査で検出する。

### 根拠
abstract record の基底と非公開の constructor は、バリアントの集合を内部に閉じ、外から増えないようにする。
C# のコンパイラは閉じた階層を網羅とみなさず、全バリアントを書いた switch にも CS8509 を出し、未知の派生と null を理由に discard のアームを求める。
discard のアームを置くと、バリアントを追加しても未処理が警告されず、網羅の検査が効かなくなる。
閉じた階層を認識する diagnostic suppressor は、全バリアントを処理した switch の CS8509 だけを抑止し、バリアントを追加して未処理が出たときの警告は残す。
これで discard を置かずに網羅を検査でき、警告をエラー扱いにすればバリアントの漏れでビルドが落ちる。
default や discard のアームで例外を投げる形は、漏れを実行時まで遅らせる。
nullable reference types は、不在を型に現し、null の取り違えを型検査で防ぐ。
record は、通常の constructor を private にしても外部 assembly からの派生を型だけでは防げない。
非 sealed な record が explicit な copy constructor を宣言する場合、その accessibility は protected でなければならず、private や private protected は CS8875 で拒否される。
このためコンパイラが合成する copy constructor は常に protected になり、他の assembly の派生型がそれを `base(original)` で呼べば、閉じたはずの階層の外に新しいバリアントを作れてしまう。
この経路は型では塞げないので、階層の外にある派生型の有無を ArchUnitNET の構造検査で検出し、CI で気づけるようにする。

### 完了条件
場合分けが、外部の派生を封じた sealed record の階層で表されている。
網羅の switch に、default のアームも discard のアームも無い。
閉じた階層の CS8509 を抑止する suppressor が入り、網羅の警告がエラー扱いで、バリアントの追加がビルドで気づける。
不在が、型の上の nullable で表されている。
階層の外からの派生が、構造検査で検出されている。

### 禁止事項
場合分けの基底に、外部から派生できる余地を残すこと。
網羅の switch に default のアームや discard のアームを置き、バリアントの漏れの検査を失わせること。
protected な copy constructor を経由した階層の外からの派生の防止を、型だけで実現できると称すること。

### 行動
基底を abstract record にして constructor を非公開にし、バリアントをネストした sealed record で宣言して `required` で初期化を強制する。
閉じた階層を認識する diagnostic suppressor を入れ、switch 式を default も discard も無しで書き、CS8509 を含む網羅の警告をエラー扱いに設定する。
階層の外からの派生の有無を、ArchUnitNET の構造検査で確かめる。

### 例
```csharp
// discard アームで実行時に投げる。バリアントの追加を忘れても実行時まで気づけない
var label = account switch { Account.Iban iban => iban.Value, _ => throw new ArgumentOutOfRangeException() };

// 派生を内部に閉じ、default も discard も無い網羅 switch
public abstract record Account
{
    private Account() { }
    public sealed record Iban(string Value) : Account;
    public sealed record Swift(string Value) : Account;
}
// suppressor が閉じた階層の CS8509 を抑止する。バリアントを足すと未処理が警告される
var label = account switch { Account.Iban iban => iban.Value, Account.Swift swift => swift.Value };
```

## 継承を判別共用体に限る

### 要求
継承は、判別共用体の宣言にだけ使う。
振る舞いの再利用や Template Method のために、abstract や継承を使わない。
判別共用体の基底でない型は、sealed にする。
振る舞いの共有は、継承でなく合成と委譲で得る。

### 根拠
C# の継承は、abstract record の基底と sealed なバリアントで判別共用体を宣言する手段として要る。
振る舞いの再利用のための継承は、基底と派生を密に結び、基底の変更が全派生へ波及する。
Template Method で派生に隙間を残すと、型の集合が外から開き、不正な状態の構築を許す。
継承しない型を sealed にすると、想定しない派生を型で禁じ、型の集合が閉じたままになる。
振る舞いを合成と委譲で組めば、各部品が独立して差し替えられ、結合が緩い。

### 完了条件
継承が、判別共用体の宣言にだけ使われている。
判別共用体の基底でない型が、sealed である。
振る舞いの共有が、合成と委譲で実現されている。

### 禁止事項
振る舞いの再利用や Template Method のために、abstract や継承を使うこと。
判別共用体の基底でない型を、sealed にせず派生の余地を残すこと。

### 行動
継承を、abstract record の基底と sealed なバリアントによる判別共用体の宣言にだけ使う。
判別共用体の基底でない型を、sealed で宣言する。
共有したい振る舞いは、型を部品として持ち、委譲で呼ぶ。

### 例
```csharp
// 振る舞いの再利用のための継承。基底の変更が全派生へ波及する
public abstract class ReportBase { protected abstract void Render(); public void Run() => Render(); }

// 継承は判別共用体に限り、振る舞いは合成で持つ。型は sealed
public sealed class MonthlyReport(IReportRenderer renderer) { public void Run() => renderer.Render(); }
```

## 不変を既定にする

### 要求
値・イベントに setter を持たせず、初期化は init に限る。
変更は with 式で新しい値を作る形で表し、値オブジェクトの変更は検証付きの factory を通して不変条件を迂回しない。

### 根拠
init と record の値の既定は、構築の後の変更を塞ぐ。
with 式は元を複製して指定したプロパティだけ変えた新しい値を作り、元を不変に保つ。
ただし with 式は浅い複製で検証を経ないので、値オブジェクトで無条件に許すと不変条件を迂回する抜け道になる。

### 完了条件
値・イベントに、setter がない。
変更が、with 式または検証付きの factory による新しい値の生成で表されている。
値オブジェクトの変更が、不変条件の検証を経ている。

### 禁止事項
値・イベントに setter を持たせること。
値オブジェクトの不変条件を、with 式で迂回すること。

### 行動
プロパティを init に限り、単純な値の変更は with 式で、不変条件のある値オブジェクトの変更は検証付きの factory で新しい値を作る。

### 例
```csharp
// with は浅い複製で検証を経ない。値オブジェクトの不変条件を迂回しうる
var moved = address with { ZipCode = "00000" };

// 値オブジェクトの変更は検証付き factory を通す
Result<Address> moved = address.WithZipCode("00000"); // 内部で Create を呼び検証する
```

## 意味と単位を型で区別する

### 要求
意味や単位が異なる値は、構造が同じでも別の値オブジェクトで区別する。

### 根拠
`decimal` や `string` を直に回すと、重さと金額のような別の概念が同じ型になり、取り違えても気づけない。
別の record にすれば、コンパイラが取り違えを拒否する。

### 完了条件
意味や単位が異なる値が、別の値オブジェクトで区別されている。
取り違えが、コンパイルエラーになる。

### 禁止事項
意味や単位の異なる値を、同じプリミティブで扱うこと。

### 行動
単位ごと・識別子ごとに値オブジェクトを分ける。
等価の比較は record が持つプロパティ単位の値等価で足り、別の基底を持ち出さない。

### 例
```csharp
// 重さと金額が同じ decimal。取り違えても気づけない
decimal weight; decimal price;
// 別の値オブジェクトに分け、取り違えをコンパイルで弾く
public sealed record Weight { /* Create で検証 */ }
public sealed record Money { /* Create で検証 */ }
```

## 命名と整形を道具に委ねる

### 要求
命名と整形は .NET の命名規約と CSharpier の既定に従い、手で揃えない。
ファイル名は、そのファイルの変更単位の型の名前に PascalCase で一致させる。

### 根拠
整形を手で揃えると、差分に無意味な変更が混じり、規約の揺れがレビューの対象になる。
道具に委ねれば表記が一意に決まり、議論を設計に集中できる。
CSharpier は設定項目が少ない opinionated な formatter で、.editorconfig の書き方に出力が左右されない。
ファイル名を変更単位の型に PascalCase で一致させると、型を名前で探すときにファイルが一意に定まる。

### 完了条件
命名が、.NET の命名規約に従っている。
ファイル名が、変更単位の型の名前に PascalCase で一致している。
整形が、CSharpier の既定で一意に決まっている。

### 禁止事項
整形を、手で揃えること。
ファイル名を、変更単位の型と違う名前や、kebab-case などの別の表記にすること。

### 行動
.NET の命名規約に従い、CSharpier を既定の設定で適用する。
ファイル名を、変更単位の型の PascalCase の名前に一致させる。

## 契約をドキュメントコメントに書く

### 要求
宣言した型とメンバに XML ドキュメントコメントを付ける。
対象が持つ param・typeparam・returns・value・exception を省かない。
想定された失敗は returns の Result の型に現し、exception は欠陥に限る。
summary の最初の一行と文体の規律は [comment](../../principles/comment.md) に従う。

### 根拠
XML ドキュメントコメントは、利用者が実装を読まずに、IntelliSense と生成文書から用途と契約を読めるようにする。
param は、コンパイラが引数との対応を検証し、記述漏れを警告する。
exception は、戻り値に現れない欠陥としての送出を宣言し、想定された失敗は returns の Result の型に現す。
summary の最初の一行と文体の理由は [comment](../../principles/comment.md) に従う。

### 完了条件
宣言した型とメンバに、用途と契約を述べる XML ドキュメントコメントがある。
対象が持つ param・typeparam・returns・value・exception が、網羅されている。
summary の最初の一行と文体が、[comment](../../principles/comment.md) の完了条件を満たしている。

### 禁止事項
宣言した型やメンバの契約を、未記述で放置すること。
対象が持つ param・typeparam・returns・value・exception を、省くこと。

### 行動
宣言ごとに目的の summary を一行で書き、引数・型引数・戻り値・プロパティ値・送出する例外のうち該当するものをすべて記す。
summary の最初の一行と文体は [comment](../../principles/comment.md) に従って書く。

### 例
```csharp
/// <summary>検証済みカートの確定と在庫引当</summary>
/// <param name="cart">確定対象の検証済みカート</param>
/// <returns>確定済みの注文または在庫不足の失敗</returns>
/// <exception cref="InvalidOperationException">保存済みの注文が不変条件に違反している</exception>
public Result<Order, OrderError> Place(ValidCart cart) { /* ... */ }
```

## companion をビルド時のツールとして分ける

### 要求
値オブジェクトの生成、閉じた階層の網羅の suppressor、効果の規律の analyzer は、core と別の netstandard2.0 のプロジェクトに置く。
このプロジェクトは `OutputItemType="Analyzer"` と `ReferenceOutputAssembly="false"` で参照し、実行時の依存にしない。

### 根拠
analyzer と source generator はコンパイラが読み込むビルド時のツールで、実行時には存在せず出荷物に含まれない。
Roslyn はこれらに netstandard2.0 を課し、生成器は自身を含むアセンブリのビルドに使えないので、core と同じプロジェクトには置けない。
`ReferenceOutputAssembly="false"` は、ツールの dll を実行時の参照に混ぜないために要る。

### 完了条件
生成器と suppressor と analyzer が、core と別の netstandard2.0 プロジェクトにある。
これらが `OutputItemType="Analyzer"` で参照され、実行時の依存に現れない。

### 禁止事項
生成器や analyzer を、実行時のプロジェクトや core の層・submodule に置くこと。
ツールの dll を、実行時の参照に含めること。

### 行動
companion を別の netstandard2.0 プロジェクトにし、各プロジェクトから `OutputItemType="Analyzer"`・`ReferenceOutputAssembly="false"` で参照する。
配布するときは `analyzers/dotnet/cs` に詰め、`IncludeBuildOutput=false` で実行時の出力に含めない。

## 参照
業務意味の型封入は [modeling](../../principles/modeling.md)、型の規律は [types](../../concerns/types.md)、合成と継承の境界は [separation](../../principles/separation.md)、ドキュメントコメントは [comment](../../principles/comment.md)、置き場は [structure/core/domain](../../structure/core/domain.md)、companion の境界は [structure/skeleton](../../structure/skeleton.md) に従う。
エラーモデルと結果の型は [connection](./connection.md)、境界での外部表現の変換は [translation](./translation.md) に従う。
