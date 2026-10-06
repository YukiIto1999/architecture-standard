# concerns を更新するとき

concerns は、特定概念で守る言語非依存の性質と保証を所有する。
principles の判断基準と一般規律を、認可、永続化、並行性などの概念の性質と保証として具象化する。
配置は [root README](../../../README.md) の配置規則に従い、実装が一つのモジュールでも概念の保証は concerns に置き、具体的な構成と配置は structure に置く。

## 既存の24概念

effect・concurrency・dependency・types・context-propagation・persistence・caching・migration・transaction・messaging・workflow・authentication・authorization・privacy・security・secrets・audit-trail・observability・configuration・resilience・performance・lifecycle・experience・accessibility。
新概念を足す前に、この24に当たる所がないかを必ず確かめる。当たれば足す、当たらなければ抜けなので新設する。
file を分ける単位の契約は、[concerns/README](../../../concerns/README.md) を正本とする。
分ける根拠は分類軸で述べ、行数や項目数を根拠にしない。

## 根拠の高度

概念の高度での具象化を述べる。
principles が所有する判断基準と一般規律は再導出せず、概要で参照する。
言語固有の実現と ecosystem の採用判断は languages が、言語横断の採用判断は tools が所有する。

## 書式

概念フォルダの README は `## 概要`(統べる規律と、具象化する principle への参照)、`## 規律` の台帳、末尾に `## 参照`。規律ファイルは `## 規律名`、必須の5節、必要な場合だけ例。README と一組で読む。
規律名は概念固有・精密な名詞・単一意味軸にする。一つの規律に二つの主題を詰めない。
例は言語非依存にする。擬似コード・標準的な SQL・構造で示し、特定言語の構文や方言を持ち込まない。

## この層の MECE 点検

- 言語機構・方言(sqlx・EF・tokio・zod・ON CONFLICT など)が本文や例に漏れていないか(漏れていれば languages へ)。
- 規格・プロトコル名を除き、市場から選ぶ製品の採用や選定理由が漏れていないかを確認し、言語横断の採用は tools、言語 ecosystem 固有の採用は languages への参照に戻す。
- principles の原則文を再述していないか。完了条件と禁止事項に、具象化する principle の完了条件・禁止事項と同じ観測を別の語で書いていないか(書いていれば参照だけに置き換える)。
- 他の概念と同じ規律を重複させていないか(一つが所有し他は参照。例: outbox は transaction が所有、messaging は配送に絞り参照)。
- 規律名が単一意味軸か(二主題が混ざっていれば分割)。
- 概念の性質と保証を concerns、具体的な構成を structure が所有しているか(認可の保証は concerns、認可 adapter の配置と root またぎの許可依存は structure に分け、適用されるモジュール数や規範に従う関係を所有先の根拠にしない)。
- 新概念なら README の概念表と概念数を更新したか。
