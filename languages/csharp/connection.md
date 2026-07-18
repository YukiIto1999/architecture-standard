# connection

## 概要
connection は、C# で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect.md) が定める効果システムを、C# の型と機構で満たす。
効果は `Effect<TRequirements, TFailure, TValue>` の遅延した値で表し、要求する依存を型に出し、境界でだけ実行する。
[separation](../../principles/separation.md) の依存の向きと [dependency](../../concerns/dependency.md) の単方向性に従う。

## 効果を Effect 型で組む

### 要求
副作用を伴う計算は、`Effect<TRequirements, TFailure, TValue>` で表す。
これは `Func<TRequirements, CancellationToken, ValueTask<EffectExit<TFailure, TValue>>>` を包む `readonly struct` とし、生成では実行しない。
`default(Effect<...>)` の構築は、companion の analyzer で検出する。
純粋な計算は Effect で包まず、純粋な関数のままにする。

### 根拠
struct が delegate を一つ包む値なので、組み立てても副作用は起きず、合成と再試行と差し替えができる。
ValueTask で同期と非同期を一つの型で扱い、割り当てを抑える。
三つの型引数で、要求する依存と想定内失敗と成功の値を型に出す。
純粋な計算を Effect で包むと、不要な delegate と ValueTask の語彙が核に侵入する。
`default(Effect<...>)` は `_run` が null のまま構築でき、型だけでは実行時の NullReferenceException を防げないので、companion の analyzer で構築を検出する。

### 完了条件
副作用を伴う計算が、`Effect<TRequirements, TFailure, TValue>` で表されている。
`Effect` が、生成では実行されない遅延した値である。
純粋な計算が、Effect で包まれていない。
`default(Effect<...>)` の構築が、companion の analyzer で検出されている。

### 禁止事項
副作用を伴う計算を、生成で実行する eager な形で書くこと。
純粋な計算を、Effect で包むこと。
default の Effect を構築し、`_run` が null の値を作ること。

### 行動
副作用を伴う計算を Effect で返し、Map と Bind で合成する。query 式を使う場合は Select と SelectMany を実装する。
delegate を外へ見せず、構築は静的な生成関数に限る。
`default(Effect<...>)` の構築を、companion の analyzer で検出する。

### 例
```csharp
// 生成で即実行され、合成も差し替えもできない
public async Task<Order> Place(PlaceOrderCommand command) { /* すぐ走る */ }

// 遅延した効果の値。実行は境界の runtime でだけ
public readonly struct Effect<TRequirements, TFailure, TValue>
    where TRequirements : IEffectRequirements
{
    private readonly Func<TRequirements, CancellationToken, ValueTask<EffectExit<TFailure, TValue>>> _run;
    internal Effect(Func<TRequirements, CancellationToken, ValueTask<EffectExit<TFailure, TValue>>> run) => _run = run;
    internal ValueTask<EffectExit<TFailure, TValue>> Run(TRequirements requirements, CancellationToken cancellationToken) => _run(requirements, cancellationToken);
}
```

## 効果の生成と combinator と資源を備える

### 要求
Effect の生成と合成は、静的な生成関数とインスタンスの combinator で行い、delegate を直に触らせない。
生成・合成・失敗変換・資源・依存提供のための combinator を備える。
query 式のため、`Select` を `Map` から、`SelectMany` を `Bind` と `Map` から与える。

### 根拠
生成関数が delegate を内に隠すので、利用側は `_run` を直に触らず Effect を作れる。
`Bind` は前段の成功値に依存して次の Effect を返す合成の核で、`Map` はその特例として導出できる。
`MapFailure` と `Recover` は Failed だけを変換し回復し、Defected と Canceled には触れない。
`AcquireRelease` は取得した資源を、成功・失敗・取り消しのいずれでもちょうど一度解放する。
`Provide` は要求する依存を与えて `TRequirements` を `NoRequirements` に畳み、実行できる形にする。

### 完了条件
生成が `Succeed`・`Fail`・`Defect`・`Try` で行われている。
合成が `Map`・`Bind`(query 式なら `Select`・`SelectMany`)で行われている。
資源の取得と解放が `AcquireRelease` で、成功・失敗・取り消しのいずれでも解放されている。
依存提供が `Provide` で行われている。

### 禁止事項
`Recover` で、Defected や Canceled まで回復すること。
資源の解放を、失敗や取り消しの経路で漏らすこと。

### 行動
生成・合成・失敗変換・資源・依存提供を、上記の combinator で組む。
`Recover` は Failed だけを扱い、Defected と Canceled を素通しする。

