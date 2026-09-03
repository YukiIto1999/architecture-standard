# StackExchange.Redis

用途は、Valkey へ接続する client である。
採用は、C# は StackExchange.Redis である。
判断基準は、接続を composition で共有して切断後に再接続し、session・cache・一時データの読み書きを一つの client interface に集約できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Valkey が推奨する Valkey GLIDE C# の preview 解除を再評価のトリガーとする。

## 一時データ

### 要求
session や cache のような寿命の短い共有状態は永続化の DB と分けて扱い、Valkey への接続は StackExchange.Redis で行う。

### 根拠
寿命の短い一時データを永続化の DB に混ぜると、寿命の違うデータが同じ確定点と制約に縛られる。
Valkey に分け、接続を StackExchange.Redis の一つの機構に固定すれば、寿命の短い共有状態を独立に扱える。

### 完了条件
寿命の短い一時データが、永続化の DB と分けて Valkey で扱われている。
Valkey への接続が、StackExchange.Redis で行われている。

### 禁止事項
寿命の短い一時データを、永続化の DB に置くこと。

### 行動
一時データを Valkey に置き、接続を StackExchange.Redis で行う。
