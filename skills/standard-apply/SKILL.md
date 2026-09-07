---
name: standard-apply
description: architecture-standard 以外の標準には使わず、「別 repository の社内コーディング標準」が明示された依頼は対象外である。この repository で「architecture-standard に従って」「標準に従って」「標準準拠」「標準を適用」「structure の標準に合わせて」「現在の標準を基準に」と指定された対象 project または repository の作業では、対象 path や symbol が未特定でも、調査や編集に着手する前に、この skill を必ず使う。特に「標準に従ってこの worker の設計」「project ADR に残す判断を分ける」のように対象確認が必要な設計依頼や、「architecture-standard を使って staged diff をレビュー」のような読取依頼でも、対象を探す前にこの skill を呼び出す。この skill は対象確認後の参考資料ではなく、未特定事項を含む作業の最初の入口である。新規構築、意味回収、監査、移行、設計、実装、refactoring、構造改善、review、staged diff review、バイブコーディング由来システムの構造再生が該当する。architecture-standard 自体の変更には standard-update、自己監査には standard-audit を使う。
---

# standard-apply

標準を project へ適用する入口である。
手順と判定基準の正本は標準本文に置き、この skill へ転写しない。

## 開始ゲート

対象 project へ最初の tool call を行う前に、次の入口を一つだけ選ぶ。

| 入力の入口 | 最初の対象 project 操作 | この作業で使わない探索 |
|---|---|---|
| exact file path がある | その file を Read で直接読む | 対象 project への Glob、fd、directory 一覧、`git ls-files` |
| symbol だけがある | その exact symbol の Grep で一つの定義候補へ絞り、一致 file を読む | 対象 project への Glob、directory 一覧 |
| project root だけで system-wide recovery または audit | 後述の条件を満たす場合だけ `<target-project-root>/**/*` を一回 Glob する | 二回目の Glob、別の列挙手段 |

選択直後の最初の対象 project 読取または探索は、表の操作でなければならない。標準本文は手元の `<standard-root>` にある現在の規範文書を根拠とし、対象 project の入口を再発見する `README.md` や `target-project/*` の Glob、`pwd`、directory 一覧は使わない。
exact file path を与えられた作業では、project ADR、caller、state、test の確認にも Glob を使わない。path 未指定の Glob は標準と対象 project の双方へ一致しうるため、標準側だけの探索としても使わない。先に Glob してから exact path へ戻っても、この開始ゲートを満たしたことにならず、調査または設計を完了と報告しない。
project root だけを与えられた system-wide recovery または audit では、最初の対象 project 探索を文字どおり `<target-project-root>/**/*` の一回にする。`README.md` や `<target-project-root>/*` を先に試してはならない。二回目を実行した場合は後の結果を正当化に使わず、調査を完了と報告しない。

### 閉じた対象調査経路

exact source path を与えられ、受入条件に completion、state、success または failure がある設計では、最初の対象 project 操作の前に [target scoping](references/target-scoping.md) を読み、そこに記載した経路と限定 Grep だけを使う。

## 前提

- この skill がある repository を標準、依頼で示された repository を対象 project とする。
- この skill の所在（`skills/standard-apply/SKILL.md`）から二段上の親 directory を `<standard-root>` として固定する。`pwd` や `git rev-parse` で standard root を再発見しない。対象 project を current directory にした Git 操作や特定マシンのローカル絶対パスと混ぜない。
- 標準本文は常に `<standard-root>` にある現在の規範文書（`README.md`、`principles/`、`concerns/`、`process/`、`structure/`、`tools/`）を参照する。標準の過去版を Git 履歴から掘り出して判断基準にせず、対象 project に記録された標準の版も基準にしない。
- 標準本文は編集しない。標準側の不備は file と該当箇所を報告し、修正は standard-update へ渡す。

## 参照経路

