---
name: standard-apply
description: architecture-standard 以外の標準には使わず、「別 repository の社内コーディング標準」が明示された依頼は対象外である。この repository で「architecture-standard に従って」「標準に従って」「標準準拠」「標準を適用」「structure の標準に合わせて」「現在の標準を基準に」と指定された対象 project または repository の作業では、対象 path や symbol が未特定でも、調査や編集に着手する前に、この skill を必ず使う。特に「標準に従ってこの worker の設計」「project ADR に残す判断を分ける」のように対象確認が必要な設計依頼や、「architecture-standard を使って staged diff をレビュー」のような読取依頼でも、対象を探す前にこの skill を呼び出す。この skill は対象確認後の参考資料ではなく、未特定事項を含む作業の最初の入口である。新規構築、意味回収、監査、移行、設計、実装、refactoring、構造改善、review、staged diff review、バイブコーディング由来システムの構造再生が該当する。architecture-standard 自体の変更には standard-update、自己監査には standard-audit を使う。
---

# standard-apply

標準を project へ適用する入口である。
手順と判定基準の正本は標準本文に置き、この skill へ転写しない。

## 対象の入口

対象 project の既知の入口から始める。exact file path があればその file を直接読む。symbol だけが分かる場合は、利用可能な LSP で定義と参照を確認し、使えなければ native search で探す。project root しか分からない場合は README や manifest の宣言を確認し、必要な source と test の範囲を絞る。

既知の path を再発見するための列挙はしない。探索が必要な場合は target root と確認する関係を明示し、ignore 境界を維持する。空の検索結果や初回の候補集合だけで、project 全体に契約、writer、test が存在しないとは判断しない。

受入条件に completion、state、success、failure など意味と authority の確認が必要な語がある設計では、[target scoping](references/target-scoping.md) に従って対象の根拠を追う。

## 前提

- この skill がある repository を標準、依頼で示された repository を対象 project とする。
- この skill の所在（`skills/standard-apply/SKILL.md`）から二段上の親 directory を `<standard-root>` として固定する。`pwd` や `git rev-parse` で standard root を再発見しない。対象 project を current directory にした Git 操作や特定マシンのローカル絶対パスと混ぜない。
- 標準本文は常に `<standard-root>` にある現在の規範文書（`README.md`、`principles/`、`concerns/`、`structure/`、`tools/`、`languages/`、`process/`）を参照する。標準の過去版を Git 履歴から掘り出して判断基準にせず、対象 project に記録された標準の版も基準にしない。
- 標準本文は編集しない。標準側の不備は file と該当箇所を報告し、修正は standard-update へ渡す。

## 参照経路

`<standard-root>/README.md` と選んだ process を読み、今回の判断に必要な規律へ進む。対象 project の調査と標準本文の照合は、互いに必要な根拠を確認しながら進める。

- 標準本文を追加で読む前に、その file が答える判断または照合項目を定める。答えが得られた参照経路はそこで止め、使わない規律を先回りして読まない。
- process が無条件に `従う` と定める link は必須条件として読む。`変更が触れる`、`採用する` などの条件付き link は、今回の対象が条件を満たす場合だけ読む。directory link はその README を入口にする。
- concern から別 concern の link へ無条件に再帰しない。queue、過負荷、retry、deadline、lifecycle など、その規律の対象が変更契約に含まれるかで判断する。process の全 step を消し込むことと、条件付き link を全て読むことを混同しない。
- 依頼または process が全域照合を要求する場合は、その要求を探索範囲の根拠にする。局所変更の参照節約を、全域監査や対象 project の調査不足へ転用しない。

対象 project は README、manifest、直接の参照先を手掛かりに、caller、consumer、state authority、writer、effect、test、decision record を一段ずつ追う。宣言された置き場を優先するが、最初の検索で見つからなければ、観測した別名、公開 route、返却値、型などから必要な範囲だけ再探索する。決定の記録の正本の置き場は最上位 README の宣言で確認する。宣言がなければ置き場と契約の authority は Unknown とし、他の場所から読めた記録を正本へ昇格させない。

