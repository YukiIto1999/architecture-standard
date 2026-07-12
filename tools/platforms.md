# platforms

platforms は、セルフホストする基盤の採用を定める。
エントリは、[README](./README.md) の書式と選定の共通基準に従う。
基盤に対する規律は concerns と structure が定め、ここでは採用と判断基準だけを持つ。

## datastore

用途は、永続化する事実の正本を関係と制約で保つ datastore である。
採用は、PostgreSQL である。
判断基準は、外部キー・一意・NOT NULL・検査の制約で関係の意図を表せることと、worker の queue の backend を同じ store で賄い、外部の broker を開かずに済むことである。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。

## 一時 store

用途は、キャッシュ・session・一時データを保つ store である。
採用は、Valkey である。
判断基準は、キャッシュ・session・一時データの用途を単一の store で賄え、失効・整合・運用の手順を増やさないことである。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。

## 認可の engine

用途は、権限のモデルを評価する認可の engine である。
採用は、OpenFGA である。
判断基準は、権限のモデルを役割・関係・属性の宣言的な組み合わせで表せることと、engine の datastore を既存の採用で賄えることである。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。

## 検査の基盤

用途は、認知的複雑さの検査と quality gate を提供する検査の基盤である。
採用は、SonarQube Community Build のセルフホストである。
判断基準は、無償の Community Build が cognitive complexity(S3776)と quality gate を提供することと、セルフホストが 1 顧客 1 配備と整合することである。
検査の道具としての使い方は、[inspection](./inspection.md) に従う。
撤回条件は、無償の Community Build で判断基準の提供が続かなくなることであり、リリースポリシーの変化を再評価のトリガーとする。

## secret の暗号化

用途は、secret を at-rest で暗号化して保つ機構である。
採用は、SOPS であり、鍵は age である。
判断基準は、secret を at-rest で暗号化したまま配備の定義と一緒に版管理へ置けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## telemetry

用途は、telemetry の出力の規格と収集の基盤である。
採用は、OpenTelemetry であり、収集は OpenTelemetry collector で行う。
判断基準は、ログ・計測・トレースを単一の規格で扱え、収集を業務のプロセスの外へ分離できることである。
配置の規律は、[concerns/observability](../concerns/observability.md) に従う。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。
