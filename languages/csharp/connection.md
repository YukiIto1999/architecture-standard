# connection

## 概要
connection は、C# で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect/README.md) が定める効果システムを、C# の型と機構で満たす。
効果は `Effect<TRequirements, TFailure, TValue>` の遅延した値で表し、要求する依存を型に出し、境界でだけ実行する。
[separation](../../principles/separation/README.md) の依存の向きと [dependency](../../concerns/dependency/inward-dependencies.md) の「依存を内側へ一方向に向ける」の規律に従う。

## 効果を Effect 型で組む

### 要求
副作用を伴う計算は、`Effect<TRequirements, TFailure, TValue>` で表す。
これは `Func<TRequirements, Deadline, CancellationToken, ValueTask<EffectExit<TFailure, TValue>>>` を包む `readonly struct` とし、生成では実行しない。
内部の Run は ValueTask を返し、公開 host API の Task と役割を混ぜない。
Roslyn analyzer の EFFSYS008 で、明示的な default に加え、Effect の未初期化配列・field、同一 compilation で追跡できる generic producer による未初期化値の生成を拒否する。
Run は `_run` が null なら `UninitializedEffectException` を送出し、未初期化の Effect を専用の defect として閉じる。
純粋な計算は Effect で包まず、純粋な関数のままにする。

### 根拠
struct が delegate を一つ包む値なので、組み立てても副作用は起きず、合成と再試行と差し替えができる。
ValueTask で同期と非同期を一つの型で扱い、割り当てを抑える。
三つの型引数で、要求する依存と想定内失敗と成功の値を型に出す。
純粋な計算を Effect で包むと、不要な delegate と ValueTask の語彙が核に侵入する。
明示的な default と型解決できる default は、Roslyn analyzer で利用前に止められる。
別 assembly の metadata だけを参照する generic producer の内部までは consumer の analyzer で追跡できないため、静的拒否だけで未初期化値の到達を排除しない。
Run が null delegate を呼ぶ前に専用の defect を送出すれば、静的検査を抜けた default を通常の NullReferenceException と取り違えない。

### 完了条件
副作用を伴う計算が、`Effect<TRequirements, TFailure, TValue>` で表されている。
`Effect` が、生成では実行されない遅延した値である。
純粋な計算が、Effect で包まれていない。
内部の Run が、Deadline と CancellationToken を受け取り ValueTask を返している。
EFFSYS008 が、明示的な default と、未初期化配列・field・同一 compilation の generic producer の検出対象を拒否している。
Run が `_run` の null を実行前に検出し、`UninitializedEffectException` を送出している。
metadata-only の外部 producer から到達した default Effect が、runtime で Defected の `UninitializedEffectException` になることが実行テストで確認されている。

### 禁止事項
副作用を伴う計算を、生成で実行する eager な形で書くこと。
純粋な計算を、Effect で包むこと。
default の Effect を構築し、`_run` が null の値を作ること。
全ての default Effect を、analyzer だけで検出できるとみなすこと。
Run の未初期化 guard を外し、null delegate の呼出しを通常の NullReferenceException にすること。
Effect の内部の Run から、Task または Task<T> を返すこと。

### 行動
副作用を伴う計算を Effect で返し、Map と Bind で合成する。
query 式を使う場合は Select と SelectMany を実装する。
delegate を外へ見せず、構築は文脈の値の生成関数に限る。
未初期化値の静的拒否を EFFSYS008 で検査し、配列や同一 compilation の generic producer を検査の盲点として扱わない。
Run の先頭で `_run` の null を検出し、`UninitializedEffectException` を送出する。
source を consumer の compilation に含めない外部 producer を使い、runtime の未初期化 guard を専用の consumer で確かめる。

### 例
公開 host API で `Task<T>` を生成するとその場で実行が始まり、効果を合成したり差し替えたりできない。

```csharp
public Task<Order> Place(PlaceOrderCommand command) => placeOrderHandler.HandleAsync(command);
```

効果は遅延した値で表し、境界の runtime でだけ実行する。

