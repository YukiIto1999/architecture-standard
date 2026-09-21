# NSwag

用途は、契約から C# の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、C# は NSwag である。
判断基準は、contracts/generated の client と型を契約から生成でき、drift をリポジトリの検証入口の gate にできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の C# の client と型は NSwag で生成し、利用を client・型と drift・conformance の検査に限る。
server の stub 生成に使わず、server の実装は Minimal API を保つ。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、利用側が契約に従う。
server の stub を生成すると、生成の都合が server の構造を縛るので、server は Minimal API を保つ。

### 完了条件
client と型が、NSwag で生成されている。
NSwag の利用が、生成と検査に限られ、server の stub 生成に使われていない。

### 禁止事項
NSwag を、server の stub 生成に使うこと。

### 行動
NSwag で client と型を生成し、server は Minimal API で実装する。
