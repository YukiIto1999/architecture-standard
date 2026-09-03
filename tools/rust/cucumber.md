# cucumber

用途は、業務語彙の executable spec を実行する道具である。
採用は、Rust は cucumber の Rust 実装である。
判断基準は、業務語彙のシナリオを公開の interface 越しに検証できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 仕様

### 要求
業務語彙の executable spec は、[verification](../../principles/verification.md) が定める同じ検査経路で、cucumber の Rust 実装として実行する。
feature の各 step は、一つの step binding と、その binding が呼ぶ公開 interface の operation に対応させる。
feature、step binding、公開 interface の対応は、各一覧を実体から導く drift 検査と executable spec の実行で検証する。

### 根拠
[verification](../../principles/verification.md) が定める、実行可能な仕様と実装を同じ検査経路に載せ、別成果物なら対応を検証する要求に、cucumber の Rust 実装で応える。
feature、step binding、公開 interface は別の成果物なので、対応の drift 検査がなければ一方だけ古くなりうる。

### 完了条件
業務語彙の executable spec が、cucumber の Rust 実装で書かれ、実行されている。
feature の全 step が、一つの step binding と公開 interface の operation に対応している。
feature、step binding、公開 interface の対応に欠落と余剰がなく、drift 検査と executable spec の実行が同じ検証入口で通っている。

### 禁止事項
仕様に、実装の操作の語を書くこと。
実行可能であることを理由に、feature、step binding、公開 interface の継ぎ目が消えたとみなすこと。
feature、step binding、公開 interface の対応を、人が固定した件数だけで検査すること。

### 行動
業務の語彙でシナリオを書き、cucumber の Rust 実装でステップを実装する。
feature の step、step binding、公開 interface の operation をそれぞれ実体から列挙し、対応の欠落と余剰を drift 検査で失敗させる。
drift 検査と executable spec を、実装と同じ検証入口で実行する。