### 例
```csharp
// 生成と資源は静的な生成関数で。delegate を内に隠す
public static class Effect
{
    public static Effect<TRequirements, TFailure, TValue> Succeed<TRequirements, TFailure, TValue>(TValue value);
    public static Effect<TRequirements, TFailure, TValue> Fail<TRequirements, TFailure, TValue>(TFailure failure);
    public static Effect<TRequirements, TFailure, TValue> Defect<TRequirements, TFailure, TValue>(Exception defect);
    public static Effect<TRequirements, TFailure, TValue> Try<TRequirements, TFailure, TValue>(
        Func<TRequirements, CancellationToken, ValueTask<TValue>> body, Func<Exception, TFailure> onError);
    public static Effect<TRequirements, TFailure, TResult> AcquireRelease<TRequirements, TFailure, TResource, TResult>(
        Effect<TRequirements, TFailure, TResource> acquire,
        Func<TResource, ValueTask> release,                                       // 成功・失敗・取消で必ず一度
        Func<TResource, Effect<TRequirements, TFailure, TResult>> use);
}

// Effect<TRequirements, TFailure, TValue> のインスタンス combinator。シグネチャの一覧であり、実装は libs の Effect 機構が持ち、companion は検査と生成のみを行う
Effect<TRequirements, TFailure, TResult>  Map<TResult>(Func<TValue, TResult> selector);
Effect<TRequirements, TFailure, TResult>  Bind<TResult>(Func<TValue, Effect<TRequirements, TFailure, TResult>> bind);
Effect<TRequirements, TFailure2, TValue>  MapFailure<TFailure2>(Func<TFailure, TFailure2> selector);
Effect<TRequirements, TFailure, TValue>   Recover(Func<TFailure, Effect<TRequirements, TFailure, TValue>> handler);  // Failed のみ
Effect<NoRequirements, TFailure, TValue>  Provide(TRequirements requirements);
// query 式: Select = Map、SelectMany = Bind + Map
```

## 終了を成功と失敗と欠陥と取り消しに分ける

### 要求
Effect の終了は `EffectExit<TFailure, TValue>` の閉じた階層で表し、Succeeded・Failed・Defected・Canceled に分ける。
想定内失敗は TFailure の sealed record の階層で表し、欠陥と取り消しを TFailure に混ぜない。
純粋な計算の想定内失敗は、自作の閉じた `Result<TValue, TFailure>` で表し、TFailure には Effect と同じ sealed record の階層を使う。
Result の実装は、Effect と同じく libs の機構が持つ。

### 根拠
Result の二状態では、欠陥と取り消しを一つの型に分けて全域化できず、失敗に畳むか型の外へ逃がすことになる。
四つの終了に分けると、回復できる失敗と回復できない欠陥と取り消しを取り違えない。
TFailure を sealed record の階層にすると、網羅の switch で扱える。
外部ライブラリの `readonly struct` の Result は、`default` の構築を型で防げず、不正な状態の排除が崩れる。
自作の閉じた Result なら、TFailure の階層と `default` 検出の analyzer を Effect と共有できる。
外部依存の失敗は adapter で回復できる失敗と欠陥に分け、回復できる失敗を Failed に、欠陥を Defected にする。
EffectExit の基底も非 sealed な abstract record で、外部 assembly からの派生を型だけでは防げない限界と、その手当ては [formation](./formation.md) の閉じた階層の規律に従う。

### 完了条件
Effect の終了が、Succeeded・Failed・Defected・Canceled に分かれている。
想定内失敗が、TFailure の sealed record の階層で表されている。
純粋な計算の想定内失敗が、libs の機構の `Result<TValue, TFailure>` で表されている。
欠陥と取り消しが、TFailure に混ざっていない。

### 禁止事項
欠陥や取り消しを、TFailure に混ぜること。
想定内失敗を、例外で送出すること。
純粋な計算の失敗の表現に、外部ライブラリの Result 型を使うこと。

### 行動
終了を EffectExit の四状態に分け、TFailure を sealed record の階層にする。
外部依存の失敗を adapter で仕分け、回復できる失敗を Failed、欠陥を Defected にする。

### 例
```csharp
// すべての例外を失敗の型へ畳み込む。欠陥も取り消しも想定内失敗に化ける
try { return Result.Success<Order, OrderError>(Place(cart)); }
catch (Exception exception) { return Result.Failure<Order, OrderError>(OrderError.From(exception)); }

// 終了を四つに分ける閉じた階層
public abstract record EffectExit<TFailure, TValue>
{
    private EffectExit() { }
    public sealed record Succeeded(TValue Value) : EffectExit<TFailure, TValue>;
    public sealed record Failed(TFailure Failure) : EffectExit<TFailure, TValue>;
    public sealed record Defected(Exception Exception) : EffectExit<TFailure, TValue>;
    public sealed record Canceled : EffectExit<TFailure, TValue>;
}
```

