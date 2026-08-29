---
name: standard-update
description: architecture-standard 自体へ規律、採用、構造、手順、外部知見、project の改訂提案を取り込む依頼では必ず使う。原則・概念・言語規則・構造・採用・手順、標準の file、標準運用 skill を追加または修正する依頼、「標準へ反映」「標準を直す」「標準へ追記」「standard-update skill を修正」という依頼が該当する。対象 path が既知でも未特定でも、調査や編集に着手する前に、この skill を必ず使う。対象 project への適用には standard-apply、読み取り専用監査には standard-audit を使う。
---

# standard-update

標準の単一性と層間 MECE を保って更新する。
入力をそのまま転写せず、所有者、根拠、書式、参照、検証を一つの変更として閉じる。
この skill は標準の6領域を更新する運用入口であり、`process/` の標準本文ではない。下の領域別書式は更新対象の標準本文だけに適用する。

## 領域

- `principles/` — 言語に依存しない設計原則。なぜを所有する。
- `concerns/` — 言語非依存の17概念。effect・concurrency・dependency・types・persistence・transaction・messaging・authentication・authorization・observability・privacy・security・configuration・resilience・performance・lifecycle・experience。複数の部または全層へ効く規律を所有する。
- `languages/` — rust、csharp、typescript による上位規律の実現を所有する。
- `structure/` — 一つの部の境界、中身、依存方向を所有する。検証技法の選択、性質から型・静的検査・実行テスト・計測への割当、mutation・coverage・実行範囲は `structure/tests/methods.md` が所有する。
- `tools/` — language・stack・build・inspection・services・platforms の6分割で、採用と判断基準を所有する。
- `process/` — bootstrap・recovery・design・implementation・refactoring・review・audit・migration の順序と確認点を所有する。
- `docs/` — 調査と判断の材料であり、標準本文には含めない。

## 参照経路

### 検証の重複と割当の固定経路

入力の候補が、検証手段を「同じ性質」とみなして重複排除する言語非依存の判定基準を追加または変更し、特定言語の実現 file 自体の変更を依頼していない場合に限り、次の順序を使う。この固定経路は、その候補の所有者裁定についてだけ下の一般経路より優先する。特定の `languages/*/inspection.md`、tool、または複数の明示 target への変更依頼は、主張と所有者を分けて一般経路で扱う。

1. `README.md`、`structure/tests/methods.md`、`structure/tests/layout.md` を、この順に exact path の Read で直接読む。一つでも読めなければ止める。三つの Read が tool evidence に揃う前に reference または編集へ進まない。
2. 手順1の三つを読んだことを確認してから、`.claude/skills/standard-update/references/normative-quality.md` を exact path で読む。layout を未読のまま reference を読んだ場合は、後から補って編集を続けず、この経路を未完了として止める。
3. 裁定が段4なら、`languages/README.md`、`languages/rust/inspection.md`、`languages/csharp/inspection.md`、`languages/typescript/inspection.md` を、この順に exact path の Read で直接読む。文章上の定義変更または実現機構を変えない変更でも省略しない。各 inspection について `有効な metric / 無効な metric / 無効にする理由 / 上位規範が必須検証へ割り当てた metric` を内部台帳へ記録し、四項目を本文から埋められない file は一致確認済みとしない。二つの metric を別の性質と明記しながら、重複、二重測定、または一本化を理由に片方を無効化している記述は上位判定と矛盾する。たとえば cyclomatic complexity と cognitive complexity を別物と書いた直後に「二重に測らないため cognitive complexity へ一本化する」と続ける文は矛盾であり、同じ指標の重複だと読み替えない。片方だけが標準の表で必須検証へ割り当てられているなら、非採用理由は「他方は標準の必須検証へ割り当てられていない」とだけ書く。その metric が誤判定する、劣る、不要であるという未検証の品質判断へ置き換えず、別性質であるだけで両方を必須化しない。同じ規律の行動に「複雑度を一つへ一本化する」のような総称が残る場合も、採用した具体的な metric だけを測る文へ同期する。最終報告では各言語を「同一指標だった」と一括せず、編集要否を決めた metric と現行理由を file ごとに示す。
4. 上位の判定基準を変更するなら `structure/tests/methods.md` を編集する。reference だけにある用語を持ち込まず、編集前に同じ節で使われていた標準本文の語彙で書く。本文には、要求・禁止事項から導く非空の全適用集合、集合の一致と合否の双方向含意、不一致・適用不能・一方だけ不合格なら両方を残すこと、反例未発見だけでは同一にしないこと、実装欠陥・更新漏れだけでは別性質にしないことを全て明記する。一つでも欠ければ編集を完了としない。手順3で下位実現との矛盾を確認した場合だけ、矛盾する exact inspection file も同じ変更契約で同期する。矛盾がなければ下位 file を編集しない。編集後は `structure/tests/methods.md` と、編集した場合だけその exact inspection file を Read し直し、用語の存在確認にも Grep を使わない。次に `git diff -- structure/tests/methods.md` を一回実行し、inspection file も編集した場合だけ同じ command の末尾にその exact path を加える。この exact diff を最終 reviewer へ渡す差分とする。最後に exact path の `.claude/skills/standard-update/scripts/verify.sh` を実行する。最終報告の変更先も `structure/tests/methods.md` と正確に書き、path を組み替えない。

