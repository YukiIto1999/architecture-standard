# OpenTelemetry

用途は、telemetry の出力の規格と収集の基盤である。
採用は、OpenTelemetry であり、収集は OpenTelemetry collector で行う。
判断基準は、ログ・計測・トレースを単一の規格で扱え、収集を業務のプロセスの外へ分離できることである。
配置の規律は、[concerns/observability](../../concerns/observability.md) に従う。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。
