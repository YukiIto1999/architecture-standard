# architecture-standard

architecture-standard は、ソフトウェアアーキテクチャの標準そのものです。
このリポジトリに置かれたファイル群が、システム全体の設計、実装、運用の規範の正本として機能します。

AI エージェントによる起草と改訂を前提に、標準本文の書式と台帳は機械検査で維持します。
対象プロジェクトで設計思想が実現されているかは、規律に割り当てた実行検査とレビューで評価します。

## 目的と提供価値

本標準は、プロジェクトごとに場当たり的に行われがちなアーキテクチャ決定を単一の基準で置き換えます。開発ライフサイクルのあらゆる段階で、一貫した判断の土台を提供します。

- 新規構築では、本標準の骨格と規律に従い、初期設計から迷いなく組み立てます。
- 既存システムの移行では、本標準との差分を特定し、段階的に整合させる形で改修を進めます。
- 設計やコードの監査では、本標準への合致度を判定の枠に基づいて客観的に評価します。
- 日常の実装とレビューでは、本標準の各規律を直接照合し、設計意図と品質を担保します。

## アーキテクチャの全体像

本標準の6つの領域は、どの種類の判断を正本として所有するかで分けます。
同じ抽象度の六層ではなく、正本の所有、規範に従う関係、本文を探す参照経路を区別します。
次の図の矢印は規範に従う関係だけを示し、探索の参照経路は示しません。

```text
[ principles ] ◄── [ concerns ] ◄── [ structure ] ◄── [ tools ] ◄── [ languages ]
                        ▲
                        │
                   [ process ]
```

### 領域の一覧

| 領域 | 答える問い | 正本として所有する判断 |
|---|---|---|
| [principles](./principles/) | どの判断基準と一般規律に従うか | 特定概念や技術に閉じない設計の判断基準と一般規律。構成・規律・表現の3群 |
| [concerns](./concerns/) | 概念が何を保証するか | 認可、永続化、並行性など、特定概念で守る言語非依存の性質と保証。24概念 |
| [structure](./structure/) | 全体と各部をどう設計するか | ターゲットプロジェクト全体と各部の責務、境界、依存方向、配置、および各部固有の設計規律 |
| [tools](./tools/) | 何を、どう選ぶか | 言語横断の採用と判断基準。build・platforms・services の3区分 |
| [languages](./languages/) | どの言語機構で満たすか | 言語固有の実現と規約、その ecosystem の採用物。rust・csharp・typescript |
| [process](./process/) | どの順で作り、どこで確かめるか | 作業の種別ごとの順序と確認点。11単位 |

### 規範に従う関係と参照経路

規範に従う関係は、具象から抽象への一方向に保ちます。
languages は tools、structure、concerns、principles に従い、tools は structure、concerns、principles に従い、structure は concerns、principles に従い、concerns は principles に従います。

process は principles と concerns に従い、作業順序の入力および確認点の照合先として structure、tools、languages を指します。
process は順序と確認点だけを所有し、性質の規範を再定義しません。

正本を所有する領域は、規範に従う関係だけでは決まりません。
具象の側は、抽象が定めた規律を再定義しません。
本文を探すための参照で抽象の側から具象の側を指す場合は、機構の所在を案内するだけであり、具象の内容に依存しません。

参照文の文末の述語は、具象から抽象へは「に従う」、抽象から具象へは「が定める」と書き、文構造で参照の向きを表します。
規律を名指す参照は、正本の見出しを「」で囲んだ逐語の名で書き、別の語で言い換えないこととします。

この標準では、現在の読み手の理解と判断に説明が必要な場合に限り、正本から投影した文書を `docs/` に置き、Git で追跡します。
標準本文には含めず、六領域の規範は `docs/` なしで完全に自立して成立します。
対象 project の読者向け文書と一時的な作業記録の役割は、[principles/documentation/separate-document-types.md](./principles/documentation/separate-document-types.md) の「文書の種別を分け、読み手を定める」が定めます。

## 利用シナリオ別の案内

目的に応じて process の入口から必要な規律へ進み、以下の導線を参照します。

