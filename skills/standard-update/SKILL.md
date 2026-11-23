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

- `principles/` — 特定概念や技術に閉じない設計の判断基準と一般規律を所有する。
- `concerns/` — 言語非依存の24概念で守る性質と保証を所有する。
  effect・concurrency・dependency・types・context-propagation・persistence・caching・migration・transaction・messaging・workflow・authentication・authorization・privacy・security・secrets・audit-trail・observability・configuration・resilience・performance・lifecycle・experience・accessibility を扱う。
- `structure/` — project 全体と各部の責務、境界、依存方向、配置、および各部固有の設計規律を所有する。
  検証技法の選択、性質から型・静的検査・実行テスト・計測への割当、mutation・coverage・実行範囲は `structure/tests/methods.md` と、その冒頭の表が対象別に分けた技法の file が所有する。
- `tools/` — 言語横断の開発道具(build)、自運用基盤(platforms)、外部 Web サービス(services)の採用と共通基準を所有する。
- `languages/` — rust・csharp・typescript の言語 ecosystem として、6実現軸の規律、全域規律 conventions、その言語 ecosystem の採用物を所有する。
- `process/` — bootstrap・recovery・design・implementation・refactoring・review・audit・migration・verification・release・drill の順序と確認点を横断的に所有する。
- `docs/` — 調査と判断の材料であり、標準本文には含めない。

## 参照経路

`<skill-package-root>` は、成功して読んだこの `SKILL.md` を symlink の実体まで辿った directory である。
`references/` と同梱資材は、ここからの相対 path で読み、同梱 script はここから実行する。
`<standard-root>` は、依頼された標準の作業 checkout の root である。
依頼が明示した値か、host の agent policy が案内する値を使い、この Skill の配備先、固定 Rev、`pwd` から推定しない。
値を得られなければ不足する前提として返し、編集や検証に着手しない。
標準本文の編集と検証は `<standard-root>` で行い、配備済み source や現在の対象 project を編集先にしない。
公開入口の script には、対象の標準 checkout を `--standard-root "<standard-root>"` で明示する。
実行する script は `<skill-package-root>/scripts/` のものであり、`<standard-root>` や `pwd` にある同名の script へ切り替えない。
reference が指す標準本文は `<standard-root>` から読み、`<skill-package-root>` の近くにある本文を使わない。

既知の正本 path は直接読み、再発見の検索をしない。
所有者が不明なら root `README.md` の領域表と台帳から候補を探す。
外部知見の採否を問われたら、無変更も含め、編集先を決める前に手順1から始める。
配置、参照方向、標準の改訂と適用の違いは `<standard-root>/README.md` で確認する。

配置または領域書式を決めるときだけ、該当する `references/{principles,concerns,structure,tools,process}.md` を読む。
languages の配置と書式は `references/tools.md` が所有する。
全 reference の一括読取や、目的のない全域検索をしない。

## 手順

### 1. 何の判断を変える提案かを復元する

記事、実測、project からの提案ごとに、誰のどの判断に問題があり、何を根拠に、どの条件で何を選び直そうとしているかを、入力の該当箇所と結ぶ。
著者の主張、その説明に使った例、こちらが導いた仮説を分ける。
資料が複数なら、同じ例を挙げていても何を優先しているかが違う箇所を残す。
条件を一つ変えてもその提案が成立するかを問い、本文のない資料や確かめていない因果を、確定した要求にしない。

運用 Skill の判断を改訂する場合は、この段で評価者が、失敗が現れる実務の依頼と必要な成果を固定する。適用範囲を変える場合は近接する非対象も選ぶ。
host に Skill の評価手順があればそれを使い、実行者へは期待解答を渡さず、変更前の成果を対照に残す。

意味を変えない typo、リンク、台帳の同期だけなら、Git 履歴、参照先の正本または既存台帳から正しい値を特定し、手順5へ進む。
値が割れれば推測で直さず、その箇所を保留する。

### 2. 意味を比較し影響範囲を辿る

直接所有者の本文を読み、[意味の比較と裁定](references/normative-quality.md) の「判断が分かれる例を作る」を使う。
検証を一つ省けるかが争点なら [検証の重複と割当](references/verification-duplication.md) の反例で試す。

