---
name: standard-audit
description: architecture-standard(principles/concerns/languages/structure)を MECE と忠実度で監査する。フォルダ間とファイル間の重複・抜け、11名の参考エンジニアの足場、humanizer-ja の文体、6節書式(structure は layout 書式)、標準は単一の維持、言語非依存、自己充足、作り切り、事実誤りを、読み取り専用で点検し、重大度つきで指摘を返す。標準を変更する前後、コミット前、また「監査」「見直す」「MECE を確認」「矛盾や重複がないか」「足場が薄くないか」と言われたときは、skill 名を明示されなくても必ずこれを使う。修正はせず指摘に留める(修正は standard-update)。
---

# standard-audit

標準を、白紙の目で MECE と忠実度で監査する。
書いた者は自分の文を客観視できないので、別の目で見る。
**読み取りと報告のみ。ファイルを編集しない。** 修正は standard-update の仕事である。

## やり方

標準をスライスに分け、スライスごとに**白紙の subagent** を当てる。
書いた当人の再読では bias が入るので、必ず新しい subagent に読ませる。先入観を与えない brief を渡し、白紙の状態から9軸を独立に評価させる。
スライスの目安は、principles 全体、concerns を前半と後半、languages を rust・csharp・typescript、structure を skeleton+core+contracts と surfaces+runtimes+deploy+tests。
独立した複数スライスは、一つのメッセージで並行に投げる。
各 subagent は下の9軸で読み、重大度つきで指摘を返す。最後に統合する。
機械検査は standard-update の `scripts/verify.sh` を使う。

## 監査の9軸

汎用ベストプラクティスでなく、この標準の確立済みの前提を基準にする。

- **A 思想の足場(11名)**: ミノ駆動・増田・nwiizo・mizchi・そーだい・t-wada・kawasima・A.King・R.C.Martin・Fowler・farstep。各単位が、その領域に効く参考者の主張とずれていないか。明らかな足場が反映されていない箇所(運用面の nwiizo、DB の そーだい、型の King/farstep など)。本文に人名は出さないので内容で見る。検出したずれは `docs/decisions/0011-deliberate-divergences.md` の台帳に照合し、意図的な採否は指摘でなく台帳との一致確認として扱う。
- **B 文章スタイル(humanizer-ja・k16shikano)**: 記号(❌✅・emoji)、見出しの括弧、冗長・水増し、hedging(〜かもしれない)、経緯・進捗・予定のマーカー、一文多義、不要な前置き。
- **C 6節書式**: `## 概要`＋単位ごとの `## 名`(`### 要求/根拠/完了条件/禁止事項/行動`、必要なら `### 例`)＋`## 参照`(principles は概要にリードとして埋める)。欠落・順序乱れ・空節。structure は6節を使わず、導入の参照文・フォルダ構成の図・単位表または依存方向表・topical な見出しからなる layout 書式に従う(該当なし、または6節を持ち込んでいれば指摘)。
- **D 整合性・フォルダ内 MECE**: ファイル間の重複(同じことを二箇所で根拠ごと書く)、矛盾、根拠の高度(principles=根本/concerns=概念/languages=機構)、相互参照の正しさ(concerns が正本、structure が参照側、逆転していないか)。
- **E 標準は単一**: 条件付きの分岐や例外を標準の側に作っていないか。逸脱は project の ADR へ送る形か。
- **F 言語非依存・フォルダ間 MECE**: principles と concerns に言語機構・製品名・方言が漏れていないか。設計原則が principles のみ、モジュール設計の詳細が concerns のみ、ちょうど一つの部の境界・中身が structure のみ、言語の扱いが languages のみに分かれているか。原則の再導出を concerns や structure でしていないか。concerns の横断規律を structure が再定義していないか。
- **G 自己充足**: docs を読まずとも、各単位の要求・完了条件・禁止事項だけで従えるか。folder の地図だけで決定が転写されていない箇所。
- **H 作り切り**: 要求された深さに対し浅い(MVP 的)、または未要求の投機を作り込んでいる箇所。網羅の抜け。
- **I 事実誤り**: 一次資料に照らして誤り・不正確・版依存の誤り。疑わしい所だけ web で spot-check(snippet 断定しない)。

## 出力

重大度つきで、`ファイル:該当箇所:指摘:根拠` の形で列挙する。

- **critical**: 誤り・前提違反・実コードが通らない。
- **major**: 足場の薄さ・整合性の崩れ・フォルダ間/ファイル間の MECE 違反・網羅の抜け。
- **minor**: スタイル・語・配置の磨き。

最後にスライスごとの総評(強い点・弱い点・足場が薄い単位)を付ける。
指摘のみを返し、修正は提案に留める。修正へ進むなら standard-update を使う。

## 関連

- `standard-update` — 指摘を受けて実際に直す skill。監査はその前後で使う。