### 新規にプロジェクトを立ち上げる場合
1. [process/bootstrap.md](./process/bootstrap.md) で全体の立ち上げ手順を確認します。
2. [structure/skeleton.md](./structure/skeleton.md) でリポジトリ全体の骨格と境界を定義します。
3. [tools/](./tools/) で言語横断の道具と基盤を、[languages/](./languages/) で言語ごとの ecosystem と採用物を選定します。

### 日常の設計や実装を進める場合
1. [process/design.md](./process/design.md) および [process/implementation.md](./process/implementation.md) の順序と確認点に従います。
2. 設計の判断基準と一般規律は [principles/](./principles/) を、特定概念の性質と保証は [concerns/](./concerns/) を参照します。
3. 全体と各部の構成、境界、固有の設計規律は [structure/](./structure/) に従います。

### コードレビューや品質監査を実施する場合
1. [process/review.md](./process/review.md) または [process/audit.md](./process/audit.md) を開きます。
2. 後述の判定の枠および適用の4則に基づき、客観的な証跡と本文引用をもって判定します。
3. 適合性を JSON で報告する全域監査は、[standard-conformance](./skills/standard-conformance/SKILL.md) の inventory、照合、完了検査を使います。

### 既存システムの移行や構造改善を行う場合
1. [process/recovery.md](./process/recovery.md) で既存の意味を回収し、[process/migration.md](./process/migration.md) で段階的移行の順序を設計します。
2. 振る舞いを変えない改善は [process/refactoring.md](./process/refactoring.md) に従います。

## 運用 Skill

運用 Skill の正本は、このリポジトリの `skills/<id>/` に置き、client の設定 directory では所有しません。
対象 project への適用は [standard-apply](./skills/standard-apply/SKILL.md)、適合性の全域監査は [standard-conformance](./skills/standard-conformance/SKILL.md)、標準への改訂提案の報告は [standard-feedback](./skills/standard-feedback/SKILL.md) を使います。
標準自体の変更は [standard-update](./skills/standard-update/SKILL.md)、読み取り専用監査は [standard-audit](./skills/standard-audit/SKILL.md) を入口にします。
CLI の人と script の呼び出しの設計は [cli-design](./skills/cli-design/SKILL.md)、契約から生成器と oracle、操作列、反例の分類へ落とす検査は [property-testing](./skills/property-testing/SKILL.md) を使います。

dotfiles-wsl は、固定した Nix source と `skills/plugins/module.nix` の明示的な採用表から、選択済み client へ Skill package を配備します。
Claude Code の `.claude/skills/` など client ごとの配備先は投影先であり、正本の所有先ではありません。
配備済み source は読み取り専用とし、標準の編集と検証には作業 checkout を使います。

## 統治の規約

### 矛盾の解決

記述が層をまたいで矛盾したときは、抽象側の記述を正とします。
優先順位は principles、concerns、structure、tools、languages の順です。
process の記述が他の層と食い違うときは、他の層を正とします。

同じ層の中の矛盾は、その層の README が正本と指すファイルを正とします。root の構成は skeleton が、各部の内部は各 layout が、概念の規律は当該概念のフォルダの規律ファイルが、言語の機構は該当する実現軸のファイルが正本です。

適用の現場では、この順で選んだ記述に従って作業を継続します。矛盾に気づいた場合は独断で読み替えず、対象ファイルと該当箇所を添えて標準の保守窓口へ報告します。標準への改訂提案も、実測した証跡を添えて同じ窓口へ報告し、対象プロジェクトの成果物へ残しません。

この優先順位は、現在の標準をプロジェクトへ適用するための規則であり、標準自体を改訂するときの正しさの証明には使いません。
標準の保守では、外部知見を現在の標準全体を再評価する観測として扱い、現行の上位原則も含めて根拠、前提、因果関係、適用範囲を比較します。
改訂は、意味的に影響する規律、下位実現、確認点と運用 Skill まで整合させ、今回の知見と同じ設計判断、概念モデル、因果関係に属さない変更を混ぜません。
更新の手順と評価は、作業 checkout の [standard-update](./skills/standard-update/SKILL.md) が所有します。

### 正本の単一

