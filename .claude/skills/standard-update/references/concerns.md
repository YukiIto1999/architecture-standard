# concerns を更新するとき

concerns は、言語非依存の概念ごとの規律を置く。
principles の原則を、全系を通す概念の高度で具象化する。モジュール設計の詳細(認証認可・DB/テーブル・型など)はここに来る。

## 既存の17概念

effect・concurrency・dependency・types・persistence・transaction・messaging・authentication・authorization・observability・privacy・security・configuration・resilience・performance・lifecycle・experience。
新概念を足す前に、この17に当たる所がないかを必ず確かめる。当たれば足す、当たらなければ抜けなので新設する。

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
