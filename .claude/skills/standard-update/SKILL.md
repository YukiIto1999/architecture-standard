---
name: standard-update
description: architecture-standard 自体へ規律、採用、構造、手順、外部知見、project の改訂提案を取り込む。原則・概念・言語規則・構造・採用・手順を追加または修正する依頼、「標準へ反映」「標準を直す」という依頼では、調査や編集に着手する前に、この skill を必ず使う。対象 project への適用には standard-apply、読み取り専用監査には standard-audit を使う。
---

# standard-update

標準の単一性と層間 MECE を保って更新する。
入力をそのまま転写せず、所有者、根拠、書式、参照、検証を一つの変更として閉じる。
この skill は標準の6領域を更新する運用入口であり、`process/` の標準本文ではない。下の領域別書式は更新対象の標準本文だけに適用する。

## 領域

- `principles/` — 言語に依存しない設計原則。なぜを所有する。
- `concerns/` — 言語非依存の17概念。effect・concurrency・dependency・types・persistence・transaction・messaging・authentication・authorization・observability・privacy・security・configuration・resilience・performance・lifecycle・experience。複数の部または全層へ効く規律を所有する。
- `languages/` — rust、csharp、typescript による上位規律の実現を所有する。
- `structure/` — 一つの部の境界、中身、依存方向を所有する。
- `tools/` — language・stack・build・inspection・services・platforms の6分割で、採用と判断基準を所有する。
- `process/` — bootstrap・design・implementation・refactoring・review・audit・migration の順序と確認点を所有する。
- `docs/` — 調査と判断の材料であり、標準本文には含めない。

詳細は変更する領域に対応する `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/references/{principles,concerns,languages,structure,tools,process}.md` だけを読む。

## 手順

### 1. 入力を分解する

入力から主張、根拠、例、決定を分ける。
project の `docs/revision/` を回収する場合は提案ごとに採否を裁定する。
一次本文がなく内容を確定できない外部主張は、配置と調査課題までに留める。
typo、リンク、見出し、registry の機械修正では、変更前の Git 履歴、参照先の正本、または既存 registry から期待値を特定してから編集する。自然言語としてもっともらしい類義語を推測して置き換えない。候補が一致しなければ無変更とし、曖昧さを報告する。

### 2. 所有者を決める

root `README.md` の領域表を正本にする。
値・なぜは principles、複数の部に効く言語非依存の規律は concerns、特定言語の実現は languages、一つの部の境界と中身は structure、採用と判断基準は tools、作業の順序と確認点は process へ置く。

対象 file と直接の参照先を読んでから、足す、新設、矛盾を解消する、無変更のいずれかを決める。
一つの主張が複数層にまたがる場合は側面ごとに所有者を分け、同じ根拠を重複させない。

### 3. 必要な根拠を調べる

外部事実、版依存の仕様、製品の採用判断を変更する場合だけ外部調査を行う。
一次資料を含む独立した2源以上で確認し、snippet だけで断定せず、`docs/research/` に URL、確認日、判断への影響を残す。
library / framework の仕様は context7 を先に使い、Web 全般は web-researcher を使う。
外部事実を含む裁定を終える前に、主張ごとに本文を取得できた独立2源があるか点検する。1源しかない主張は確認済みにせず、更新を見送って未確認事項へ残す。

typo、リンク、書式、正本と参照の同期だけを直し、外部事実や採用判断を変えない場合は外部調査を行わない。
context7 と web-researcher のいずれかが利用できなければ、利用可能な手段で公式一次資料を直接確認する。必要な一次資料を取得できなければ、外部事実を含む更新を確定せず、阻害要因を報告する。
一次資料に記載がないことだけを、機能が存在しない証拠にしない。確認できたのが文書化の有無だけなら「文書化を確認できない」と報告し、非対応や実現不能と断定しない。

### 4. 領域の書式で書く

- principles: H1 直下のリード、規律ごとの H2、`要求/根拠/完了条件/禁止事項/行動`、必要な場合だけ例。`## 概要` と `## 参照` は置かない。
- concerns / languages: `## 概要`、規律ごとの必須5節、必要な場合だけ例、末尾の `## 参照`。
- structure: 導入の参照文、folder tree、単位表または依存方向表、topical な見出しからなる layout 書式。必須5節を持ち込まない。詳細は `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/references/structure.md` に従う。
- tools: 用途、採用、判断基準、撤回条件の4行 entry。
- process: 導入の参照文、`## 順序`、`## 確認点`、`## 範囲外`。必須5節を持ち込まない。

要求、完了条件、禁止事項は判定可能な表現にする。
例は次の順で書く。

1. 例の言語を特定し、その言語の `languages/<language>/conventions.md` を読む。擬似コードなら言語固有の構文を使わない。
2. 編集前に、意図的に違反させる項目と、例に表示する規律対象の構文を特定する。
3. 差と帰結はコードフェンス外の本文へ置き、コード例へ説明のコメントを足さない。ドキュメントコメント、採らなかった理由、禁止するコメントそのものを示す例では、規律の対象であるコメントだけをコード内に残す。
4. コード例は判定に必要な部分だけを示す断片とする。例の主題でない import、ドキュメントコメント、周辺の宣言は表示を省けるが、実コードで不要であるとは示さない。表示する構文は、意図的な違反を除き、conventions の規律を例の中でも満たす。
5. ドキュメントコメントを表示する場合は、目的と、宣言が持つ引数・型引数・戻り値・値・副作用・失敗条件の該当項目を、望ましい例と意図的な悪例の両方に記す。引数・型引数・戻り値・値の該当は説明の自明さでなく宣言の署名から決め、引数があれば param、型引数があれば typeParam、非 void の戻り値があれば returns、値を公開するメンバなら value を省かない。conventions が専用のタグまたは節を定める項目はその記法を使い、定めない項目は本文で述べる。別の例の完全な契約で代替しない。