```csharp
internal sealed class UninitializedEffectException : Exception
{
    internal UninitializedEffectException() : base("未初期化の Effect") { }
}

public readonly struct Effect<TRequirements, TFailure, TValue>
    where TRequirements : IEffectRequirements
{
    private readonly Func<TRequirements, Deadline, CancellationToken, ValueTask<EffectExit<TFailure, TValue>>>? _run;
    internal Effect(Func<TRequirements, Deadline, CancellationToken, ValueTask<EffectExit<TFailure, TValue>>> run) => _run = run;

    internal ValueTask<EffectExit<TFailure, TValue>> Run(
        TRequirements requirements,
        Deadline deadline,
        CancellationToken cancellationToken)
    {
        var run = _run;
        if (run is null) throw new UninitializedEffectException();
        return run(requirements, deadline, cancellationToken);
    }
}
```

## 効果の生成と combinator と資源を備える

### 要求
Effect の生成は、文脈(`TRequirements` と `TFailure`)を型引数2つの値へ一度だけ束ねた `EffectContext` の生成関数で行う。
`Succeed<TValue>` と `Try<TValue>` は、値または delegate の戻り値から `TValue` を推論させる。
`Fail<TValue>` と `Defect<TValue>` は、引数に `TValue` が現れないため、呼び出し側で値型の型引数を明示する。
合成は拡張 method の combinator で行い、delegate を直に触らせない。
生成・合成・失敗変換・資源・依存提供のための combinator を備える。
query 式のため、`Select` を `Map` から、`SelectMany` を `Bind` と `Map` から与える。
`Try` の body は TRequirements、Deadline、CancellationToken をこの順に受け取って ValueTask<TValue> を返し、`AcquireRelease` の release は資源と Deadline を受け取って ValueTask を返す。
`AcquireRelease` の release は非取消の後始末であり、元の Deadline は受け取るが CancellationToken は受け取らない。
AcquireRelease が扱う資源を子が使う場合の合流と、処理と解放がともに失敗する終了経路は [coordination](./coordination.md) の「資源解放」に従う。
Effect 内部の body と release に Task を混在させない。
Map、Bind、Select、SelectMany、MapFailure、Recover、AcquireRelease は、Run が受けた同じ Deadline を下流の Effect と release へ渡し、合成の途中で期限を生成し直さない。

### 根拠
C# は型引数の部分推論を持たないため、文脈と値を同じ型引数列に並べると、呼び出しのたびに全型引数を書く儀式になる。
文脈を値へ束ねると、呼び出し面では変わるものだけを名指せる。
`Succeed` と `Try` は `TValue` が引数に現れるため型推論できるが、`Fail` と `Defect` は failure または exception だけを受け取るため `TValue` を推論できない。
生成関数が delegate を内に隠すので、利用側は `_run` を直に触らず Effect を作れる。
`Bind` は前段の成功値に依存して次の Effect を返す合成の核で、`Map` はその特例として導出できる。
`MapFailure` と `Recover` は Failed だけを変換し回復し、Defected と Canceled には触れない。
`AcquireRelease` は取得に成功した資源を、使用の成功・失敗・欠陥・取り消しのいずれでもちょうど一度解放する。
release を CancellationToken なしで待てば、Effect が取り消された後も後始末を中断しない。
元の Deadline を release へ渡せば期限の診断 context を保持できるが、期限超過を release の取消には使わない。
`Provide` は要求する依存を与えて `TRequirements` を `NoRequirements` に畳み、実行できる形にする。
body と release を ValueTask に揃えると、Effect runtime が一度だけ await する内部経路という役割がシグネチャから判別できる。
combinator が同じ Deadline を渡せば、Bind の段数ごとに時間枠が引き直されない。