探索の完了は tool の綴り、検索回数、決め打ちの directory 名では判定しない。判断を左右する主張ごとに根拠と確認範囲が示せたら止める。追加の探索で解消できる不足は追い、利用可能な資料では確定できない契約だけを Unknown として残す。未確認の関係を推測で埋めない。

## 作業境界

設計、実装、構造改善、移行では、設計本文または編集の前に [change contract](references/change-contract.md) を読み、変更契約と実現段を固定する。
どのモードでも、固定した変更契約の条件へ直接結びつかない設計要素、file、型、抽象、設定、依存、fallback を追加しない。
現在のモードで実測できる条件を確かめ、未実装と未実行の条件を分けて報告した時点で止める。

## 手順

1. 標準の `README.md` を読み、依頼をモードへ写像する。新規構築=`process/bootstrap.md`、既存システムの意味回収=`process/recovery.md`、監査=`process/audit.md`、移行=`process/migration.md`、設計=`process/design.md`、実装=`process/implementation.md`、構造改善=`process/refactoring.md`、レビュー=`process/review.md`、release と配備=`process/release.md` である。検証の実行は、どのモードからも `process/verification.md` に従う。構造再生の複合依頼は recovery を読み取り専用で先に完了し、確定した意味だけを後続モードへ渡す。
2. 選んだ process 本文を読み、参照経路の規則に従って、対象範囲の判定に必要な本文だけを読む。記憶、見出し、一般的なベストプラクティスで補完しない。
   設計では `process/design.md` の順序1から8と確認点を省略しない。番号付き step または確認点が `従う` と定める直接参照は、対象が小さくても読んで照合する。directory 参照はその `README.md` から一つに絞る。
   並行処理を設計する場合は、子処理の失敗伝播と cancellation を、依頼の受入条件に列挙がなくても標準の必須条件として変更契約へ残す。現行契約が不明なら具体的な継続・停止・戻り値を決めず、未確定の必須条件にする。受入条件外の別件として落とさない。
3. process の順序と確認点を内部チェックリストとして管理し、変更契約を固定する。応答へ全文を転写せず、依頼に関係する進捗、見送り、未確認事項だけを報告する。
4. 標準が決めている事項と project 固有の決定を分ける。標準が沈黙する事項や逸脱は、一般則で埋めず、採用理由、撤回条件、単一採用、置き換える規律、技術的制約の実証を project の決定の記録に残す。
5. 変更契約が許可する作業と focused check を実行する。読み取り専用の監査やレビューでは、報告を応答で返し、依頼されていない報告 file を作らない。判定や変更ごとに、根拠とした標準の file と該当規律を記録する。標準内の矛盾は root README の裁定規則に従い、黙って読み替えない。
6. 実装または構造改善では、完了前に変更の経緯を持たない独立した reviewer context で照合する。subagent が利用できなければ新しい独立 session を使う。どちらも利用できない場合は自己照合を行うが、独立レビュー済みとは主張せず、その制約を報告する。

### 意味回収

recovery では、対象 project を読み始める前に [recovery](references/recovery.md) を読み、根拠状態と意図と変更先を分けた回収表を作る。

### 監査とレビュー

監査とレビューでは、対象 source を読み始める前に [audit and review](references/audit-review.md) を読み、標準本文の前処理と evidence ledger を閉じてから違反を判定する。

## 報告

- 結論を先に置き、実施したモード、対象範囲、根拠にした root `README.md`、選択した process file、参照した規律、実測した検証、未確認事項を示す。
- 監査とレビューの指摘は、severity、対象 file と該当箇所、対応する標準の規律を添える。
- 監査の severity は `process/audit.md` の対応をそのまま使い、自己判断で引き上げない。
- 標準本文の引用は判定に必要な短い箇所だけにする。読了の証明として長文を複製しない。
- 実行できない検証は合格とせず、理由と実施した次善の確認を分けて書く。

## 関連

- `references/change-contract.md` — 設計と編集の変更契約と実現段。
- `references/recovery.md` — 意味回収の根拠状態の分離。
- `references/audit-review.md` — 監査とレビューの前処理と消し込み。
- `references/provenance.md` — 外部知見の出典記録。実行時には読まない。
- `standard-update` — 標準本文の更新。
- `standard-audit` — 標準そのものの読み取り専用監査。