一つの関心について、正本は一箇所だけに置きます。他の箇所は正本を参照し、再定義しません。
対象には、状態、語彙、契約、データ、採用、規律、検証の閾値を含むすべての関心が含まれます。正本が複数存在すると、同じ関心が箇所ごとに異なる値や意味を持ち、不整合と語の割れが発生するためです。

正本の所在は、標準の側では領域と配置規則が、対象プロジェクトの側では各領域の規律が定めます。
導出した値を別の箇所へ保持してよいのは、破棄しても正本を失わない控えとして扱い、正本からいつでも再構築できる場合に限定します。
正本を移すときは、旧い正本を残したまま新しい正本を立て、すべての参照を移し終えてから旧い正本を削除します。一時に併存する正本は、この移行途中に限られます。

### 標準の単一性と例外の管理

標準は、単一の標準のみが存在します。同一の目的に対して、条件付きの分岐や例外を標準の側に設けることはありません。同一目的の代替手段は標準外とみなします。

標準外の技術や設計を採るプロジェクトは、そのプロジェクトの決定の記録に採用理由、撤回条件、単一採用、置き換える標準規律のファイル参照、逸脱の前提となる技術的制約の実証を明記しなければなりません。
標準が明示的な定めを持たない目的については、principles の要求と禁止事項に照らしてプロジェクト自身が決定し、単一採用として決定の記録に残します。標準の沈黙を、一般的な手法による補完の暗黙の許可と解釈してはなりません。

決定の記録は、独立した外部 ADR の永久保管ではなく、判断の意味を現在のコード、テスト、契約、設定、変更理由、採らなかった理由から辿れる状態を指します。
情報の分担と更新は、[principles/documentation/decision-records.md](./principles/documentation/decision-records.md) の「設計判断の理由を決定の記録に残す」に従います。
逸脱の撤回条件、単一採用、規律への参照と技術的制約の実証は、現在の採用を判断できる情報として保持し、必要な読者向けの説明は正本への対応を持つ追跡対象の文書にします。
判断を覆す場合は、現在の情報を更新し、変更する理由を一つの目的と取り消し理由に絞った commit へ残します。

#### 対象の性質による既定の縮小

本標準は、複数の surface か永続データを持つシステムを既定とします。ただし、単一 surface、永続データなし、単一 process をすべて満たすプロジェクトに限り、以下の緩和を、対象の性質を判定する一つの決定として決定の記録に残して適用できます。

| 緩和対象 | 緩和内容 |
|---|---|
| contracts | 外部との契約を持たないなら contracts/ を置かない。HTTP を持たない契約は JSON Schema 経路の型生成だけに縮小できる |
| task graph | 単一言語・単一 package なら、タスク名の契約を保ったまま言語の native な task 実行で代替できる |

上記以外の緩和はすべて個別の逸脱として扱い、決定の記録へ個別に残すことを必要とします。

### 配置規則

標準へ新しい規律や記述を追記する際は、以下の原則に従います。

1. 複数の意味を含む曖昧な用語は、独立した個別の関心へ分解する。
2. 配置は記述の主たる判断を単位にし、複数の独立した判断を含む場合は分解して、それぞれの正本を一度だけ置き、他の領域は正本を参照して再定義しない。
3. 配置先は以下の順で判定し、最初に合致した領域へ配置する。
   1. 特定の概念、構成、採用物に閉じない一般的な設計原則と判定規律は principles へ配置する。
   2. 言語固有の実現、規約、その言語 ecosystem の採用判断は languages へ配置する。
   3. 言語横断の道具、自運用基盤、外部サービスの採用と判断基準は tools へ配置する。
   4. 開発・運用作業の順序と確認点は process へ配置する。
   5. プロジェクト全体または各部の構成と固有の設計判断は structure へ配置する。
   6. 特定概念の言語非依存の性質と保証は concerns へ配置する。