### 完了条件
生成が `EffectContext` の `Succeed`・`Fail`・`Defect`・`Try` で行われている。
`Succeed` と `Try` の `TValue` が引数から推論されている。
`Fail<TValue>` と `Defect<TValue>` の呼び出しに値型の型引数が明示されている。
合成が `Map`・`Bind`(query 式なら `Select`・`SelectMany`)で行われている。
資源の取得と解放が `AcquireRelease` で行われ、使用の全終了経路で解放が一度だけ完了している。
依存提供が `Provide` で行われている。
`Try` の body が TRequirements、Deadline、CancellationToken、ValueTask<TValue> のシグネチャを持っている。
`AcquireRelease` の release が資源と Deadline を受けて ValueTask を返し、Task を返していない。
`AcquireRelease` の release が CancellationToken を受け取らず、取り消し後も非取消で完了している。
全ての combinator が、Run から受けた同じ Deadline を下流の Effect と release へ渡している。

### 禁止事項
`Recover` で、Defected や Canceled まで回復すること。
資源の解放を、失敗や取り消しの経路で漏らすこと。
生成関数を、Effect と同名の補助 static type や generic 型の static member に置くこと。
引数に `TValue` が現れない `Fail` または `Defect` で、値型が推論されるとみなすこと。
Effect 内部の body または release から、Task または Task<T> を返すこと。
combinator の内側で Deadline を生成し、相対 timeout を引き直すこと。
`AcquireRelease` の release へ CancellationToken を渡し、後始末を取り消し可能にすること。

### 行動
生成・合成・失敗変換・資源・依存提供を、上記の combinator で組む。
`Succeed` と `Try` は引数から `TValue` を推論させ、`Fail<TValue>` と `Defect<TValue>` は値型を明示する。
`Recover` は Failed だけを扱い、Defected と Canceled を素通しする。
`Try` の body と `AcquireRelease` の release は、Deadline を受け取る ValueTask の delegate に揃える。
`AcquireRelease` の release は元の Deadline だけを渡す非取消の後始末とし、CancellationToken を追加しない。
全ての combinator で、Run が受けた Deadline を値のまま下流の Effect と release へ渡す。

### 例
文脈は一度だけ名指しする。
`Succeed` と `Try` の値型は引数から推論させ、`Fail` と `Defect` の値型は明示する。
release は元の絶対期限を保持した非取消の後始末であり、終了状態にかかわらず一度実行する。

文脈から成功と試行の値型を推論し、値を持たない失敗と欠陥では値型を明示する。

```csharp
var fx = new EffectContext<TR, Fault>();
var effect = fx.Try(body, onError).Bind(value => fx.Succeed(Summarize(value)));
Effect<TR, Fault, Summary> failed = fx.Fail<Summary>(fault);
Effect<TR, Fault, Summary> defected = fx.Defect<Summary>(exception);
```

合成と query 式の入口は、同じ `Effect` の combinator に揃える。

```csharp
public static class EffectCombinators
{
    public static Effect<TRequirements, TFailure, TResult> Map<TRequirements, TFailure, TValue, TResult>(
        this Effect<TRequirements, TFailure, TValue> effect,
        Func<TValue, TResult> selector)
        where TRequirements : IEffectRequirements => EffectModule.Map(effect, selector);

    public static Effect<TRequirements, TFailure, TResult> Bind<TRequirements, TFailure, TValue, TResult>(
        this Effect<TRequirements, TFailure, TValue> effect,
        Func<TValue, Effect<TRequirements, TFailure, TResult>> bind)
        where TRequirements : IEffectRequirements => EffectModule.Bind(effect, bind);

    public static Effect<TRequirements, TFailure, TResult> Select<TRequirements, TFailure, TValue, TResult>(
        this Effect<TRequirements, TFailure, TValue> effect,
        Func<TValue, TResult> selector)
        where TRequirements : IEffectRequirements => effect.Map(selector);

    public static Effect<TRequirements, TFailure, TResult> SelectMany<TRequirements, TFailure, TValue, TIntermediate, TResult>(
        this Effect<TRequirements, TFailure, TValue> effect,
        Func<TValue, Effect<TRequirements, TFailure, TIntermediate>> collectionSelector,
        Func<TValue, TIntermediate, TResult> resultSelector)
        where TRequirements : IEffectRequirements =>
            effect.Bind(value => collectionSelector(value).Map(intermediate => resultSelector(value, intermediate)));

    public static Effect<TRequirements, TFailure2, TValue> MapFailure<TRequirements, TFailure, TFailure2, TValue>(
        this Effect<TRequirements, TFailure, TValue> effect,
        Func<TFailure, TFailure2> selector)
        where TRequirements : IEffectRequirements => EffectModule.MapFailure(effect, selector);

    public static Effect<TRequirements, TFailure, TValue> Recover<TRequirements, TFailure, TValue>(
        this Effect<TRequirements, TFailure, TValue> effect,
        Func<TFailure, Effect<TRequirements, TFailure, TValue>> handler)
        where TRequirements : IEffectRequirements => EffectModule.Recover(effect, handler);

    public static Effect<NoRequirements, TFailure, TValue> Provide<TRequirements, TFailure, TValue>(
        this Effect<TRequirements, TFailure, TValue> effect,
        TRequirements requirements)
        where TRequirements : IEffectRequirements => EffectModule.Provide(effect, requirements);
}
```