その例で判断が変わると、誰の義務や検証結果が変わるか。
上位の目的と兄弟規律から、別 concern の境界、構造、技術採用、言語別実現、作業の確認点、利用側で違反を見分ける手段まで、答えの変わりうる関係を往復する。
参照がなくても、同じ判断を別の語で下していないかを領域の台帳と概念に基づく検索で探し、本文を読む。
一つの主張に独立した判断があれば、それぞれの所有者を特定する。

影響表には、判断を左右する関係ごとに、起点、確認先の本文、そこで要求される結果、残る疑問を対応させる。
同じ根拠は作業記録を参照し、関係を除いた理由は裁定に影響するものだけを記す。
新たに見つけた同じ原因の欠陥は追跡に加え、別件は混ぜない。
候補の採否や実現を変える関係があれば、直接所有者が十分でも探索を続ける。
確かめられなければ、その関係に依存する裁定だけを保留する。

### 3. 必要な根拠を調べる

外部事実、版依存の仕様、製品の性質が採否を分ける場合は、採用・棄却のどちらを見込んでいても外部調査を行う。
主張を直接裏付ける一次本文を読み、対象の版と適用条件を確かめ、作業中の URL、確認日、判断への影響は追跡外の `work/research/` に残す。
採用する事実と参照は対応する正本へ反映し、継続する読者向けの説明が必要な場合だけ `docs/` へ投影する。
library / framework の仕様は利用可能な library documentation の入口を先に使い、Web 全般は `web-research` の入口を使う。
仕様の定義は、その仕様を所有する公式本文を根拠にする。
効果や優位性についての経験的な主張は、比較条件と測定方法を確認し、著者の自己評価と独立した検証を区別する。
資料間の矛盾や適用条件の不足が裁定を変える場合は追加調査し、資料の件数だけで確認済みとも未確認とも判定しない。
入力本文を観測として用いることと、その外部の経験的主張を事実として採用することは分ける。
本文と現行規律から作れる反例や論理的な不整合は内部証拠で評価し、外部事実を追加しない概念や表現の改善へ外部資料を機械的に要求しない。

typo、リンク、書式、正本と参照の同期だけを直し、外部事実や採用判断を変えない場合は外部調査を行わない。
調査の入口が利用できなければ、利用可能な手段で公式一次資料を直接確認する。
必要な一次資料を取得できなければ、その外部事実に依存する裁定を確定せず、阻害要因を報告する。
一次資料に記載がないことだけを、機能が存在しない証拠にしない。
確認できたのが文書化の有無だけなら「文書化を確認できない」と報告し、非対応や実現不能と断定しない。

### 4. モデルと改善方法を選ぶ

影響表の本文と反例を使い、手順2の reference の「モデルを選び、裁定する」へ進む。
先にファイルや差分の大きさを選ばず、候補のモデルを利用側の同じ判断に当て、どちらを残すと何が保証できるかで決める。

編集する場合は、選んだモデル、退けた実質的な別案、変更前後の義務と判定例、変更する所有者・整合したままの影響先・検証手段を変更契約に残す。
調査で原因が広がれば契約も更新する。
破壊的な変更や根本方針の転換は、理由・影響・代替案を示し、承認を得てから実施する。
本文を変えない場合は verifier を実行せず、裁定を分けた例と、それを裏付ける影響表の本文・検証先を返す。採否を分ける関係が未確認なら、その判断は確定しない。

### 5. 領域の書式で書く

- principles: 原則ごとにフォルダを分ける。
  README は H1 直下のリードと `## 規律` の台帳、規律ファイルは規律の H2 と `要求/根拠/完了条件/禁止事項/行動`、必要な場合だけ例を置く。
  README に `## 概要` と `## 参照` は置かない。
- concerns: 概念ごとにフォルダを分ける。
  README は `## 概要`・`## 規律` の台帳・`## 参照`、規律ファイルは規律の H2 と必須5節、必要な場合だけ例を置く。