理由を書く、言語で例示する、順序を持つ、複数のモジュールに効くという表現だけでは、配置先を決めません。
採用理由は採用側が、原則の意図と是正を説明する行動は principles が、業務 workflow の状態と確定点は concerns が所有します。
認可の保証は実装が一つのモジュールでも concerns に置き、認可 adapter の配置は structure に置きます。
TypeScript の規約はプロジェクト全域に効いても languages に置きます。
root をまたぐ具体的な許可依存は [structure/skeleton.md](./structure/skeleton.md) が、依存が満たす一般的な性質と保証は [concerns/dependency](./concerns/dependency/README.md) が所有し、root を一つの巨大なモジュールと読み替えて区別を失わせません。
検証技法と規範から検証への割当は [structure/tests/methods.md](./structure/tests/methods.md) が所有し、structure をフォルダ配置だけに限定しません。

## 運用と判定

### 適用の4則

AI エージェントおよび開発者は、すべての作業モードにおいて次の4則に従います。

1. 本文の直読。規律を適用または指摘する前に、該当ファイルの本文を必ず読む。principles と concerns の規律ファイルは、概念フォルダの README と一組で読む。過去の記憶や要約、見出しの略称だけで判断を下さない。
2. 全域の調査。監査と適用の範囲は、対象リポジトリの全域を既定とする。範囲を局所に限定するには、明示的な指示を必要とする。
3. 意図の確認。標準の本文と依頼者の意図が食い違った場合は、本文を盾に意図を独断で上書きせず、必ず依頼者に確認する。
4. 本文引用の義務として、規律への違反や逸脱を報告する際は、照合した規律の本文の引用とファイルパスを明記する。
   引用を伴わない違反指摘は、有効な照合が行われていないものとみなす。

検証の合否は、リポジトリに記録された検証入口の実測結果によってのみ判定し、自己申告や推測で通過させてはなりません。

### 適用判断

判断を左右する主張の根拠状態と導出元は、[principles/requirements/evidence-decision-separation.md](./principles/requirements/evidence-decision-separation.md) の「根拠と決定状態を分ける」に従います。
合否または設計を左右する意味的な適合、違反、非適用、保留の判断では、次の対応を既存の設計、レビュー、監査の記録と出典から追跡できなければなりません。

| 情報 | 確認できる内容 |
|---|---|
| 規律 | 現行の正本と該当する要求、完了条件、禁止事項 |
| 対象 | 判断したコード、契約、要件、設定、実行経路の事実と確認範囲 |
| 適用条件 | 対象が条件を満たす、満たさない、確定できない理由 |
| 導出 | 対象のどの事実が、規律のどの条件を満たすか |
| 結論 | 適合、違反、非適用、または根拠不足による保留 |
| 検証 | 実施した検査とその観測、または未実行の範囲 |

この表は新しい保存 schema や毎回の応答 template ではなく、判断に必要な情報が追えることを要求します。
既存の成果物と出典を参照し、同じ根拠を重複して記録しません。
意味的な適合の報告は、規律見出しの名指しだけでは足りず、対象の事実と導出への参照を伴わせます。
型検査や決定的な検査で直接確定する項目は、その規則と対象と実測結果の対応を証拠とし、同じ推論を文章で再構成しません。
判定を変える未確認条件は非適用にせず、利用可能な証拠で解消できなければ保留し、判断への影響と不足する事実を残します。

### 判定の枠と severity

規律への遵守判定は、領域ごとの枠組みに従って厳密に行います。

- principles と concerns では、要求で意図を捉え、完了条件と禁止事項に照らして判定します。機械検証可能な規範命題は structure/tests や languages の inspection に割り当て、残りは process の確認点照合が担います。
- structure では、構成、依存方向、各部の本文が定める固有の設計規律への合致で判定します。
- tools と languages では、採用と判断基準、採用機構と各規律の完了条件および禁止事項への合致で判定します。
- process では、手順の順序遵守と確認点の照合有無で判定します。

監査における severity は、上記で得た違反を以下のように分類します。

- critical: principles や concerns の禁止事項違反、structure の依存方向または明示された禁止への違反、tools や languages の明示された禁止への違反。
- major: principles や concerns の完了条件の不達、structure の必須構成または layout の不達、tools や languages の採用機構・完了条件・判断基準の不達、process の順序不遵守または確認点の未照合。
- minor: 判定の枠に明記されていない表現や構造の改善提案。違反には数えない。

同一の箇所が critical と major の双方に該当する場合は、critical のみを報告に含めます。

