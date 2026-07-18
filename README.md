# architecture-standard

architecture-standard は、ソフトウェアアーキテクチャの標準そのものである。
このリポジトリのファイルが、そのまま標準である。
標準を生成するメタ層や、実装のソースは持たない。

この標準は、プロジェクトごとのアーキテクチャ決定を置き換える。
新規構築は、この標準に従って組み立てる。
既存の移行は、この標準との差分を埋める形で進める。
監査は、この標準への合致を評価する。
日常の実装とレビューは、この標準を照合の基準にする。
これらのモードは、AI エージェントが再現性をもって実行する。

## 領域

| 領域 | 答える問い | 内容 |
|---|---|---|
| [principles](./principles/) | なぜ | 設計判断の土台となる言語非依存の原則。構成・規律・表現の3群 |
| [concerns](./concerns/) | 全体を貫く規律は何か | システム全体を通す概念ごとの規律。17概念 |
| [structure](./structure/) | 各部をどう組むか | ターゲットプロジェクトの骨格と各部の構造 |
| [languages](./languages/) | 言語でどう実現するか | 言語ごとの採用機構とイディオム |
| [tools](./tools/) | 何を使うか、どう選ぶか | 用途ごとの採用と判断基準。language・stack・inspection・services・platforms の5分割 |
| [process](./process/) | どの順で作り、どこで確かめるか | 作業の種別ごとの順序と確認点。7単位 |

参照は、具象から抽象への一方向に保つ。
tools は languages・structure・concerns・principles に、languages は structure・concerns・principles に、structure は concerns・principles に、concerns は principles に従う。
process は principles・concerns に従い、順序の入力と確認点の照合先として structure・languages・tools を指す。
process は順序と確認点だけを所有し、性質の規範を再定義しない。
具象の側から、より抽象の側への参照は、常に適法である。
抽象の側は、機構の置き場として具象の側を指すだけで、具象の内容に依存しない。
具象の側は、抽象が定めた規律を再定義しない。

docs/ は、決定・調査・議事録・レビューの材料であり、標準に含めない。
標準は、docs/ なしで完結する。

## 矛盾の解決

記述が層をまたいで矛盾したときは、抽象側の記述を正とする。
優先は principles、concerns、structure、languages、tools の順である。
process の記述が他の層と食い違うときは、他の層を正とする。
同じ層の中の矛盾は、その層の README が正本と指すファイルを正とする。
root の構成は skeleton が、各部の内部は各 layout が、概念の規律は当該概念のファイルが、言語の機構は該当する実現軸のファイルが正本である。
適用の場では、この順で選んだ記述に従って作業を続ける。
矛盾は黙って読み替えず、file と該当箇所を添えて標準の保守へ報告する。

## 標準の単一性

標準は、単一の標準のみである。
同一の目的に対して、条件付きの分岐や例外を標準の側に作らない。
同一目的の代替手段は、標準外である。
標準は、標準外の目的に対しても、採る場合の機構を単一に名指しすることがある。名指しがあっても、採否の記録は project の ADR に従う。
標準外を採る project は、その project の ADR に、採用理由・撤回条件・単一採用・置き換える標準規律の file 参照・逸脱の前提となる技術的制約の実証を明記する。
撤回条件の既定は、前提が崩れたら標準へ戻すことである。
アンチパターンは、不採用であり禁止である。
対象の性質に応じて技法を選ぶ規則は、例外ではなく、単一の標準を一様に適用する形である。
標準が定めを持たない目的では、principles の要求と禁止事項に照らして project が決定し、単一採用として project の ADR に記録する。
標準の沈黙を、一般則による補完の許可と解釈しない。

## 配置規則

標準への追記は、次の規則に従う。

1. 傘ことばを、別個の関心に分解する。
2. 各関心は、変更理由が及ぶ最も広いスコープに1度だけ置く。狭い層は参照するだけで、再定義しない。
3. 置き場は次の順で判定し、最初に該当した所へ置く。
   1. 値・なぜ → principles/
   2. 採用と判断基準 → tools/
   3. 作業の順序と確認点 → process/
   4. 特定言語の実現 → languages/
   5. ちょうど1つの部の境界・中身 → structure/
   6. 複数の部にまたがる、または全層に効く → concerns/

## 適用の3則

どのモードでも、AI エージェントは次の3則に従う。

1. 規律を適用・指摘する前に、該当ファイルの本文を読む。記憶・要約・見出しの略語で判定しない。
2. 監査と適用の範囲は、対象リポジトリの全域を既定とする。範囲を狭めるには、明示の指示を要する。
3. 標準の本文と依頼者の意図が割れたら、本文で意図を上書きせず、依頼者に確認する。

検証の合否は CI の実測で判定し、自己申告で通さない。

## 利用

### 標準の参照

標準は、project の repo へ取り込まない。
AI エージェントには、この標準リポジトリの場所を渡し、規律は本文を読ませて適用する。
project は、準拠の基準にした標準の commit を、project の ADR に記録する。
監査は、記録された commit の標準を基準に照合する。
project は、標準への改訂提案を project の docs/revision に置く。
project の入口の文書は、次の3点だけを書き、標準の内容を転写しない。

```text
アーキテクチャの標準は <標準リポジトリの場所> にある。
準拠の基準は、project の ADR に記録した commit である。
適用は、標準の README の適用の3則と利用の手順に従う。
```

### 適用の手順

手順の正本は [process](./process/) にある。
新規構築は [process/bootstrap](./process/bootstrap.md)、監査は [process/audit](./process/audit.md)、移行は [process/migration](./process/migration.md) に従う。
日常の作業は、設計が [process/design](./process/design.md)、実装が [process/implementation](./process/implementation.md)、構造改善が [process/refactoring](./process/refactoring.md)、レビューが [process/review](./process/review.md) に従う。

## 判定の枠

遵守の判定は、領域ごとの枠で行う。
枠の正本は各領域の README であり、ここには対応だけを示す。
principles と concerns は、要求で意図を捉え、完了条件と禁止事項で照合する。
structure は、構成・依存方向・各 layout の固有規律で判定する。
languages は、採用機構と各規律の完了条件で判定する。
tools は、採用と判断基準で判定する。
process は、順序の遵守と確認点の照合で判定する。
