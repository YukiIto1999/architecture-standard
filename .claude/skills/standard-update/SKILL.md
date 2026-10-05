---
name: standard-update
description: architecture-standard 自体へ規律、採用、構造、手順、外部知見、project の改訂提案を取り込む依頼では必ず使う。原則・概念・言語規則・構造・採用・手順、標準の file、標準運用 skill を追加または修正する依頼、「標準へ反映」「標準を直す」「標準へ追記」「standard-update skill を修正」という依頼が該当する。対象 path が既知でも未特定でも、調査や編集に着手する前に、この skill を必ず使う。対象 project への適用には standard-apply、読み取り専用監査には standard-audit を使う。
---

# standard-update

新しい観測、反証、視点を使い、多数のプロジェクトの品質を支える標準を、より正確で一貫し、誤解しにくい判断基準へ更新する。
入力は転記する文章でも既存標準へ従属する要求でもなく、現行の概念モデルと表現を再評価する材料として扱う。
標準の単一性、層間 MECE、安全な変更と検証は、この目的を満たす制約であり、変更量の少なさを目的にしない。
この skill は標準の6領域と材料置き場 docs を更新する運用入口であり、`process/` の標準本文ではない。
下の領域別書式は更新対象の標準本文だけに適用する。

## 領域

- `principles/` — 言語に依存しない設計原則。なぜを所有する。
- `concerns/` — 言語非依存の24概念。effect・concurrency・dependency・types・context-propagation・persistence・caching・migration・transaction・messaging・workflow・authentication・authorization・privacy・security・secrets・audit-trail・observability・configuration・resilience・performance・lifecycle・experience・accessibility。複数の部または全層へ効く規律を所有する。
- `structure/` — 一つの部の境界、中身、依存方向を所有する。検証技法の選択、性質から型・静的検査・実行テスト・計測への割当、mutation・coverage・実行範囲は `structure/tests/methods.md` が所有する。
- `tools/` — 言語横断の開発道具(build)、自運用基盤(platforms)、外部 Web サービス(services)の採用と共通基準を所有する。
- `languages/` — rust・csharp・typescript の言語 ecosystem。6実現軸の規律、全域規律 conventions、その言語 ecosystem の採用物を所有する。
- `process/` — bootstrap・recovery・design・implementation・refactoring・review・audit・migration・verification・release・drill の順序と確認点を横断的に所有する。
- `docs/` — 調査と判断の材料であり、標準本文には含めない。

## 参照経路

既知の正本 path は直接読み、再発見の検索をしない。
所有者が不明なら root `README.md` の領域表と台帳から候補を探す。
外部知見と意味を変える改訂では、直接所有者の発見を探索の終了とせず、手順2の意味的影響範囲を辿る。
配置、参照方向、標準の改訂と適用の違いは root `README.md` で確認する。

意味の比較と裁定には [normative quality](references/normative-quality.md) を使う。
配置または領域書式を決めるときだけ、該当する `references/{principles,concerns,structure,tools,process}.md` を読む。
languages の配置と書式は `references/tools.md` が所有する。
検証の重複排除には [verification duplication](references/verification-duplication.md) の反例と割当の点検を追加するが、探索範囲は一般経路と同じにする。
reference の答えを得たらその説明の先回り読取は止めるが、標準本文の影響追跡は未解決の関係がなくなるまで続ける。
全 reference の一括読取や、目的のない全域検索をしない。

## 手順

### 1. 入力を分解する

入力から主張、根拠、例、決定を分け、主張ごとに source locator と検証可能な内容を記録する。
入力の主張は未採用の候補であり、記事の権威や現行標準との一致だけで採否を決めない。
主張の中心、対象、適用範囲、前提、判断軸、因果関係、強制力、例外、失敗時の意味、実装と検証への帰結を既存本文と比較する。
意味の関係と、変更するかという裁定は分ける。
一次本文がなく確定できない主張は、既知の意味と不足証拠を分け、採用済みとも誤りとも断定しない。
標準の保守窓口へ届いた project の改訂提案も同じ比較で扱う。
typo、リンク、見出し、registry の機械修正では、変更前の Git 履歴、参照先の正本、または既存 registry から期待値を特定してから編集する。自然言語としてもっともらしい類義語を推測して置き換えない。候補が一致しなければ無変更とし、曖昧さを報告する。

### 2. 意味を比較し影響範囲を辿る

直接所有者は探索の起点であり、編集範囲の上限ではない。
root `README.md` の領域表と配置規則に照らし、既存の知識と変更理由を所有する箇所を起点にする。
一つの主張が複数層にまたがる場合は側面ごとに所有者を分け、同じ規範は複製しない。

`references/normative-quality.md` に従い、一致、包含、部分包含、異なる主軸、補完、矛盾、新規の関係を判定する。
同じ結論でも理由や境界が違えば、その差が将来の判断を変えるか調べる。
意味が包含されていても、初見の開発者と agent が主軸、判断軸、要求行動、違反を正しく読み取れるか、弱い読みと強い読みを具体例で試す。
skill や reference の説明で標準本文の欠落を補わない。

