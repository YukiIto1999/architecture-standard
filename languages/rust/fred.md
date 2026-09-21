# fred

用途は、Valkey へ接続する client である。
採用は、Rust は fred である。
判断基準は、接続を composition で共有して切断後に再接続し、session・cache・一時データの読み書きを一つの client interface に集約できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と、Valkey が推奨する Valkey GLIDE C# の preview 解除を再評価のトリガーとする。

## 一時データ

### 要求
session や cache のような寿命の短い共有状態は永続化の DB と分けて扱い、Valkey への接続は fred で行う。

### 根拠
fred は Valkey と Redis の両方を公式に対象にした非同期クライアントで、接続の pooling と backoff 付きの自動再接続を組み込みで持つ。
接続を fred の一つの機構に固定すれば、寿命の短い共有状態への接続の作法が Rust の中で割れない。

### 完了条件
寿命の短い一時データが、永続化の DB と分けて Valkey で扱われている。
Valkey への接続が、fred で行われている。

### 禁止事項
寿命の短い一時データを、永続化の DB に置くこと。

### 行動
一時データを Valkey に置き、接続を fred で行う。