## 終了を成功と失敗と欠陥と取り消しに分ける

### 要求
Effect の終了は `EffectExit<TFailure, TValue>` の閉じた階層で表し、Succeeded・Failed・Defected・Canceled に分ける。
想定内失敗は TFailure の sealed record の階層で表し、欠陥と取り消しを TFailure に混ぜない。
純粋な計算の想定内失敗は、閉じた `Result<TValue, TFailure>` で表し、TFailure には Effect と同じ sealed record の階層を使う。
Result の実装は、Effect と同じく libs の機構が持つ。
Roslyn analyzer は、明示的な `default(Result<...>)`、Result への `default` literal の代入、型解決で Result と判定できる `default(T)` を検出する。
Result の内部 tag は、0 を未初期化、1 を成功、2 を失敗に固定する。
初期化状態を照会する `HasValue` だけは tag 0 を false として返す。
case の投影・取得を行う `Value` と `TryGetValue`、`Match`、`IsFailed`、等価性、hash、文字列化と演算子は、tag 0 を runtime で検出して欠陥を送出する。
等価性は両 operand を検査し、object overload も受け手が未初期化なら相手の型だけを見て false にしない。
初期化済みの case が許す null payload は有効であり、未初期化や第三の空の case と混同しない。

### 根拠
Result の二状態では、欠陥と取り消しを一つの型に分けて全域化できず、失敗に畳むか型の外へ逃がすことになる。
四つの終了に分けると、回復できる失敗と回復できない欠陥と取り消しを取り違えない。
TFailure を sealed record の階層にすると、網羅の switch で扱える。
明示的な default と型解決できる default は、Roslyn analyzer で利用前に止められる。
配列要素、field、未解決の generic から来る default まで analyzer で完全には検出できない。
初期化状態の照会と有効な case の観測を分ければ、HasValue の false を保ちつつ、default を成功・失敗や空の値として処理する経路を閉じられる。
外部依存の失敗は adapter で回復できる失敗と欠陥に分け、回復できる失敗を Failed に、欠陥を Defected にする。
EffectExit の基底も非 sealed な abstract record で、外部 assembly からの派生を型だけでは防げない限界と、その手当ては [formation](./formation.md) の「不正な状態を構築できなくする」に従う。

### 完了条件
Effect の終了が、Succeeded・Failed・Defected・Canceled に分かれている。
想定内失敗が、TFailure の sealed record の階層で表されている。
純粋な計算の想定内失敗が、libs の機構の `Result<TValue, TFailure>` で表されている。
明示的な `default(Result<...>)`、Result への `default` literal の代入、型解決で Result と判定できる `default(T)` が、Roslyn analyzer で検出されている。
Result の内部 tag 0 が、未初期化に割り当てられている。
HasValue だけが未初期化を false として返し、case の取得・投影と意味を使う各操作が tag 0 を欠陥として拒否している。
欠陥と取り消しが、TFailure に混ざっていない。