主張ごとに、起点、関係、確認先、読取証拠、解決状態を短い影響表へ記録する。
次の関係を点検し、関係がある領域では具体的な本文へ辿り、関係がなければ理由を記録する。

- 上位の価値、判断基準、前提との整合を調べる。
- 同一概念の他の規律、用語、重複する正本、他 concern との境界を調べる。
- structure の責務と依存方向、languages と tools の下位実現を調べる。
- process の確認点と検証への割当、運用 Skill の裁定と停止条件を調べる。

明示参照と逆参照だけでなく、同じ概念や因果関係を扱う未接続の規律も、台帳と意味検索で発見し、本文で裏付ける。
検索が必要なときは問いと概念を固定し、既知の語の一致検索だけで影響範囲を定めない。
上位へ辿ることを所有者の移動と混同せず、一般化できることだけで移動しない。
新しい関係が見つかったら影響表を拡張し、今回の知見と同じ判断、概念モデル、因果関係の欠陥は変更候補に含める。
偶然見つけた因果関係のない問題は混ぜない。
探索は、関係する各領域を本文で確認し、未解決の依存と反例がなくなったときに閉じる。
未確認の関係は確認済みにせず、裁定を変えうる不足として残す。

### 3. 必要な根拠を調べる

外部事実、版依存の仕様、製品の採用判断を変更する場合だけ外部調査を行う。
一次資料を含む独立した2源以上で確認し、snippet だけで断定せず、`docs/research/` に URL、確認日、判断への影響を残す。
library / framework の仕様は利用可能な library documentation の入口を先に使い、Web 全般は `web-research` の入口を使う。
外部事実を含む裁定を終える前に、主張ごとに本文を取得できた独立2源があるか点検する。1源しかない主張は確認済みにせず、更新を見送って未確認事項へ残す。
入力本文を観測として用いることと、その外部の経験的主張を事実として採用することは分ける。
本文と現行規律から作れる反例や論理的な不整合は内部証拠で評価でき、外部事実を追加しない概念や表現の改善を、独立2源の不足だけで止めない。

typo、リンク、書式、正本と参照の同期だけを直し、外部事実や採用判断を変えない場合は外部調査を行わない。
調査の入口が利用できなければ、利用可能な手段で公式一次資料を直接確認する。
必要な一次資料を取得できなければ、その外部事実に依存する裁定を確定せず、阻害要因を報告する。
一次資料に記載がないことだけを、機能が存在しない証拠にしない。確認できたのが文書化の有無だけなら「文書化を確認できない」と報告し、非対応や実現不能と断定しない。

### 4. モデルと改善方法を選ぶ

現行標準も評価対象にし、衝突そのものを不採用理由にしない。
外部主張の誤り、現行規律の誤り、前提または抽象度または適用領域の違い、概念の分解や所有者の誤り、上位原則からの再構成を、証拠と反例で比較する。
適用時の層の優先順位を、改訂時の現行規律の正しさの証明に使わない。
採用モデルは、全体整合性、説明力、将来の判断の一貫性、プロジェクト品質への帰結から選ぶ。

モデルを決めた後、無変更、文章修正、意味拡張、接続の修正、概念の再分解、所有者移動、構造変更、Skill の手順変更から、根本原因を解消する方法を選ぶ。
局所の追記で一応満たせても、責務混在や誤読を残す構造案があるなら、再分解や再配置と比較する。
すべての変更形を機械的に列挙せず、原因に対して実質的に異なる案と、その採否を記録する。
最初の十分な案で打ち切らず、変更量を採否の目的にしない。
構造変更自体にも価値を置かず、既存が意味、表現、影響先のすべてで十分なら無変更にする。

編集前に、主張と既存本文の差、原因、採用モデル、影響先、変更する所有者と参照、検証、範囲外を変更契約として記録する。
影響追跡で新しい欠陥が立証されたら、因果関係を示して契約を更新する。
意味を変えた場合は、対象、義務、違反、判定手段の差を残し、後から文章修正へ読み替えない。
新しい reference は反復する詳細な判断、新しい script は決定的な不変条件、新しい eval は未観測の失敗境界を所有する場合だけ作る。

### 5. 領域の書式で書く

- principles: 原則ごとのフォルダ。README は H1 直下のリードと `## 規律` の台帳、規律ファイルは規律の H2 と `要求/根拠/完了条件/禁止事項/行動`、必要な場合だけ例。README に `## 概要` と `## 参照` は置かない。
- concerns: 概念ごとのフォルダ。README は `## 概要`・`## 規律` の台帳・`## 参照`、規律ファイルは規律の H2 と必須5節、必要な場合だけ例。
- languages の軸 file: `## 概要`、規律ごとの必須5節、必要な場合だけ例、末尾の `## 参照`。
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

### 6. 配線と台帳を更新する