## 要求する依存を型に出す

### 要求
Effect が要求する依存は、`IEffectRequirements` を継承した能力の interface で宣言し、計算ごとに必要な分だけを generic constraints で要求する。
依存の実装は composition root が runtime に与え、本番とテストで差し替える。
`Provide` で `TRequirements` を `NoRequirements` へ畳んだ後、原始効果(時刻・乱数・ID・I/O)を宣言済みの能力の実装と adapter の外で直接使わない。

### 根拠
能力の interface を generic constraints で要求すると、計算が何を要求するかが型に出て、不足が型検査に出る。
計算ごとに必要な能力だけを要求すると、全部入りの単一の環境にならない。
依存を名前で取り出す `GetService<T>` は型付きの service locator なので、要求が型に出ない。
本番とテストで requirements の実装を差し替えると、時刻と乱数と外部依存を制御できる。
`Provide` は要求を消したという型の主張を作るので、畳んだ後に原始効果を直接呼ぶと、要求が型に出ているという保証が実体を伴わない嘘になる。

### 完了条件
Effect が要求する依存が、能力の interface の generic constraints で型に出ている。
各計算が、必要な能力だけを要求している。
依存の実装が、composition root で与えられている。
`NoRequirements` へ畳んだ後の原始効果の直接呼び出しが、能力の実装と adapter の外に無い。

### 禁止事項
全部入りの単一の環境を作り、全ての計算に要求させること。
依存を `GetService<T>` で名前で取り出すこと。
`NoRequirements` へ畳み込んだ後、原始効果を直接呼び要求が無いという型の主張を裏切ること。

### 行動
能力を `IEffectRequirements` を継承した interface で宣言し、計算の `where` で必要な分だけ要求する。
本番とテストで requirements の実装を差し替える。

### 例
```csharp
public interface IEffectRequirements { }
public sealed record NoRequirements : IEffectRequirements;   // 要求なし。Provide で畳んだ先
public interface IRequireClock : IEffectRequirements { DateTimeOffset GetCurrentTime(); }
public interface IRequireOrders : IEffectRequirements { IOrderRepository Orders { get; } }

// 要求する能力だけを where で宣言する
public static Effect<TRequirements, PlaceOrderFailure, OrderId> PlaceOrder<TRequirements>(PlaceOrderCommand command)
    where TRequirements : IEffectRequirements, IRequireClock, IRequireOrders => /* ... */;

// composition root が、全能力を実装した requirements を組んで runtime に与える
public sealed class ProductionRequirements(IClock clock, IOrderRepository orders)
    : IEffectRequirements, IRequireClock, IRequireOrders
{
    public DateTimeOffset GetCurrentTime() => clock.UtcNow;
    public IOrderRepository Orders { get; } = orders;
}
// テストは同じ能力を別実装で差し替える。TestRequirements は固定時刻とインメモリの Orders を持つ
```

## 効果を境界で実行し companion で縛る

### 要求
Effect の実行は `EffectRuntime<TRequirements>` の境界に限り、内側の層では実行しない。
EffectRuntime は requirements を保持し、Effect を解釈して `EffectExit` を返す。
実行中に送出された OperationCanceledException を Canceled に、その他の例外を Defected に写し、想定内失敗は throw せず Fail で返す。
型で縛れない規則は、companion(analyzer と source generator)が次の4責務で強制する: R の合成環境の生成、Bind 連鎖での要求包含の検査、原始効果の閉じ込め、`NoRequirements` への迂回の禁止。

### 根拠
実行を境界に集めると、どこで副作用が起きるかが一箇所で読める。
host の async と取り消しで Effect を駆動し、送出された取り消しと欠陥を終了状態に写すので、内側は throw でなく Fail で想定内失敗を返せる。
C# は型推論が弱く、実行境界の限定と要求の充足と原始効果の直呼びの禁止を、型だけでは縛れない。
要求する能力の組み合わせごとに環境型を手で書くと、組み合わせの数だけ nominal な型か神環境型のどちらかに倒れるので、companion が組み合わせから環境型を生成する(R の合成)。
Bind の連鎖は C# の型推論だけでは呼び元の R が呼び先の R を包含することを保証しないので、companion が連鎖を検査する(伝播の検査)。
時刻・乱数・ID・I/O のような原始効果を宣言済みの能力の外で直接呼べると、要求が型に出ているという保証が崩れるので、companion が能力の実装と adapter の外での直呼びを検出する(原始効果の閉じ込め)。
`NoRequirements` への畳み込みの後に原始効果を直接使う経路は、要求を消したという型の主張を裏切る迂回なので、companion がこれを検出する(迂回の禁止)。