## プロジェクトへの適用方法

### 標準リポジトリの参照方法

標準のファイル群は、対象プロジェクトのリポジトリ内へ直接コピーして取り込んではなりません。

AI エージェントには本標準リポジトリのパスを渡し、常に一次資料である本文を直接読ませて適用します。
プロジェクトは標準の版を固定せず、配備されている現在の標準本文を基準にします。

設計、実装、レビュー、監査は、いずれも現在の標準本文を基準として照合します。過去の版を基準にすると、すでに改訂された規律への適合を合格と判定し、現行の規律への違反を見落とします。標準の改訂によって既存の実装が違反になった場合は、[process/migration.md](./process/migration.md) に従って現行の標準へ寄せます。

### 運用と検査の役割

規範の正本、適用手順、配布設定、対象プロジェクトの検証は、役割を分けて運用します。
標準本文を agent の常時指示へ複製せず、今回の判断に必要な本文への参照は [standard-apply](./skills/standard-apply/SKILL.md) が案内します。
配布する Skill の本文と同梱 script は [skills/](./skills/) が所有し、host 側の配布設定は採用する source と更新を管理します。
配布先を更新するまでは、作業 checkout の変更は稼働中の agent へ届きません。

| 役割 | 所有者と入口 |
|---|---|
| 設計判断と規律の正本 | この README と六領域の標準本文 |
| 対象 project への適用 | [standard-apply](./skills/standard-apply/SKILL.md) |
| 規範から検査への割当 | [structure/tests/methods.md](./structure/tests/methods.md)、[principles](./principles/) と [concerns](./concerns/) の概念 README の規律台帳、言語別 inspection の対応表である [Rust](./languages/rust/inspection.md)、[C#](./languages/csharp/inspection.md)、[TypeScript](./languages/typescript/inspection.md) |
| 検査の実行と合否 | [process/verification.md](./process/verification.md) と対象 project の検証入口 |
| 監査の順序 | [process/audit.md](./process/audit.md) |
| JSON 監査報告と完了境界 | [standard-conformance](./skills/standard-conformance/SKILL.md) と [check-coverage.mjs](./skills/standard-conformance/scripts/check-coverage.mjs) の `inventory`、`check` |
| session の監査完了強制 | 対応 host の dotfiles runtime が持つ `dotfiles-agent-gate conformance` と stop receipt |
| 標準側の不備の還流 | [standard-feedback](./skills/standard-feedback/SKILL.md) |

全域の適合性監査では、現行正本と対象 source の inventory から文書集合と検査割当を導き、文書ごとの適用判断と規律ごとの検査証拠を報告へ残します。
正本に割り当てられた machine と review はそれぞれ必要とし、読取や一件のレビューで他の検査を代替しません。
条件付き規律の適用判断は、実行検査や独立レビューの証拠とは別に扱います。
`check-coverage.mjs` は、欠けた disposition や検査割当の rule と kind、不足証拠、未実行、古い観測、新規違反を検出して監査の完了判定を閉じます。
project の analyzer ではなく、引用の意味や適用判断の妥当性、証拠の真偽、全規範命題の実検査も保証しないため、すべての設計思想を機械検証したとは扱いません。
報告の形式、実基線台帳との照合、対象 project を含む Git repository の外への報告保存、CLI の終了状態の扱いは、standard-conformance の契約に従います。
対応 host の runtime gate は標準側の checker を実行して receipt を記録し、stop で同じ正本、source、報告、checker の鮮度を照合します。
checker と規範はこの repository が、receipt と停止時の強制は dotfiles が所有するため、host に gate がない場合は自動 stop 強制済みとは扱いません。
登録 command と実 session ID の取得、gate がない場合の検証入口への接続は、standard-conformance の完了検査が案内します。

### プロジェクト側の記載形式

対象プロジェクトの最上位 README には、標準本文を転写せず、以下の形式で参照先のみを宣言します。

```text
アーキテクチャの標準は <標準リポジトリの場所> にある。
準拠の基準は、常に現在の標準本文である。
適用は、標準の README の適用の4則と利用の手順に従う。
現在の契約と読者向け文書の入口は <対象 project の参照先> にある。
```
