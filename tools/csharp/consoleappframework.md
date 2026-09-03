# ConsoleAppFramework

用途は、CLI の surface の骨格である。
採用は、C# は ConsoleAppFramework である。
判断基準は、引数を型で宣言して境界で一度 parse でき、依存を組立点から注入できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## console

### 要求
console は ConsoleAppFramework で組み、コマンドを型と constructor injection で組む。

### 根拠
コマンドを型と constructor injection で組めば、依存がシグネチャに現れ、組立点だけが具象を知る。
引数を型でバインドすれば、未検証の値が内側に入らない。

### 完了条件
console が、ConsoleAppFramework で組まれている。
コマンドが型と constructor injection で組まれている。

### 禁止事項
コマンドの中で、依存を直接生成すること。

### 行動
コマンドをクラスとして登録し、依存を constructor で受ける。

### 例
`Add<T>` で command を登録し、依存は constructor、引数は型でバインドする。

```csharp
var app = ConsoleApp.Create().ConfigureServices(services => services.AddSingleton<IGreetingService, GreetingService>());
app.Add<GreetCommands>(); app.Run(args);
public sealed class GreetCommands(IGreetingService greeter)
{
    public void Greet(string name, int count = 1) { for (var i = 0; i < count; i++) Console.WriteLine(greeter.Greet(name)); }
}
```