### 完了条件
Effect の実行が、composition root の境界に限られている。
OperationCanceledException が Canceled に、その他の例外が Defected に写されている。
実行境界の限定と要求の充足が、companion の analyzer で検査されている。
R の合成環境が、companion の生成で作られている。
Bind の連鎖の要求包含が、companion の検査を通っている。
原始効果の直接呼び出しが、宣言済みの能力の実装と adapter の外に無いことが、companion で検査されている。
`NoRequirements` への迂回が、companion で検出されている。

### 禁止事項
内側の層で、Effect を実行すること。
`DateTimeOffset.UtcNow` のような原始効果を、純粋核や application で直に呼ぶこと。
companion の4責務のいずれかを、実装せず素通りさせること。

### 行動
Effect の実行を composition root の `EffectRuntime.Run` に集める。
companion に、R の合成・Bind 連鎖の検査・原始効果の閉じ込め・`NoRequirements` への迂回の検出の4つを実装する。

### 例
```csharp
// runtime は requirements を保持し、解釈して終了状態を返す。例外を Canceled と Defected に写す
public sealed class EffectRuntime<TRequirements>(TRequirements requirements)
    where TRequirements : IEffectRequirements
{
    public async ValueTask<EffectExit<TFailure, TValue>> Run<TFailure, TValue>(
        Effect<TRequirements, TFailure, TValue> effect, CancellationToken cancellationToken)
    {
        try { return await effect.Run(requirements, cancellationToken); }
        catch (OperationCanceledException) { return new EffectExit<TFailure, TValue>.Canceled(); }
        catch (Exception exception) { return new EffectExit<TFailure, TValue>.Defected(exception); }
    }
}

// 境界で runtime に与えて実行する
var runtime = new EffectRuntime<ProductionRequirements>(requirements);
EffectExit<PlaceOrderFailure, OrderId> exit = await runtime.Run(PlaceOrder<ProductionRequirements>(command), cancellationToken);
```

## port を interface で宣言する

### 要求
adapter が実装する port は interface で宣言し、業務の核は interface だけに依存する。
能力として型に出す依存は requirements で、adapter の組み立てる依存は constructor で受け取る。

### 根拠
interface は技術に依存しない契約で、核はそれだけに依存すれば実装から切れる。
効果が要求する能力は requirements で型に出し、adapter どうしの組み立ては constructor で配線すると、両者の役割が分かれる。

### 完了条件
port が、interface で宣言されている。
業務の核が、interface だけに依存している。
能力が requirements で、adapter の組み立てる依存が constructor で受け取られている。

### 禁止事項
業務の核で、具象の実装を直接生成すること。

### 行動
port を interface で宣言し、adapter の依存を constructor の引数で受ける。

### 例
```csharp
// 核が具象を直接生成する
public sealed class OrderService { private readonly SmtpNotifier _notifier = new(); }

// port は interface、adapter の依存は constructor で受ける
public sealed class SmtpNotifier(ISmtpClient client) : INotifier;
```

## 配線を composition root に限る

### 要求
adapter の登録と requirements の組み立ては composition root に限り、`Program.cs` で行う。
実行時に `IServiceProvider` から依存を引く service locator を使わない。

### 根拠
組み立てを composition root の一点に集めれば、どの具象が使われるかが一箇所で見渡せる。
composition root が、本番の requirements を組み立てて runtime に与え、効果の実行を境界に置く。
`IServiceProvider` からその場で引くのは service locator で、依存をシグネチャから隠す。

### 完了条件
adapter の登録と requirements の組み立てが、composition root に限られている。
`IServiceProvider` から依存を引く service locator を使っていない。

### 禁止事項
実行時に、`IServiceProvider` から依存を引くこと。

### 行動
adapter の登録と requirements の組み立てを `Program.cs` に集め、runtime に requirements を与える。

### 例
```csharp
// 実行時に provider から引く service locator
var validator = _provider.GetService<IOrderValidator>();

// composition root で requirements を組み、runtime に与える
var requirements = new ProductionRequirements(new SystemClock(), orderRepository);
var runtime = new EffectRuntime<ProductionRequirements>(requirements);   // Program.cs
```

## 参照
効果システムは [effect](../../concerns/effect.md)、依存の向きは [dependency](../../concerns/dependency.md)、判別共用体の宣言は [formation](./formation.md) に従う。
取り消しは [coordination](./coordination.md)、資源は [retention](./retention.md)、組立点の構造は [structure/core/application](../../structure/core/application.md) に従う。