- languages の軸 file: `## 概要`、規律ごとの必須5節、必要な場合だけ例、末尾に `## 参照` を置く。
- structure: 導入の参照文、folder tree、単位表または依存方向表、topical な見出しからなる layout 書式を使い、詳細は [structure](references/structure.md) に従う。
  必須5節を持ち込まない。
- tools: 用途、採用、判断基準、撤回条件の4項目を置く。
- process: 導入の参照文、`## 順序`、`## 確認点`、`## 範囲外` を置く。
  必須5節を持ち込まない。

要求、完了条件、禁止事項は判定可能な表現にする。
例は次の順で書く。

1. 例の言語を特定し、その言語の `languages/<language>/conventions.md` を読む。
   擬似コードなら言語固有の構文を使わない。
2. 編集前に、意図的に違反させる項目と、例に表示する規律対象の構文を特定する。
3. 差と帰結はコードフェンス外の本文へ置き、コード例へ説明のコメントを足さない。
   ドキュメントコメント、採らなかった理由、禁止するコメントそのものを示す例では、規律の対象であるコメントだけをコード内に残す。
4. コード例は判定に必要な部分だけを示す断片とする。
   例の主題でない import、ドキュメントコメント、周辺の宣言は表示を省けるが、実コードで不要であるとは示さない。
   表示する構文は、意図的な違反を除き、conventions の規律を例の中でも満たす。
5. ドキュメントコメントを表示する場合は、目的と、宣言が持つ引数・型引数・戻り値・値・副作用・失敗条件の該当項目を、望ましい例と意図的な悪例の両方に記す。
   引数・型引数・戻り値・値の該当は説明の自明さでなく宣言の署名から決め、引数があれば param、型引数があれば typeParam、非 void の戻り値があれば returns、値を公開するメンバなら value を省かない。
   conventions が専用のタグまたは節を定める項目はその記法を使い、定めない項目は本文で述べる。
   別の例の完全な契約で代替しない。

編集の直前に、ドキュメントコメントを表示する各宣言の署名と param・typeParam・returns・value を一対一で照合する。
その後に、対象言語の現行版で成立し、例の主題でない違反が残っていないことを確認する。
既存 file の文体に合わせ、一文一義で書く。
絵文字、進捗語、不要な前置き、人名による権威づけを標準本文へ入れない。

### 6. 配線と台帳を更新する

root `README.md` の配置規則に従い、記述の主たる判断を単位に正本と参照先を接続する。
概念の性質と保証は concerns が、project 全体と各部の構成および固有の設計規律は structure が所有し、規範に従う関係を理由に正本を移したり複製したりしない。
概念の増減では root `README.md`、`concerns/README.md`、`skills/standard-update/SKILL.md`、`references/concerns.md` を同期する。
tools の区分や採用名を変えた場合は `tools/README.md`、languages の言語 ecosystem や採用物を変えた場合は `languages/README.md` と該当 ecosystem の台帳を同期する。
いずれも領域一覧と該当 reference を同期し、`scripts/naming-registry-check.mjs` の動的 registry で検査する。
永続する別の registry file は作らない。

### 7. 検証して閉じる

意味や表現を改めた場合は、最初に使った判定例を改訂後の本文とその参照だけで解き直す。
意図した結果が導け、残す義務・適用外の扱い・下位の検証が保たれているかを確かめる。
機械修正では手順1で特定した正しい値と照合する。
影響表の各確認先を「変更した」「読み直して一致した」「未確認」に分け、旧い判断や参照が残る場合は所有者の修正へ戻る。
結論を変えうる未確認事項を残して全体が整合したとはしない。

変更箇所だけを直接検査する linter、test、構造検査があれば focused check として先に実行する。
対応する機械検査がなければ、対象 file と直接参照の差分照合を行い、機械検査済みとは扱わない。
次に、標準本文の機械検査を実行する。

```bash
bash "<skill-package-root>/scripts/verify.sh" --standard-root "<standard-root>"
```

失敗した場合は原因を直し、同じ検査を再実行して PASS になるまで完了としない。
この PASS は標準本文の決定的な機械検査の結果であり、mutation 分析の完了や score を指さない。
変更が製品の検証や mutation 分析の手順へ及ぶ場合も、決定的な検査の成否と分析の状態(未実行・未分類・生の status)を分けて報告し、分析の未完了を失敗または PASS と書かない。