concerns を横断規律の正本、structure を参照側にする。
概念の増減では root `README.md`、`concerns/README.md`、`.claude/skills/standard-update/SKILL.md`、`references/concerns.md` を同期する。
tools の区分や採用名を変えた場合は `tools/README.md`、languages の言語 ecosystem や採用物を変えた場合は `languages/README.md` と該当 ecosystem の台帳を同期する。いずれも領域一覧と該当 reference を同期し、`scripts/naming-registry-check.mjs` の動的 registry で検査する。永続する別の registry file は作らない。

### 7. 検証して閉じる

充足済みで無変更と裁定した場合は、本文用 verifier を実行しない。次を報告する。

- 主張と既存文の意味の関係、直接所有者、意図した読みを報告する。
- 合理的な別解釈と、それを否定する標準本文を示す。
- 影響表の確認先と証拠、関係しない領域の理由を示す。
- 規範から実装と検証までの連鎖を示す。
- 未確認事項と、裁定を変える可能性を示す。

不採用の場合は、現行規律との衝突だけでなく、前提、根拠、反例、品質への帰結から採用モデルが優れる理由を示す。
根拠不足で見送る場合は、欠けている証拠と、それが変える裁定を報告する。
変更がある場合は次の検証を行う。

編集対象は変更契約の因果的な範囲へ閉じ、同じ概念の欠陥を残すために一ファイルへ限定しない。
変更後は影響表を再照合し、意味、用語、所有者、参照方向、下位実現、確認点と Skill の運用が採用モデルに一致することを確認する。
削除した正本の参照と旧い判断を残さず、各影響先を変更したか、既存で一致するか、不足証拠があるか明示する。

変更箇所だけを直接検査する linter、test、構造検査があれば focused check として先に実行する。対応する機械検査がなければ、対象 file と直接参照の差分照合を行い、機械検査済みとは扱わない。
次に `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/verify.sh` を repository root から実行する。
失敗した場合は原因を直し、同じ検査を再実行して PASS になるまで完了としない。

本 skill、`references/*.md`、`scripts/*`、`evals/*.json` を変更した場合は、次も実行する。

```bash
bash "${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/verify-test.sh"
bash "${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/skill-package-check.sh"
```

`skill-package-check.sh` の役割と、変更面ごとの model eval の範囲は [evaluation](references/evaluation.md) に従う。

最後に変更 file を standard-audit の scoped audit で照合する。
subagent が利用できれば変更の経緯を持たない reviewer に依頼し、利用できなければ独立 session、どちらも利用できなければ自己監査へ代替する。代替時は独立監査済みと主張しない。
最終応答の変更数、文数、file 数、検証結果は実際の diff と command output に照合する。差分と一致しない要約を完了報告へ残さない。

## 実行環境

検証 script は Bash、Git、ripgrep (`rg`)、fd、awk、sed、find、coreutils、Node.js を必要とする。
不足時は検査を skip せず失敗する。
fallback evaluator は、これらに加えて Claude Code CLI を必要とする。
skill の場所が current directory にない host では、host が与える `CLAUDE_SKILL_DIR` を使う。
`CLAUDE_SKILL_DIR` がない場合は、repository root から `.claude/skills/standard-update` を skill root として使う。

## 不変条件

- 一つの規律に一つの正本を持たせ、他は参照に絞る。
- 標準側に例外や project 固有の分岐を作らない。逸脱は利用側 project の決定の記録へ送る。
- 要求範囲を作り切り、未要求の投機を追加しない。
- 標準本文だけで遵守を判定できる状態にする。
- 原因を解消する変更と影響先を閉じ、因果関係のない変更や不要な機構を増やさない。
- 検証していない結果を PASS や完了として報告しない。

## 関連

- `references/{principles,concerns,structure,tools,process}.md` — 領域固有の配置、根拠、書式、MECE 点検。`tools.md` は tools と languages の両方を所有する。
- `references/normative-quality.md` — 意味の関係、表現の反証、モデル選択、無変更の裁定。
- `references/verification-duplication.md` — 検証手段の重複排除に固有の反例と下位割当の点検。
- `references/evaluation.md` — product 検査の役割と model eval の範囲。
- `scripts/verify.sh` — 標準本文の機械検査。
- `scripts/verify-test.sh` — verifier の回帰検査。
- `scripts/skill-package-check.sh` — 実作業用の frontmatter、5 skill の eval schema、script 構文の検査。
- `scripts/skill-test.sh` — 評価対象へ公開しない、期待解答と mutation を含む evaluator 回帰検査。
- `scripts/run-task-evals.mjs` / `scripts/run-trigger-evals.mjs` — skill-creator を使えない host の隔離評価入口。
- `scripts/discipline-sections.awk` / `scripts/naming-registry-check.mjs` / `scripts/verbatim-overlap.mjs` / `scripts/heading-citation-check.mjs` — verifier が呼び出す内部実装。個別の公開入口にはしない。
- `evals/evals.json` / `evals/trigger-evals.json` — task 品質と発火境界の評価集合。
- `standard-audit` — 標準自体の読み取り専用監査。
