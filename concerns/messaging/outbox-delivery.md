## outbox から配送する

### 要求
integration event の記録は [transaction](../transaction/README.md) の outbox に従い、配送は outbox から読み出して行う。
記録と配送を分け、配送は少なくとも一度として扱う。

### 根拠
記録と配送を同じ経路で行うと、配送の失敗が記録の確定を巻き込む。
記録を transaction の outbox に確定させ、配送を別に行えば、確実な記録と再試行できる配送に分けられる。
配送は分散した経路を通るので、少なくとも一度として扱い、重複は消費側の冪等で吸収する。

### 完了条件
integration event の記録が、transaction の outbox に従っている。
配送が、outbox から読み出して行われ、記録と分かれている。

### 禁止事項
記録と配送を同じ経路に混ぜ、配送の失敗で記録の確定を巻き込むこと。

### 行動
記録は transaction の outbox に委ね、配送は outbox を読み出して行う。