Skill、reference、script の変更では、変更の影響から追加検査を選ぶ。

- Skill の判断手順を変えた場合は、手順1で固定した依頼を新しい実行者へ渡し、成果と証拠を対照と比べる。
  入口や適用範囲を変えた場合に限り、通常の依頼と近接する非対象で自然発火を別に確かめる。
  本文を渡して得た成果、自然に起動して得た成果、実行できず未評価の能力を区別する。
- 検証器、その回帰 fixture、または検証器が判定する形式・schema・台帳の契約を変えた場合は、`bash "<skill-package-root>/scripts/verify-test.sh" --standard-root "<standard-root>"` で回帰を確認する。本文や reference だけの差分でも判定契約への影響があれば対象に含める。
- package の file を変えた場合は、`bash "<skill-package-root>/scripts/skill-package-check.sh" --standard-root "<standard-root>"` で frontmatter、配置と script 構文を確認する。

検査の選択理由と既存証跡の再利用を記録し、中断した回帰は完了した case と未実行の範囲を区別する。
上限の延長や成功済み範囲の再走行で待機を繰り返さず、必要な保証を覆う計画へ戻る。

最後に standard-audit へ scoped audit を渡す。
対象は差分だけでなく、影響表で同じ判断を担う未編集の箇所を含める。
入力の該当箇所・判定を分ける例・監査対象と判定用 context・未確認の関係を渡す。
直接影響の立証に探索が必要ならその問いと許される範囲を明示し、依頼者が閉じた対象を指定していれば越えない。
返った反例で裁定が崩れたら手順2へ戻り、未監査の範囲を監査済みにしない。
subagent が利用できれば変更の経緯を持たない reviewer に依頼し、利用できなければ独立 session、どちらも利用できなければ自己監査へ代替する。
代替時は独立監査済みと主張しない。
最終応答の変更数、文数、file 数、検証結果は実際の diff と command output に照合する。
差分と一致しない要約を完了報告へ残さない。

## 実行環境

検証 script は Bash、Git、ripgrep (`rg`)、fd、awk、sed、find、coreutils、Node.js を必要とする。
不足時は検査を skip せず失敗する。

## 不変条件

- 一つの規律に一つの正本を持たせ、他は参照に絞る。
- 標準側に例外や project 固有の分岐を作らない。
  逸脱は利用側 project の決定の記録へ送る。
- 要求範囲を作り切り、未要求の投機を追加しない。
- 標準本文だけで遵守を判定できる状態にする。
- 原因を解消する変更と影響先を閉じ、因果関係のない変更や不要な機構を増やさない。
- 検証していない結果を PASS や完了として報告しない。
- 改訂で対象 project の既存の実装が違反になる場合も、改訂の作業で project の repository と基線台帳を編集しない。
  その違反は、`<standard-root>/process/migration.md` の順序の2に従い、改訂の後に各 project で始める最初の作業単位が `standard-conformance` の改訂後の照合で検出して記録する。
  改訂の報告には、変えた義務と判定手段を残し、その照合の範囲を Git の差分から辿れるようにする。

## 関連

- `references/{principles,concerns,structure,tools,process}.md` — 領域固有の配置、根拠、書式、MECE 点検。`tools.md` は tools と languages の両方を所有する。
- `references/normative-quality.md` — 意味の関係、表現の反証、モデル選択、無変更の裁定。
- `references/verification-duplication.md` — 検証手段の重複排除に固有の反例と下位割当の点検。
- `scripts/verify.sh` — 標準本文の機械検査。
- `scripts/verify-test.sh` — verifier の回帰検査。
- `scripts/skill-package-check.sh` — 実作業用の frontmatter と script 構文の検査。
- `scripts/discipline-sections.awk` / `scripts/naming-registry-check.mjs` / `scripts/verbatim-overlap.mjs` / `scripts/heading-citation-check.mjs` — verifier が呼び出す内部実装。個別の公開入口にはしない。
- `standard-audit` — 標準自体の読み取り専用監査。
