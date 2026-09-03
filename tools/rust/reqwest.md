# reqwest

用途は、外部の HTTP API を呼び出す非同期の client である。
採用は、Rust は reqwest(TLS は rustls)である。
判断基準は、Tokio の runtime に接続でき、timeout と取り消しを要求ごとに接続でき、TLS を rustls で担えることである。生成した契約の client(openapi-generator の rust generator)が内部で使う library と一致し、手書きの呼び出しと生成 client で HTTP 実装が割れないことを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
