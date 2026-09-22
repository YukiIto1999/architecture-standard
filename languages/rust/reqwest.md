# reqwest

用途は、外部の HTTP API を呼び出す非同期の client である。
採用は、Rust は reqwest であり、TLS は rustls である。
判断基準は、Tokio の runtime に接続でき、timeout と取り消しを要求ごとに接続でき、TLS を rustls で担えることである。生成した契約の client([progenitor](./progenitor.md))が内部で使う library と一致し、手書きの呼び出しと生成 client で HTTP 実装が割れないことを含む。生成物は reqwest の既定機能を外して `json`・`query`・`stream` だけを要求するため、rustls は製品の crate が reqwest の `rustls` 機能を有効にして与える。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