対象 project の調査を閉じた後、`<standard-root>/README.md` と選んだ process を最初の標準本文として読む。対象 project の exact file は開始ゲートに従って先に読んでよい。
root の manifest は既定名の exact path を直接読み、標準の directory link はその `README.md` を直接読む。これらの発見に Glob を使わない。Grep が失敗した場合も find、Glob、directory 一覧へ切り替えず、未確認にする。
それ以外の本文を読む前に、その file が答える次の判断または照合項目を内部チェックリストへ一つ記録する。
その判断を変えうる直接の参照先だけを読み、答えを得た参照経路はそこで止める。
網羅した安心を得るための directory 列挙、同階層の一括読取、使わない規律の先回り読取は行わない。
選んだ process または依頼が全域照合を要求する場合は、その要求自体を各参照経路の根拠にする。
process が現在のモードの順序または確認点として無条件に `従う` と定める link は、変更契約の必須条件として読む。`変更が触れる`、`採用する` など適用条件がある link は、条件に当たる対象と違反しうる結果を示せる場合だけ読む。
読んだ concern から別 concern への link も無条件に再帰しない。queue、過負荷、retry、deadline、lifecycle など link 先が所有する対象が変更契約に含まれる場合だけ読む。並行上限と子処理完了だけの設計では、それらが観測されない限り resilience へ広げない。
process の全 step を消し込むことと、条件付き link を全て読むことを混同しない。変更契約から不適用と判断できる条件付き step は、process 本文と観測した対象を根拠に見送り、参照先を読んで見送りを補強しない。
directory への link は同階層の列挙を許可しない。具体的な file の特定が必要なら、その directory の `README.md` を台帳として一度だけ読み、一つに絞る。台帳から絞れなければ推測で探索せず未確認事項にする。
ここまでの参照制限は標準本文に適用する。対象 project は、選んだ process の判断に必要な実行経路、caller、consumer、state、設定、テスト、実測結果を根拠が揃うまで読み、一つの file や検索結果で全体を代表させない。
依頼が対象 project root だけを示し、exact file path、symbol、manifest のいずれからも開始点を固定できず、選んだ process が system-wide な recovery または audit を要求する場合に限り、開始点の発見に Glob を一回だけ許す。pattern は `<target-project-root>/**/*` の一つに固定し、既知名の存在確認、top-level確認、source用とtest用の分割によって複数回実行しない。結果から `.git`、build output、generated artifact、vendor、`docs/decisions/` を Glob 由来の読取候補から除き、必要な source、test、configuration の開始点を固定する。project ADR が system purpose、語彙、state authority または契約を持つ場合は、Glob の結果で発見したことにせず、回収した語を固定した Grep を `docs/decisions/` に限定して別に行い、一致した file だけを読む。二回目の Glob、find、fd、`git ls-files` へ進まず、一回の結果で特定できない関係は未確認にする。Glob 自体が失敗した場合も別の列挙手段へ切り替えない。
対象 project で exact path が分かる入口は直接読む。そこから一度に広域探索せず、現在の主張を確定する caller、consumer、state authority、effect、test の関係を一つ選び、その関係を順方向または逆方向へ一段ずつ追う。変更契約または意味回収の判断を変えない directory、script、隣接 module は列挙しない。
依頼が exact source path を示す場合、対象 project 全体への Glob は使わない。source を直接読み、必要な関係は確認する symbol または参照先を固定した Grep で一つずつ探す。特定できない関係は探索範囲を広げて推測せず未確認にする。project ADR の探索も上で定めた限定 Grep だけを使い、find、Glob、directory 一覧を代替にしない。
exact source path がある条件で Glob を使った場合は参照規律を満たしていないため、その結果で調査または設計を完了せず、exact path からやり直す。

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
4. 標準が決めている事項と project 固有の決定を分ける。標準が沈黙する事項や逸脱は、一般則で埋めず、採用理由、撤回条件、単一採用、置き換える規律、技術的制約の実証を project ADR に残す。
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
