# reqwest

用途は、外部の HTTP API を呼び出す非同期の client である。
採用は、Rust は reqwest であり、TLS は rustls である。
判断基準は、Tokio の runtime に接続でき、要求の future の drop と取り消しで要求を中断でき、TLS を rustls で担えることである。
生成した契約の HTTP transport も同じ reqwest を使い、[translation](./translation.md) が定める接続先と client の注入を満たすことを含む。
TLS の機能は通信を組み立てる crate が有効にし、純粋な生成型・構築・codec の crate に reqwest を要求しない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
