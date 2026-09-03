# ArchUnitNET

用途は、依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である。
採用は、C# は ArchUnitNET である。
判断基準は、層の参照禁止・公開面・副作用の参照禁止を規則として書け、違反をリポジトリの検証入口で止められることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 構造

### 要求
依存方向と境界の禁止は ArchUnitNET で検証し、namespace を層と単位に対応させて、層の参照禁止・公開面・副作用の参照禁止を規則として書く。
root の ArchUnitNET 検査は、skeleton の実行時表と build・test-only 表から runtime・build・test phase の許可 edge を生成する。
root の ArchUnitNET 検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。
Roslyn analyzer は、surface と host の公開非同期 API が Task または Task<T> を返し、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> を返すことを semantic model で検査する。
Roslyn analyzer は、request、message、job の境界より内側の非同期 API が、非取消の後始末である `AcquireRelease` の release と `IAsyncDisposable.DisposeAsync` を除き、Deadline と CancellationToken を必須引数に持つことを検査する。
Roslyn analyzer は、release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を行うことを検査する。
`IAsyncDisposable.DisposeAsync` の呼出側が、同じ Deadline を後始末の scope に保持することを検査する。
Deadline の生成が request、message、job の境界に限られることを検査する。
Roslyn analyzer は、各 hop の CancellationTokenSource が `deadline.Remaining(timeProvider)` から作られ、下流へ remaining でなく同じ Deadline が渡ることを検査する。

### 根拠
[verification](../../principles/verification.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、ArchUnitNET で応える。
namespace を層と単位に対応させれば、層の参照禁止や副作用の参照禁止を規則として表せる。
規則をテストとして回せば、違反でビルドが止まる。
ArchUnitNET の namespace の走査は型を介さない静的な呼び出しを見ないので、その禁止は Microsoft.CodeAnalysis.BannedApiAnalyzers などの banned API の lint に割り当てる。
Roslyn semantic model なら、method の accessibility、戻り値、引数、呼出式の symbol を結び付け、公開 host API と Effect 内部の awaitable の役割を区別できる。
同じ model で Deadline の生成と伝播、remaining の使用先を追えば、hop ごとに新しい相対 timeout を始める経路を拒否できる。
release と `DisposeAsync` を CancellationToken の必須規則から明示的に分ければ、通常の非同期 API の伝播漏れと、非取消でなければならない後始末を混同しない。

### 完了条件
依存方向と境界の禁止が、ArchUnitNET で検証されている。
namespace が層と単位に対応し、層の参照禁止・公開面・副作用の参照禁止が規則として書かれている。
root の ArchUnitNET 検査が、skeleton の両表から phase ごとの許可 edge を生成している。
build または test の edge が runtime の成果物へ混入した場合に、ArchUnitNET 検査が失敗している。
公開する surface と host の非同期 API が Task または Task<T>、Effect 内部の Run、Try body、AcquireRelease release が ValueTask または ValueTask<T> に分かれている。
境界より内側の非同期 API が、release と `DisposeAsync` を除いて Deadline と CancellationToken を必須引数に持ち、Deadline が request、message、job の境界だけで生成されている。
release が同じ Deadline を受けて CancellationToken を受け取らず、`DisposeAsync` が引数なしで非取消の後始末を完了している。
各 hop の局所 timeout が `deadline.Remaining(timeProvider)` から作られ、同じ Deadline が下流へ渡されている。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。
公開 host API と Effect 内部の awaitable の役割分担を、レビューだけで検査すること。
hop ごとに相対 timeout を引き直す経路を、構造検査から外すこと。
release と `DisposeAsync` へ CancellationToken を要求し、非取消の後始末を通常の非同期 API と同じ規則で検査すること。

### 行動
namespace を層と単位に対応させ、ArchUnitNET で層の参照禁止・公開面・副作用の参照禁止を規則にする。
skeleton の両表を読み、runtime・build・test phase の許可 edge を生成して project 参照と照合する。
runtime の成果物を構成する参照 closure に build または test の edge があれば失敗させる。
Roslyn analyzer で、公開 host API の Task と Effect 内部の ValueTask の戻り値を検査する。
Roslyn analyzer で、境界より内側の非同期 API の Deadline と CancellationToken、境界だけでの Deadline 生成、remaining からの局所 timeout 生成、同じ Deadline の下流伝播を検査する。
release と `DisposeAsync` は CancellationToken の必須規則から除き、元の Deadline を保持する非取消の後始末として検査する。

### 例
層の参照制約は構造テストとして実行する。

```csharp
Types().That().ResideInNamespace("App.Domain")
    .Should().NotDependOnAny(Types().That().ResideInNamespace("App.Infrastructure"))
    .Check(Architecture);
```
