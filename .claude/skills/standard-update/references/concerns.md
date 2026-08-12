# concerns を更新するとき

concerns は、言語非依存の概念ごとの規律を置く。
principles の原則を、全系を通す概念の高度で具象化する。モジュール設計の詳細(認証認可・DB/テーブル・型など)はここに来る。

## 既存の17概念

effect・concurrency・dependency・types・persistence・transaction・messaging・authentication・authorization・observability・privacy・security・configuration・resilience・performance・lifecycle・experience。
新概念を足す前に、この17に当たる所がないかを必ず確かめる。当たれば足す、当たらなければ抜けなので新設する。

## 拠り所(概念ごとに一次資料へ)

概念に効く一次パターンと、領域に効く11名に照らす。
effect は純粋核と効果の殻、types は King(parse don't validate)と kawasima(always-valid)とミノ駆動・増田の値オブジェクト、persistence は Codd の正規化と Date の真である命題と Helland の追記と そーだい、transaction は outbox(Richardson)と Vernon の集約境界と Helland、messaging は Hohpe の EIP と Helland と Kleppmann、authentication と authorization と security は Saltzer & Schroeder と OWASP と NIST と XACML、observability と resilience と lifecycle と concurrency の運用面は nwiizo(加えて OpenTelemetry・Nygard の Release It!・Google SRE・12-Factor・crash-only)、dependency は Martin の DIP と Cockburn と Seemann、experience は Nielsen・Norman・Tognazzini・Krug・Rams と WCAG のユーザビリティ/インタラクション原則(11名の外の領域固有の一次資料。`docs/research/2026-uiux-design-principles.md` に台帳あり)。
外部事実を追加または変更するときは、本 skill の調査手順に従って最低2源で裏取りし、`docs/research/` に台帳化する。

## 根拠の高度

概念の高度での具象化を述べる。
原則の根本のなぜを再導出しない。それは principles 側にあり、概要で参照する。
languages の機構の話もしない。

## 書式

`## 概要`(統べる規律と、具象化する principle への参照)、規律ごとの `## 規律名`、必須の5節、必要な場合だけ例、末尾に `## 参照`。
規律名は概念固有・精密な名詞・単一意味軸にする。一つの規律に二つの主題を詰めない。
例は言語非依存にする。擬似コード・標準的な SQL・構造で示し、特定言語の構文や方言を持ち込まない。

## この層の MECE 点検

- 言語機構・方言(sqlx・EF・tokio・zod・ON CONFLICT など)が本文や例に漏れていないか(漏れていれば languages へ)。
- 市場から選ぶ製品の採用や選定理由が漏れていないか(漏れていれば tools へ。規格・プロトコル名は対象外)。
- principles の原則文を再述していないか(根拠の高度がぶれていれば概念の具象化へ寄せる)。
- 他の概念と同じ規律を重複させていないか(一つが所有し他は参照。例: outbox は transaction が所有、messaging は配送に絞り参照)。
- 規律名が単一意味軸か(二主題が混ざっていれば分割)。
- 相互参照の向きが正しいか(concerns が正本、structure は参照する側で、逆転させない)。
- 新概念なら README の概念表と概念数を更新したか。