### 禁止事項
欠陥や取り消しを、TFailure に混ぜること。
想定内失敗を、例外で送出すること。
純粋な計算の失敗の表現に、採用した libs の Result と異なる第二の Result 型を持ち込むこと。
tag 0 の Result を、成功または失敗として扱うこと。
全ての default Result を、analyzer だけで検出できるとみなすこと。
HasValue 以外の case の観測や意味を使う操作から tag 0 の guard を外すこと、または未初期化を有効な空の case として公開すること。

### 行動
終了を EffectExit の四状態に分け、TFailure を sealed record の階層にする。
外部依存の失敗を adapter で仕分け、回復できる失敗を Failed、欠陥を Defected にする。
明示的な `default(Result<...>)`、Result への `default` literal の代入、型解決で Result と判定できる `default(T)` を、Roslyn analyzer で検出する。
Result の内部 tag 0 を未初期化に固定する。
HasValue の初期化状態の照会を残し、case の取得・投影、分岐、等価性、hash、文字列化と演算子は tag 0 を欠陥として閉じる。
配列要素、field、generic から来る default を実行テストへ置き、runtime guard を確認する。

### 例
すべての例外を想定内失敗へ畳み込むと、欠陥と取り消しまで同じ型に化ける。

```csharp
try { return Result.Succeeded(Place(cart)); }
catch (Exception exception) { return Result.Failed(OrderError.From(exception)); }
```

型解決できる `default` は Roslyn analyzer で止める。
静的検査を抜ける値は、HasValue の状態照会と、有効な case を観測する操作の欠陥を分けて確かめる。
成功と失敗の構築には `Result.Succeeded(value)` と `Result.Failed(failure)` を使う。
型付きの早期 return は `IsFailed`、全体の写像は `Match` で行う。
`Result.Value` の case は top-level の `Succeeded<TValue>` と `Failed<TFailure>` であり、Result の入れ子型ではない。

```csharp
Result<Order, OrderError> placed = Place(cart);
if (placed.IsFailed(out var failed, out var order))
{
    return failed;
}
return Result.Succeeded(Summarize(order));
```

効果の終了は閉じた四状態で表す。

```csharp
[Closed]
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
計算が要求する能力だけを `where` に出す。
composition root はその能力を実装した requirements を組み立て、runtime へ渡す。
テストは同じ能力を固定時刻やインメモリ実装で満たす。

```csharp
public interface IEffectRequirements { }
public sealed record NoRequirements : IEffectRequirements;
public interface IRequireClock : IEffectRequirements { DateTimeOffset GetCurrentTime(); }
public interface IRequireOrders : IEffectRequirements { IOrderRepository Orders { get; } }

public static Effect<TRequirements, PlaceOrderFailure, OrderId> PlaceOrder<TRequirements>(PlaceOrderCommand command)
    where TRequirements : IEffectRequirements, IRequireClock, IRequireOrders => /* ... */;