編集の直前に、ドキュメントコメントを表示する各宣言の署名と param・typeParam・returns・value を一対一で照合する。その後に、対象言語の現行版で成立し、例の主題でない違反が残っていないことを確認する。
既存 file の文体に合わせ、一文一義で書く。絵文字、進捗語、不要な前置き、人名による権威づけを標準本文へ入れない。

### 5. 配線と台帳を更新する

concerns を横断規律の正本、structure を参照側にする。
概念の増減では root `README.md`、`concerns/README.md`、`.claude/skills/standard-update/SKILL.md`、`scripts/verify.sh` を同期する。
tools の分割や採用名を変えた場合は `tools/README.md`、`.claude/skills/standard-update/SKILL.md` の領域一覧、該当 reference を同期し、`scripts/naming-registry-check.mjs` の動的 registry で検査する。永続する別の registry file は作らない。

### 6. 検証して閉じる

無変更と裁定した場合は本文用 verifier を実行せず、所有者、既存規律、裁定根拠、未確認事項だけを報告する。変更がある場合は次の検証を行う。

変更箇所だけを直接検査する linter、test、構造検査があれば focused check として先に実行する。対応する機械検査がなければ、対象 file と直接参照の差分照合を行い、機械検査済みとは扱わない。
次に `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/verify.sh` を repository root から実行する。
失敗した場合は原因を直し、同じ検査を再実行して PASS になるまで完了としない。

本 skill、`references/*.md`、`scripts/*`、`evals/*.json` を変更した場合は、次も実行する。

```bash
bash "${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/verify-test.sh"
bash "${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/skill-test.sh"
```

変更の種類に応じて model eval の範囲を決める。

- `scripts/*` または `references/*.md` だけを変更し、SKILL.md と eval を変えない場合は、上の回帰検査だけを行い、model eval は実行しない。
- SKILL.md の instruction を変更した場合は、skill-creator の評価手順を使う。変更した instruction の入力と観測可能な結果を prompt と expectation が直接使う task だけを `old-skill` と `with-skill` の2条件で隔離実行する。変更された file を監査対象に含むだけの task や、同じ skill を使うだけの task は選ばない。expectation、最終応答、tool event、diff、tracked / ignored status、実行 error、時間、token を比較する。新規 skill で旧版がない場合だけ `without-skill` を比較対象にする。
- `evals/evals.json` だけを変更した場合は、変更した task を `with-skill` で実行する。現行 instruction の不足が失敗として再現した後に instruction を変更し、その段階で `old-skill` と `with-skill` を比較する。
- description または `evals/trigger-evals.json` を変更した場合は、`scripts/run-trigger-evals.mjs` で `trigger-evals.json` の全 query を実行する。3 skill を同時に置いた条件で expected skill または非発火を測り、Skill tool の完全な入力、観測中の実行 error、発火先を記録する。
- release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較と full trigger eval の両方を行う。それ以外は変更面ごとの上記範囲に限定する。instruction と `evals/trigger-evals.json` の変更を組み合わせた場合は、影響 task の2条件比較と full trigger eval をそれぞれ行い、全 task や `without-skill` へ広げない。

task eval は本 task の完遂を、trigger eval は発火先だけを測る。起動成功を PASS とせず、別 context の grader が expectation ごとの成否と event または成果物の根拠を `grading.json` に残す。複数条件を比較した場合は、対象 task の集計を `benchmark.json` に残す。隔離 evaluator が実行できなければ model eval 完了とは扱わず、阻害要因を報告する。

最後に変更 file を standard-audit の scoped audit で照合する。
subagent が利用できれば変更の経緯を持たない reviewer に依頼し、利用できなければ独立 session、どちらも利用できなければ自己監査へ代替する。代替時は独立監査済みと主張しない。

## 実行環境

検証 script は Bash、Git、ripgrep (`rg`)、fd、awk、sed、find、coreutils、Node.js を必要とする。
不足時は検査を skip せず失敗する。
fallback evaluator は、これらに加えて Claude Code CLI を必要とする。
skill の場所が current directory にない host では、host が与える `CLAUDE_SKILL_DIR` を使う。
`CLAUDE_SKILL_DIR` がない場合は、repository root から `.claude/skills/standard-update` を skill root として使う。

## 不変条件

- 一つの規律に一つの正本を持たせ、他は参照に絞る。
- 標準側に例外や project 固有の分岐を作らない。逸脱は利用側 project の ADR へ送る。
- 要求範囲を作り切り、未要求の投機を追加しない。
- 標準本文だけで遵守を判定できる状態にする。
- 検証していない結果を PASS や完了として報告しない。

## 関連

- `references/*.md` — 領域固有の配置、根拠、書式、MECE 点検。
- `scripts/verify.sh` — 標準本文の機械検査。
- `scripts/verify-test.sh` — verifier の回帰検査。
- `scripts/skill-test.sh` — 3 skill の契約と eval schema の回帰検査。
- `scripts/run-task-evals.mjs` / `scripts/run-trigger-evals.mjs` — skill-creator を使えない host の隔離評価入口。
- `scripts/discipline-sections.awk` / `scripts/naming-registry-check.mjs` / `scripts/verbatim-overlap.mjs` — verifier が呼び出す内部実装。個別の公開入口にはしない。
- `evals/evals.json` / `evals/trigger-evals.json` — task 品質と発火境界の評価集合。
- `standard-audit` — 標準自体の読み取り専用監査。
