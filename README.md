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

本標準は、抽象から具象へと段階的に具体化される6つの領域で構成されます。上位の抽象層は下位の具象層に依存せず、すべての参照は具象から抽象への一方向に保たれます。

```text
     [ principles ]      なぜ / 言語非依存の設計原則
           ▲
           │             全体を貫く規律は何か
      [ concerns ]       セキュリティ・永続化・並行性などの24概念
           ▲
           │             各部をどう組むか
     [ structure ]       骨格・境界・レイヤー・配置
      ▲         ▲
      │         │        何を、どう選ぶか
   [ tools ]    │        言語横断の開発道具・自運用基盤・外部サービスの採用
      ▲         │
      │         │        どの言語機構で満たすか
 [ languages ]  │        rust・csharp・typescript の実現と採用物
                │
           [ process ]   どの順で作り、どこで確かめるか / 作業順序と確認点
```

### 領域の一覧

| 領域 | 答える問い | 内容 |
|---|---|---|
| [principles](./principles/) | なぜ | 設計判断の土台となる言語非依存の原則。構成・規律・表現の3群 |
| [concerns](./concerns/) | 全体を貫く規律は何か | システム全体を通す概念ごとの規律。24概念 |
| [structure](./structure/) | 各部をどう組むか | ターゲットプロジェクトの骨格と各部の構造 |
| [tools](./tools/) | 何を、どう選ぶか | 言語横断の採用と判断基準。build・platforms・services の3区分 |
| [languages](./languages/) | どの言語機構で満たすか | 言語ごとの実現軸の規律と、その ecosystem の採用物。rust・csharp・typescript |
| [process](./process/) | どの順で作り、どこで確かめるか | 作業の種別ごとの順序と確認点。11単位 |

### 参照と依存の規則

領域間の参照は、具象から抽象への一方向に保ちます。languages は tools、structure、concerns、principles に従い、tools は structure、concerns、principles に従い、structure は concerns、principles に従い、concerns は principles に従います。

process は principles と concerns に従い、作業順序の入力および確認点の照合先として structure、tools、languages を指します。process は順序と確認点だけを所有し、性質の規範を再定義しません。

具象の側から、より抽象の側への参照は常に適法です。逆に、抽象の側は機構の置き場として具象の側を指すだけであり、具象の内容に依存しません。具象の側は、抽象が定めた規律を再定義しません。

参照文の文末の述語は、具象から抽象へは「に従う」、抽象から具象へは「が定める」と書き、文構造で参照の向きを表します。規律を名指す参照は、正本の見出しを「」で囲んだ逐語の名で書き、別の語で言い換えないこととします。

なお、docs ディレクトリに置かれる資料は決定、調査、議事録、レビューの材料であり、標準には含めません。標準は docs なしで完全に自立して成立します。

## 利用シナリオ別の案内

目的に応じて、以下の導線から各仕様を参照します。

### 新規にプロジェクトを立ち上げる場合
1. [process/bootstrap.md](./process/bootstrap.md) で全体の立ち上げ手順を確認します。
2. [structure/skeleton.md](./structure/skeleton.md) でリポジトリ全体の骨格と境界を定義します。
3. [tools/](./tools/) で言語横断の道具と基盤を、[languages/](./languages/) で言語ごとの ecosystem と採用物を選定します。

### 日常の設計や実装を進める場合
1. [process/design.md](./process/design.md) および [process/implementation.md](./process/implementation.md) の順序と確認点に従います。
2. 設計の判断根拠は [principles/](./principles/) を、システム全体の規律は [concerns/](./concerns/) を参照します。
3. 各部の具体的なレイアウトと境界は [structure/](./structure/) に従います。

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
2. 各関心は、その変更理由が及ぶ最も広いスコープに一度だけ配置する。より狭い層はそれを参照するのみとし、再定義しない。
3. 配置先は以下の順で判定し、最初に合致した領域へ配置する。
   1. なぜや判断基準となる価値は principles へ配置する。
   2. 特定言語での実現と、その言語 ecosystem に属する採用物は languages へ配置する。
   3. 言語横断の道具、自運用基盤、外部サービスの採用と判断基準は tools へ配置する。
   4. 作業の手順と確認点は process へ配置する。
   5. 単一のモジュールの境界や中身は structure へ配置する。
   6. 複数のモジュールにまたがる、または全域に適用される規律は concerns へ配置する。

## 運用と判定

### 適用の4則

AI エージェントおよび開発者は、すべての作業モードにおいて次の4則に従います。

1. 本文の直読。規律を適用または指摘する前に、該当ファイルの本文を必ず読む。principles と concerns の規律ファイルは、概念フォルダの README と一組で読む。過去の記憶や要約、見出しの略称だけで判断を下さない。
2. 全域の調査。監査と適用の範囲は、対象リポジトリの全域を既定とする。範囲を局所に限定するには、明示的な指示を必要とする。
3. 意図の確認。標準の本文と依頼者の意図が食い違った場合は、本文を盾に意図を独断で上書きせず、必ず依頼者に確認する。
4. 本文引用の義務。規律への違反や逸脱を報告する際は、照合した規律の本文の引用とファイルパスを明記する。引用を伴わない違反指摘は、有効な照合が行われていないものとみなす。合致の報告は規律見出しの名指しで足りる。

検証の合否は、リポジトリに記録された検証入口の実測結果によってのみ判定し、自己申告や推測で通過させてはなりません。

### 判定の枠と severity

規律への遵守判定は、領域ごとの枠組みに従って厳密に行います。

- principles と concerns では、要求で意図を捉え、完了条件と禁止事項に照らして判定します。機械検証可能な規範命題は structure/tests や languages の inspection に割り当て、残りは process の確認点照合が担います。
- structure では、構成、依存方向、各 layout の固有規律への合致で判定します。
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
決定の記録は <決定の記録の置き場> にある。
```