public sealed class ProductionRequirements(IClock clock, IOrderRepository orders)
    : IEffectRequirements, IRequireClock, IRequireOrders
{
    public DateTimeOffset GetCurrentTime() => clock.UtcNow;
    public IOrderRepository Orders { get; } = orders;
}
```

## 効果を境界で実行し analyzer と generator で縛る

### 要求
Effect の実行は `EffectRuntime<TRequirements>` の境界に限り、内側の層では実行しない。
EffectRuntime は requirements を保持し、Effect を解釈して `EffectExit` を返す。
EffectRuntime と Run は、別 assembly の composition root が呼べる公開 library API とする。
application の実行箇所は analyzer で composition root へ限定し、`Effect.Run` は library 内部の internal に保つ。
Run は Effect、Deadline、期限超過を TFailure へ写す関数、CancellationToken の順で受け、ValueTask を返す。
requirements、TimeProvider、IDeadlineDiagnostics を構築時に明示し、診断を捨てる既定の no-op 実装を置かない。
実行中に送出された OperationCanceledException を Canceled に、その他の例外を Defected に写し、想定内失敗は throw せず Fail で返す。
Run は `Deadline` の処理を始める境界として、[coordination](./coordination.md) の「取り消し」に従い、一つの通知 owner が親の取り消しと期限到達を合流させた token を Effect へ渡す。
開始前に親の取り消しと期限を判定し、期限切れの Effect を開始しない。期限の通知 owner と長い期限の扱いは同じ「取り消し」の規律に従う。
Run は、Canceled で終えた Effect を、受け取った CancellationToken が取り消し済みなら Canceled のまま返し、取り消されておらず通知 owner が期限到達を記録していれば、呼び出し側が渡す関数で作った期限超過の TFailure の値を持つ Failed へ写す。
Run は、親の取り消しにも記録した期限到達にも帰属しない Canceled を、adapter を経ずに届いた写し損ねとして、専用の欠陥 `UnattributedCancellationException` を持つ Defected で返す。
Run は、Succeeded・Failed・Defected で終えた Effect を、返却の後に観測した取り消しや Deadline の超過で書き換えず、Deadline を越えていれば診断へ記録する。
診断処理が例外を送出した場合は `DeadlineDiagnosticsException<TFailure, TValue>` の Defected とし、`CompletedExit` に診断前の終了の同一 instance、`InnerException` に診断例外を保持する。
この診断の欠陥を、業務操作が未実行または未確定だったという結果へ読み替えない。
Run は、通知 owner の callback と解放の欠陥を Defected で返し、元の終了と独立した欠陥の instance を失わず保持する。
この欠陥を期限超過の Failed にせず、元の終了の保持には [coordination](./coordination.md) の「資源解放」と同じ型付き `UseOutcome` を使う。
Effect.Run の未初期化 guard が送出する `UninitializedEffectException` は、EffectRuntime が専用の Defected として返す。
型で縛れない規則は、analyzer と source generator が次の4責務で強制する: R の合成環境の生成、Bind 連鎖での要求包含の検査、原始効果の閉じ込め、`NoRequirements` への迂回の禁止。

### 根拠
実行を境界に集めると、どこで副作用が起きるかが一箇所で読める。
host の async と取り消しで Effect を駆動し、送出された取り消しと欠陥を終了状態に写すので、内側は throw でなく Fail で想定内失敗を返せる。
Canceled は結果を要らなくなった側の取り消しであり、Deadline の超過は通知を所有する Run が想定内の失敗として受け取るので、Run は親の CancellationToken と、通知 owner が記録した期限到達を分けて判定する。
どちらからも説明できない Canceled を期限超過や取り消しと推測して返すと、他の機構による中断が期限の超過として報告されるので、専用の欠陥にする。
期限超過の TFailure の値を呼び出し側から受ければ、境界の失敗の型に期限超過の case が無いと Run を呼べず、応答を決める分岐が網羅の switch に現れる。
library の公開 Run と application の公開 host port を分ければ、assembly 越しの実行入口を提供しながら、host port の Task と一度だけ await する ValueTask の役割を保てる。
Deadline を Run から Effect へ値のまま渡せば、Effect の合成中に時間枠を引き直さない。
C# は型推論が弱く、実行境界の限定と要求の充足と原始効果の直呼びの禁止を、型だけでは縛れない。
要求する能力の組み合わせごとに環境型を手で書くと、組み合わせの数だけ nominal な型か神環境型のどちらかに倒れるので、source generator が組み合わせから環境型を生成する(R の合成)。
Bind の連鎖は C# の型推論だけでは呼び元の R が呼び先の R を包含することを保証しないので、analyzer が連鎖を検査する(伝播の検査)。
時刻・乱数・ID・I/O のような原始効果を宣言済みの能力の外で直接呼べると、要求が型に出ているという保証が崩れるので、analyzer が能力の実装と adapter の外での直呼びを検出する(原始効果の閉じ込め)。
`NoRequirements` への畳み込みの後に原始効果を直接使う経路は、要求を消したという型の主張を裏切る迂回なので、analyzer がこれを検出する(迂回の禁止)。

### 完了条件
Effect の実行が、composition root の境界に限られている。
OperationCanceledException が Canceled に、その他の例外が Defected に写されている。
Run が、親の取り消しと期限到達を一つの owner で通知し、同じ Deadline と合流した token を Effect.Run へ渡している。
Run が、親の CancellationToken が取り消し済みの Canceled を Canceled のまま返し、親が取り消されておらず期限到達が記録された Canceled だけを期限超過の Failed へ写している。
Run が、親の取り消しにも期限到達にも帰属しない Canceled を、`UnattributedCancellationException` の Defected として返している。
Run が、Succeeded・Failed・Defected を返却後の取り消しや Deadline の超過で書き換えず、Deadline を越えていれば診断へ記録している。
公開 library API の Run が composition root からだけ呼ばれ、Effect.Run は internal に閉じ、CancellationToken が末尾の必須引数になっている。
診断の依存が明示され、診断例外から元の終了と診断例外の両方を identity を失わず観測できる。
親と期限の各通知経路で callback の完了と欠陥が回収され、通知と解放の独立した欠陥および元の終了を同一 instance として観測できる。
`UninitializedEffectException` が、EffectRuntime から Defected として返されている。
実行境界の限定と要求の充足が、analyzer で検査されている。
R の合成環境が、source generator で作られている。
Bind の連鎖の要求包含が、analyzer の検査を通っている。
原始効果の直接呼び出しが、宣言済みの能力の実装と adapter の外に無いことが、analyzer で検査されている。
`NoRequirements` への迂回が、analyzer で検出されている。

### 禁止事項
内側の層で、Effect を実行すること。
`DateTimeOffset.UtcNow` のような原始効果を、純粋核や application で直に呼ぶこと。
analyzer と source generator の4責務のいずれかを、実装せず素通りさせること。
library の公開 Run を application の公開 host port と同一視し、host port へ ValueTask を流出させること。
診断を no-op へ既定化することや、診断の欠陥だけを返して確定済みの終了を消すこと。
Effect を実行するときに Deadline を渡さず、相対 timeout を引き直すこと。
Run で、受け取った CancellationToken が取り消し済みの Canceled を、期限超過の Failed へ写すこと。
Run で、受け取った token が取り消されていないことだけから、Canceled を期限超過の Failed へ写すこと。
Run で、親の取り消しにも記録した期限到達にも帰属しない Canceled を、Canceled のまま、または期限超過の Failed として返すこと。
Run で、Succeeded・Failed・Defected を、返却後に観測した取り消しや Deadline の超過で別の終了へ書き換えること。
callback の例外を親側や timer へ漏らすことや、通知機構の欠陥を期限超過へ写して元の終了を消すこと。

### 行動
Effect の実行を composition root の `EffectRuntime.Run` に集める。
公開 EffectRuntime.Run の呼出箇所を analyzer で限定し、境界で一度だけ生成した Deadline と、親の取り消しと期限到達を合流させた token を internal の Effect.Run へ渡す。
Effect が Canceled で終えたら、親の CancellationToken が取り消し済みなら Canceled のまま、親が取り消されておらず期限到達が記録されていれば期限超過の Failed へ、どちらでもなければ UnattributedCancellationException の Defected へ写す。
Succeeded・Failed・Defected は返却後の再確認で変えず、Deadline を越えていれば診断へ記録する。
Run が返る前に通知と解放へ合流し、その欠陥と元の終了を型付き UseOutcome で保持する。
`UninitializedEffectException` を、他の欠陥と同じく Defected へ写す。
source generator に R の合成を、analyzer に Bind 連鎖の検査・原始効果の閉じ込め・`NoRequirements` への迂回の検出を実装する。

### 例
composition root は、期限と時計と診断の依存を明示して公開 library API を一度 await する。
application が外へ公開する非同期 port の戻り値は Task のままにし、runtime の実装を application 側へ複製しない。

```csharp
var deadline = Deadline.FromBudget(timeProvider, requestBudget);
var runtime = new EffectRuntime<ProductionRequirements>(requirements, timeProvider, diagnostics);
EffectExit<PlaceOrderFailure, OrderId> exit = await runtime.Run(
    PlaceOrder<ProductionRequirements>(command),
    deadline,
    PlaceOrderFailure.FromDeadline,
    cancellationToken);
