# redis

用途は、Valkey へ接続する非同期 client である。
採用は、Rust は redis である。
判断基準は、Valkey に接続して tokio の非同期処理から共有でき、切断後に再接続し、session・cache・一時データの読み書きを一つの client interface に集約できることである。tower-sessions の SessionStore を redis で実装できることを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、Valkey 対応の終了、非同期 ConnectionManager の再接続機構の変更を再評価のトリガーとする。

## 一時データ

### 要求
session や cache のような寿命の短い共有状態は永続化の DB と分けて扱い、Valkey への接続は redis の ConnectionManager で行う。
tower-sessions の SessionStore は、[structure/surfaces/server/layout](../../structure/surfaces/server/layout.md) が定める bff の session の adapter として実装し、同じ redis client を使う。

### 根拠
redis-rs は Valkey と Redis に対応する非同期 client で、ConnectionManager が切断後の再接続を担う。
client を一つに固定して SessionStore の adapter も同じ client で書けば、寿命の短い共有状態と session の接続の作法が Rust の中で割れない。

### 完了条件
寿命の短い一時データが、永続化の DB と分けて Valkey で扱われている。
Valkey への接続が、redis の ConnectionManager で行われている。
tower-sessions の SessionStore が、bff の session の adapter として redis を使って実装されている。

### 禁止事項
寿命の短い一時データを、永続化の DB に置くこと。
tower-sessions の session store だけ別の Redis client で接続すること。

### 行動
一時データを Valkey に置き、redis の ConnectionManager で接続する。
SessionStore の実装を bff の session の adapter に置き、同じ client で session を保持する。
