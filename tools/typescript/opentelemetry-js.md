# OpenTelemetry JS

用途は、利用者の環境で動く viewer の trace と構造化 event を、境界の殻で収集する機構である。
採用は、TypeScript は OpenTelemetry JS の WebTracerProvider と span event、OTLP/HTTP の trace exporter である。
判断基準は、ui port の背後で trace と構造化 event を同じ active span に記録し、採用済みの collector へ出力できることである。
撤回条件は、判断基準を満たさなくなることであり、browser 計装の experimental status の変更、logs の API と SDK の stable 到達、保守の停止、bundle と実行負荷の実測が project の予算を超えることを再評価のトリガーとする。

## viewer の telemetry

### 要求
viewer の trace と構造化 event の収集は、ui port の背後に閉じる。これを OpenTelemetry JS の modular な browser 構成で満たす。
trace と event は同じ文脈で相関させ、OTLP/HTTP で collector へ送る。
SDK の登録と exporter の構成は、host の adapter が持つ。

### 根拠
収集を境界の殻で行う規律([observability](../../concerns/observability/README.md))に、ui port の背後の OpenTelemetry で応える。
viewer 本体が SDK に触れると、収集の機構が UI の関心へ漏れる。
API と SDK を分ける OpenTelemetry の構成は、port の型を API だけに依存させ、SDK を adapter に隔離できる。
独立した UI の event は、trace の文脈を付けた LogRecord で表すと、trace と同じ文脈で相関できる。

### 完了条件
収集の呼び出しが、ui port の型だけに依存している。
SDK の登録と exporter が、host の adapter に閉じている。
trace と event が、同じ文脈で相関して collector へ届いている。

### 禁止事項
viewer の component から、SDK や exporter を直接使うこと。
収集の失敗を、UI の操作の失敗にすること。

### 行動
telemetry の ui port を定義し、host の adapter で OpenTelemetry の SDK と exporter を構成する。
event には trace の文脈を付け、OTLP/HTTP で collector へ送る。