```

未初期化値の実行時防御は、consumer が metadata だけを参照する外部 assembly の generic producer から default Effect を受け取る境界で確かめる。
期限内かつ親が取り消されていない実行で、`UninitializedEffectException` を持つ Defected になることを観測する。
未初期化配列と同一 compilation の generic producer は EFFSYS008 の静的拒否を検査する対象であり、analyzer を回避できる利用例として掲載しない。


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
核が具象を直接生成する形は避ける。

```csharp
public sealed class OrderService { private readonly SmtpNotifier _notifier = new(); }
```

port は interface で宣言し、adapter の依存は constructor で受ける。

```csharp
public sealed class SmtpNotifier(ISmtpClient client) : INotifier;
```

## 配線を composition root に限る

### 要求
adapter の登録と requirements の組み立ては composition root に限り、`Program.cs` で行う。
middleware、endpoint、adapter、業務処理の本体で、`IServiceProvider` や `HttpContext.RequestServices` から依存を引く service locator を使わない。
`IServiceProvider` を受け取るアプリケーションの処理は、`Program.cs` の DI 登録 factory に限り、その本体は宣言済みの依存の配線だけを行う。
登録 factory は service の解決時に実行されるので、container から渡された解決 scope を使い、provider を保存したり、scoped な依存を root provider や singleton に保持したりしない。

### 根拠
組み立てを composition root の一点に集めれば、どの具象が使われるかが一箇所で見渡せる。
composition root が、本番の requirements を組み立てて runtime に与え、効果の実行を境界に置く。
処理の本体で `IServiceProvider` からその場で依存を引くと、依存をシグネチャから隠す service locator になる。
[DI の登録 factory](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/service-registration#registration-methods) は依存の配線を登録するものであり、[解決処理](https://github.com/dotnet/runtime/blob/60629d14374c56f1cb51819049ad1fa529307f8d/src/libraries/Microsoft.Extensions.DependencyInjection/src/ServiceLookup/CallSiteRuntimeResolver.cs) がその factory を現在の scope で呼び出す時点と、登録する時点は異なる。
組立点への集約は配線の所有を定める規律であり、全ての依存が起動時に構築されるという意味ではない。

### 完了条件
adapter の登録と requirements の組み立てが、composition root に限られている。
処理の本体が、必要な依存を constructor または framework の型付き注入入口で受け取り、provider から直接解決していない。
provider を受け取る処理が `Program.cs` の DI 登録 factory に限られ、配線だけを行い、解決 scope と service の lifetime が一致している。

### 禁止事項
DI 登録 factory の外で、`IServiceProvider` や `HttpContext.RequestServices` から依存を直接解決すること。
登録 factory に業務判断を置いたり、provider を注入先へ渡したり保存したりして、処理の本体で依存を探索できるようにすること。
登録 factory が解決時に実行される事実を、登録時だけの処理と説明して隠すこと。
scoped な依存を、root provider で解決したり singleton に保持したりすること。

### 行動
adapter の登録と requirements の組み立てを `Program.cs` に集め、runtime に requirements を与える。
framework の型付き注入入口を使い、framework 内部の依存解決をアプリケーションの処理へ持ち出さない。
DI 登録 factory が受け取る provider は、その factory 内の配線にだけ使い、解決 scope と lifetime を確認する。

### 例
middleware や endpoint の本体で provider から依存を引く service locator は避ける。

```csharp
var validator = _provider.GetService<IOrderValidator>();
```

composition root で requirements を組み、runtime に与える。

```csharp
var requirements = new ProductionRequirements(new SystemClock(), orderRepository);
var runtime = new EffectRuntime<ProductionRequirements>(requirements, TimeProvider.System, deadlineDiagnostics);
```

## 参照
効果システムは [effect](../../concerns/effect/README.md)、依存の向きは [dependency](../../concerns/dependency/README.md)、判別共用体の宣言は [formation](./formation.md) に従う。
取り消しは [coordination](./coordination.md)、資源は [npgsql](./npgsql.md)、組立点の構造は [structure/core/composition](../../structure/core/composition.md) に従う。
