# ArchUnitNET

用途は、依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である。
採用は、C# は ArchUnitNET である。
判断基準は、層の参照禁止・公開面・副作用の参照禁止を規則として書け、違反をリポジトリの検証入口で止められることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 構造

### 要求
依存方向と境界の禁止は ArchUnitNET で検証し、namespace を層と単位に対応させて、層の参照禁止・公開面・副作用の参照禁止を規則として書く。
root の ArchUnitNET 検査は、skeleton の production のソース依存表と build・test-only 表から runtime・build・test phase の許可 edge を生成し、成果物の消費表から導く配備と同梱起動の入力をソース参照と分けて検査する。
root の ArchUnitNET 検査は、build または test の edge が runtime の成果物へ混入した場合に失敗する。

### 根拠
[verification](../../principles/verification/README.md) が定める、依存の向きやレイヤー越境は実行できるテストとして強制するという要求に、ArchUnitNET で応える。
namespace を層と単位に対応させれば、層の参照禁止や副作用の参照禁止を規則として表せる。
規則をテストとして回せば、違反でビルドが止まる。
ArchUnitNET の namespace の走査は型を介さない静的な呼び出しを見ないので、その禁止は Microsoft.CodeAnalysis.BannedApiAnalyzers などの banned API の lint に割り当てる。

### 完了条件
依存方向と境界の禁止が、ArchUnitNET で検証されている。
namespace が層と単位に対応し、層の参照禁止・公開面・副作用の参照禁止が規則として書かれている。
root の ArchUnitNET 検査が、skeleton の各表からソースの phase と成果物の消費を区別した許可 edge を生成している。
build または test の edge が runtime の成果物へ混入した場合に、ArchUnitNET 検査が失敗している。

### 禁止事項
構造の規則を、コメントや約束だけで守らせること。

### 行動
namespace を層と単位に対応させ、ArchUnitNET で層の参照禁止・公開面・副作用の参照禁止を規則にする。
skeleton の各表を読み、runtime・build・test phase のソース参照を project 参照と照合し、成果物の配備と同梱起動は入力の宣言として別に照合する。
runtime の成果物を構成する参照 closure に build または test の edge があれば失敗させる。

### 例
層の参照制約は構造テストとして実行する。

```csharp
Types().That().ResideInNamespace("App.Domain")
    .Should().NotDependOnAny(Types().That().ResideInNamespace("App.Infrastructure"))
    .Check(Architecture);
```