この経路では開始から最終報告まで Glob と Grep、`principles/verification.md`、`references/structure.md`、script directory の列挙を使わない。段1から4の途中と検証後に記載外の標準 file を読まず、所有者確定後の重複検索や repository-wide な自己監査を行わない。後述する最終の standard-audit / 独立 reviewer は免除しないが、reviewer の入力を変更差分、手順1から3で読んだ exact files、`verify.sh` の結果だけに固定し、新しい repository 探索を許可しない。subagent が利用できない場合は、同じ既読証拠だけで自己照合し、Grep、Glob、Bash、追加の Read を呼ばない。禁止した tool または file を使った場合は、経路を満たしたと報告しない。最終報告には、意図した読みと、それより弱く遵守判定を変える合理的な読みを、それぞれ一つの具体例で対比する。

開始時は `references/` を読まない。入力が既存の正本 file を明示する場合、または入力の主題が上の領域一覧と領域の台帳から具体的な正本 file へ一意に対応し、配置や所有者を変える候補でない場合は、その標準本文を直接読む。明示された path を Glob や path 未指定の Grep で再発見せず、より一般的な語を持つ principles または concerns を検索して所有者候補を増やさない。具体的な正本 file へ一意に対応しない場合だけ root `README.md` を先に読み、候補の所有者になりうる標準本文を一つに絞る。
配置または領域書式の判断が必要になった時点で、分解した一つの主張につき、対応する `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/references/{principles,concerns,languages,structure,tools,process}.md` を一つだけ読む。
既存規律がある候補について、充足済み、意味を保った文章のリファクタリング、意味の拡張のいずれかを裁定するときだけ `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/references/normative-quality.md` を読む。
各 reference を読む前に、その reference が変えうる判断を一つ記録する。答えを得たらその参照経路を止め、reference directory の列挙、他領域 reference の一括読取、将来の判断に備えた先回り読取は行わない。
一つの入力が複数領域へ分かれる場合は、先に主張と所有者を分け、それぞれの判断を始める時点で対応する reference を読む。
下位実現との一致は、候補が下位実現を変更対象に含む場合、裁定が既存規律の意味を変える場合、または所有者の判断単位が具体的な下位 file を直接参照する場合に確認する。確認対象は具体的な直接参照、領域の `README.md` 台帳、既知の逆参照から実現軸を一つずつ絞り、repository 全域の一致検索で発見しない。いずれの条件にも当たらなければ確認対象外と報告する。

## 手順

### 1. 入力を分解する

入力から主張、根拠、例、決定を分ける。
入力の主張は未採用の候補であり、標準が要求すべき決定として扱わない。
候補を一般化できることだけを理由に上位領域へ昇格させず、既存規律との照合後に採用、不採用、限定、文章のリファクタリングを裁定する。
候補ごとに、要求する遵守結果、現行本文の不足、変更が必要ならその配線と検証を変更契約として固定する。変更する file、規律、reference、script、eval は、この変更契約へ直接結びつくものだけにする。
作業中に見つけた隣接課題は変更へ取り込まず、現在の裁定を妨げる場合だけ未確認事項として報告する。
project の `docs/revision/` を回収する場合は提案ごとに採否を裁定する。
一次本文がなく内容を確定できない外部主張は、配置と調査課題までに留める。
typo、リンク、見出し、registry の機械修正では、変更前の Git 履歴、参照先の正本、または既存 registry から期待値を特定してから編集する。自然言語としてもっともらしい類義語を推測して置き換えない。候補が一致しなければ無変更とし、曖昧さを報告する。

