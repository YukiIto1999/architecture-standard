---
name: standard-apply
description: architecture-standard を対象 project や repository へ適用し、新規構築、準拠監査、移行、設計、実装、refactoring、構造改善、staged diff review、準拠 commit 基準の review を行う。architecture-standard、準拠 commit、またはこの repository の標準を基準に対象を作る、調べる、直す、review する依頼では、調査や編集に着手する前に、この skill を必ず使う。別の標準、標準そのものの変更や自己監査には使わず、後二者には standard-update / standard-audit を使う。
---

# standard-apply

標準を project へ適用する入口である。
手順と判定基準の正本は標準本文に置き、この skill へ転写しない。

## 前提

- この skill がある repository を標準、依頼で示された repository を対象 project とする。
- この skill の所在から標準 repository root を特定し、`<standard-root>` として固定する。対象 project を current directory にした Git 操作と混ぜない。
- 対象 project の ADR から、準拠基準として記録された標準 commit を特定し、その commit の本文を使う。OID を特定した後は root `README.md`、選んだ process、参照規律を記録した commit object から読む。作業 tree の本文を使えるのは、対象 blob が記録 commit と byte-identical だと確認した場合だけであり、OID の表示だけで基準にしたとは扱わない。既存 project に記録がなければ現行標準へ代替せず、準拠基準の欠落として報告し、監査、移行、設計、実装、構造改善、レビューを止める。新規構築は採用する現行 commit を ADR に記録してから進める。
- 標準本文は編集しない。標準側の不備は file と該当箇所を報告し、修正は standard-update へ渡す。

## 手順

1. 標準の `README.md` を読み、依頼をモードへ写像する。新規構築=`process/bootstrap.md`、監査=`process/audit.md`、移行=`process/migration.md`、設計=`process/design.md`、実装=`process/implementation.md`、構造改善=`process/refactoring.md`、レビュー=`process/review.md` である。
2. 選んだ process 本文を読み、そこから参照される規律のうち、対象範囲の判定に必要な本文だけを読む。記憶、見出し、一般的なベストプラクティスで補完しない。
3. process の順序と確認点を内部チェックリストとして管理する。応答へ全文を転写せず、依頼に関係する進捗、見送り、未確認事項だけを報告する。
4. 標準が決めている事項と project 固有の決定を分ける。標準が沈黙する事項や逸脱は、一般則で埋めず、採用理由、撤回条件、単一採用、置き換える規律、技術的制約の実証を project ADR に残す。
5. 依頼が許可する作業と focused check を実行する。読み取り専用の監査やレビューでは、報告を応答で返し、依頼されていない報告 file を作らない。判定や変更ごとに、根拠とした標準の file と該当規律を記録する。標準内の矛盾は root README の裁定規則に従い、黙って読み替えない。
6. 実装または構造改善では、完了前に変更の経緯を持たない独立した reviewer context で照合する。subagent が利用できなければ新しい独立 session を使う。どちらも利用できない場合は自己照合を行うが、独立レビュー済みとは主張せず、その制約を報告する。

### 監査とレビュー

監査とレビューでは、対象 project の ADR から準拠 commit を特定した後、次の前処理を完了するまで対象 source の意味監査を始めない。

1. `git -C <standard-root> show <commit>:README.md` と `git -C <standard-root> show <commit>:process/<mode>.md` で root README と選択した process を読み、根拠にした commit、file、見出しを内部台帳へ記録する。
2. 記録 commit の `process/audit.md` にある severity 対応を一字一句そのまま内部台帳へ写し、その対応だけを使う。skill の現行本文、記憶、過去の判定例で severity を補足または引き上げない。
3. 選択した process の全 step を evidence ledger へ列挙し、状態を pending にする。各 step は実施済み、理由を添えた見送り、実行不能のいずれかへ更新し、根拠 file と確認結果を添える。tool output または直接の読取証拠がない step を実施済みにしない。

前処理後は、観測した実装だけを違反の根拠にする。コメントに書かれた意図だけで未実装の挙動を認定しない。依存方向表の「依存してよい先」は許可された辺であり、その依存先がないこと自体は方向違反ではない。
監査の早い step で違反を見つけても、後続の照合を打ち切らない。依頼で定めた範囲の全 step を実施済み、理由を添えた見送り、実行不能のいずれかへ消し込むまで監査を終えない。
最終応答の前に「確認予定」「後で確認」「未処理」を探す。残る項目はその場で実施するか、理由を示した見送りまたは実行不能へ変え、pending のまま完了と書かない。
必須の folder が欠けていても、現存する source の意味監査を止める理由にはしない。たとえば worker の配置が不正でも、その source を concerns の並行処理規律と languages の実現規律へ照合する。対象 artifact 自体が存在しない確認だけを実行不能にし、folder 欠落を理由に領域全体を見送らない。
同じ source が複数の完了条件または禁止事項に当たる場合は、最初の違反だけで照合を止めず、該当する規律を全て確認する。指摘数を報告する場合は、重複排除後の列挙を数え、内訳と合計を一致させる。

## 報告

- 結論を先に置き、実施したモード、対象範囲、根拠にした root `README.md`、選択した process file、参照した規律、実測した検証、未確認事項を示す。
- 監査とレビューの指摘は、severity、対象 file と該当箇所、対応する標準の規律を添える。
- 監査の severity は `process/audit.md` の対応をそのまま使い、自己判断で引き上げない。
- 標準本文の引用は判定に必要な短い箇所だけにする。読了の証明として長文を複製しない。
- 実行できない検証は合格とせず、理由と実施した次善の確認を分けて書く。

## 関連

- `standard-update` — 標準本文の更新。
- `standard-audit` — 標準そのものの読み取り専用監査。