### 2. 所有者を決める

root `README.md` の領域表を正本にする。
値・なぜは principles、複数の部に効く言語非依存の規律は concerns、特定言語の実現は languages、一つの部の境界と中身は structure、採用と判断基準は tools、作業の順序と確認点は process へ置く。

次の順序で所有者と裁定を固定する。

1. 候補と同じ対象、結果、判定手段を扱う既存規律を探す。
2. 候補と同じ主張またはほぼ同じ主張を要求する規範文があれば、その箇所を最初の所有者候補にする。
3. 所有者候補、同じ節の判定要素、意味を決める直接の参照先を一つの判断単位として読む。別の正本への明示参照か、root `README.md` の配置規則と知識の変更理由から誤配置を立証できる場合だけ所有者を移す。
4. 既存規律がある場合だけ `references/normative-quality.md` を読み、意図した読み、遵守判定を変える別解釈、適用範囲、判定手段を照合する。skill や reference の説明で標準本文の欠落を補わない。
5. 充足済みで無変更、意味を保った文章のリファクタリング、既存規律の意味の拡張、新設、矛盾の解消、不採用、根拠不足で見送りのいずれか一つを決める。

同じ語や趣旨があるだけでは充足済みとしない。別解釈で遵守判定が変わる場合、または要求から違反の検出まで追跡できない場合は無変更を選ばない。
所有者本文が冒頭または対象節で別 file の規律に `従う` と定める場合、その直接参照は判断単位に含め、編集前に実際に読む。tool output または直接の読取証拠がない参照を確認済みと報告しない。
既存規律の曖昧さを、同じ主張を別領域へ追加して解決しない。
一つの主張が複数層にまたがる場合は側面ごとに所有者を分け、同じ根拠を重複させない。

### 3. 必要な根拠を調べる

外部事実、版依存の仕様、製品の採用判断を変更する場合だけ外部調査を行う。
一次資料を含む独立した2源以上で確認し、snippet だけで断定せず、`docs/research/` に URL、確認日、判断への影響を残す。
library / framework の仕様は context7 を先に使い、Web 全般は web-researcher を使う。
外部事実を含む裁定を終える前に、主張ごとに本文を取得できた独立2源があるか点検する。1源しかない主張は確認済みにせず、更新を見送って未確認事項へ残す。

typo、リンク、書式、正本と参照の同期だけを直し、外部事実や採用判断を変えない場合は外部調査を行わない。
context7 と web-researcher のいずれかが利用できなければ、利用可能な手段で公式一次資料を直接確認する。必要な一次資料を取得できなければ、外部事実を含む更新を確定せず、阻害要因を報告する。
一次資料に記載がないことだけを、機能が存在しない証拠にしない。確認できたのが文書化の有無だけなら「文書化を確認できない」と報告し、非対応や実現不能と断定しない。

### 4. 最初の十分な変更で止める

文章または配線を変える前に、次の段を記載順に判定する。

1. 現行本文だけで対象、義務、違反、判定手段が一意なら変更しない。
2. 対象、義務、違反、判定手段という既存の規範命題を増やさず、重複、矛盾、曖昧さを生む語または文の削除・置換だけで足りるなら、そこだけ直す。
3. 規範命題の本文を変えず、既存の要求、完了条件、禁止事項、行動、表、参照、検査の対応または参照方向だけを直せば足りるなら、接続だけを直す。
4. 対象、義務、違反、判定手段のいずれかに新しい意味を導入する必要があるなら、既存の正本 file に焦点を絞った規律または文を足し、必要な接続変更もこの段へ含める。
5. 必要な規範命題または機械判定を既存の所有者と実行入口に置けない場合だけ、新しい file、reference、script、eval を作る。

段2は規範命題の文章だけ、段3は規範命題を変えない接続だけ、段4は新しい規範上の意味を含む変更として排他的に分類する。一つの変更に新しい規範上の意味と接続変更の双方が必要なら段4とし、複数の段番号を記録しない。
重複する検証を省く条件を更新するとき、現行本文に、比較集合を各検証の自己申告でなく割り当て先の要求と禁止事項の全範囲から導くこと、その集合が非空であること、適用集合の一致、その全要素における合否述語の双方向の含意がなければ、その判定条件の追加は段4にする。「同じ性質」を「同じ要求」「同じ禁止事項」「同じ目的」へ置き換えるだけでは、比較不能な検証を同じとする読みを排除できないため段2として採用しない。変更する本文には、要求範囲を欠かさない非空の集合を定められない場合、適用集合が一致しない場合、一方が適用不能な場合、一方だけが不合格となる場合は別の性質として両方を残し、反例を未発見なだけでは同一としないことを省略せず書く。実装欠陥または更新漏れによる判定不一致だけを、別の性質である根拠にしないことも明記する。
段4を選んだ変更は、編集後に「既存規律の意味を変えていない」または「下位実現は確認対象外」と読み替えない。段4として追加した対象、義務、違反、判定手段の差と、下位実現の照合結果を最終応答に残す。
各段は変更契約を満たし、標準本文だけで一意に判定でき、必要な検証へつながるかで判定する。満たした最初の段で止め、後の段を比較または実装しない。
編集前に、選んだ段とそれより前の各段について、判定結果と、前段では満たせない変更契約の条件を記録する。選んだ段より後は判定も記録もしない。ここまでを記録できていなければ編集へ進まない。
変更した場合は、最終応答にも選んだ段と、それより前の各段が不足した理由を短く残す。段を列挙しただけでは判定済みと扱わない。段判定の列挙は選んだ段で終え、後の段は「不採用」「不要」「比較していない」と書くことも、その理由を示すこともしない。
新しい reference は繰り返し参照する詳細な裁定手順、新しい script は機械判定できる不変条件、新しい eval は既存の評価集合では観測できない失敗境界がある場合に限る。

### 5. 領域の書式で書く

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

### 6. 配線と台帳を更新する

concerns を横断規律の正本、structure を参照側にする。
概念の増減では root `README.md`、`concerns/README.md`、`.claude/skills/standard-update/SKILL.md`、`scripts/verify.sh` を同期する。
tools の分割や採用名を変えた場合は `tools/README.md`、`.claude/skills/standard-update/SKILL.md` の領域一覧、該当 reference を同期し、`scripts/naming-registry-check.mjs` の動的 registry で検査する。永続する別の registry file は作らない。

### 7. 検証して閉じる

充足済みで無変更と裁定した場合は、本文用 verifier を実行しない。次を報告する。

- 所有者と意図した読み方。
- 作成した対応表。
- 検討した合理的な別解釈と、それを否定する標準本文。
- 適用範囲。
- 規範から判定手段までの連鎖。
- 下位実現との一致、または参照経路の条件に該当せず確認対象外としたこと。
- 未確認事項。

不採用の場合は、候補が弱める、過剰に一般化する、または衝突する既存規律を示す。
根拠不足で見送る場合は、欠けている証拠と、それが変える裁定を報告する。
変更がある場合は次の検証を行う。

編集対象は、固定した所有者と一つの判断単位へ閉じる。変更契約が要求しない標準 file、reference、script、eval、docs を、整合確認や記録のためだけに追加または編集しない。

変更箇所だけを直接検査する linter、test、構造検査があれば focused check として先に実行する。対応する機械検査がなければ、対象 file と直接参照の差分照合を行い、機械検査済みとは扱わない。
次に `${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/verify.sh` を repository root から実行する。
失敗した場合は原因を直し、同じ検査を再実行して PASS になるまで完了としない。

本 skill、`references/*.md`、`scripts/*`、`evals/*.json` を変更した場合は、次も実行する。

```bash
bash "${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/verify-test.sh"
bash "${CLAUDE_SKILL_DIR:-.claude/skills/standard-update}/scripts/skill-package-check.sh"
```

`skill-package-check.sh` は実作業へ公開する product 検査であり、frontmatter、3 skill の eval 定義、script 構文を検査する。`run-task-evals.mjs` が `SKILL_EVAL_ISOLATED_SKILL` と `SKILL_EVAL_CONFIGURATION` の有効な組を渡した隔離評価だけは、選択中 skill の隠された `evals/` を欠落としない。configuration が `without-skill` なら、選択中 skill directory 全体の不存在だけを許可し、directory の一部が残る状態は失敗にする。通常実行や片方だけの指定では、skill または eval 一式がなければ失敗する。`skill-test.sh` は期待する解答と mutation を検査する外側の evaluator 回帰検査であり、評価対象 agent へ公開せず、実作業の完了条件にも使わない。

変更の種類に応じて model eval の範囲を決める。

- `scripts/*` または `references/*.md` だけを変更し、SKILL.md と eval を変えない場合は、上の回帰検査だけを行い、model eval は実行しない。
- SKILL.md の instruction を変更した場合は、skill-creator の評価手順を使う。変更した instruction の入力と観測可能な結果を prompt と expectation が直接使う task だけを `old-skill` と `with-skill` の2条件で隔離実行する。変更された file を監査対象に含むだけの task や、同じ skill を使うだけの task は選ばない。expectation、最終応答、tool event、diff、tracked / ignored status、実行 error、時間、token を比較する。新規 skill で旧版がない場合だけ `without-skill` を比較対象にする。
- `evals/evals.json` だけを変更した場合は、変更した task を `with-skill` で実行する。現行 instruction の不足が失敗として再現した後に instruction を変更し、その段階で `old-skill` と `with-skill` を比較する。
- description または `evals/trigger-evals.json` を変更した場合は、`scripts/run-trigger-evals.mjs` で `trigger-evals.json` の全 query を実行する。3 skill を同時に置いた条件で expected skill または非発火を測り、Skill tool の完全な入力、観測中の実行 error、発火先を記録する。
- release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較と full trigger eval の両方を行う。それ以外は変更面ごとの上記範囲に限定する。instruction と `evals/trigger-evals.json` の変更を組み合わせた場合は、影響 task の2条件比較と full trigger eval をそれぞれ行い、全 task や `without-skill` へ広げない。

task eval は本 task の完遂を、trigger eval は発火先だけを測る。起動成功を PASS とせず、別 context の grader が expectation ごとの成否と event または成果物の根拠を `grading.json` に残す。複数条件を比較した場合は、対象 task の集計を `benchmark.json` に残す。隔離 evaluator が実行できなければ model eval 完了とは扱わず、阻害要因を報告する。

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
- 標準側に例外や project 固有の分岐を作らない。逸脱は利用側 project の ADR へ送る。
- 要求範囲を作り切り、未要求の投機を追加しない。
- 標準本文だけで遵守を判定できる状態にする。
- 変更契約を満たす最初の段で止め、不要な file、reference、script、eval を増やさない。
- 検証していない結果を PASS や完了として報告しない。

## 関連

- `references/{principles,concerns,languages,structure,tools,process}.md` — 領域固有の配置、根拠、書式、MECE 点検。
- `references/normative-quality.md` — 充足済み、文章のリファクタリング、意味の拡張を分ける局所的な裁定。
- `scripts/verify.sh` — 標準本文の機械検査。
- `scripts/verify-test.sh` — verifier の回帰検査。
- `scripts/skill-package-check.sh` — 実作業用の frontmatter、3 skill の eval schema、script 構文の検査。
- `scripts/skill-test.sh` — 評価対象へ公開しない、期待解答と mutation を含む evaluator 回帰検査。
- `scripts/run-task-evals.mjs` / `scripts/run-trigger-evals.mjs` — skill-creator を使えない host の隔離評価入口。
- `scripts/discipline-sections.awk` / `scripts/naming-registry-check.mjs` / `scripts/verbatim-overlap.mjs` — verifier が呼び出す内部実装。個別の公開入口にはしない。
- `evals/evals.json` / `evals/trigger-evals.json` — task 品質と発火境界の評価集合。
- `standard-audit` — 標準自体の読み取り専用監査。
