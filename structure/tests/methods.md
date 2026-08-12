# tests の方法

methods は、検証に用いる技法を定める。
技法は、検証する対象の性質で選ぶ。
methods は [layout](./layout.md) の配置に従う。
ダブルとフィクスチャの扱いは [doubles](./doubles.md) に従う。

## ロジックと状態

純粋なロジックは、stateless の property-based testing で検証する。
状態の遷移は、状態を持つ property-based testing で検証する。
性質は、出力が常に満たす不変条件・二度適用しても結果が変わらない冪等・変換と逆変換の往復・信頼できる別実装との一致から選ぶ。
生成される入力が一つの区分に偏ると検査が形だけになるため、偏るときは生成を工夫するか、区分ごとに性質を分ける。
use-case は、port を fake に置き換えて検証する。
冪等性は、同じ command の識別子の再実行が同じ結果を生むことで確かめる。
これらはプロセスの外への依存を持たない Small である。配置は [layout](./layout.md) に従う。
形式手法で、コードの全面は検証しない。
symbolic と concolic の実行を、標準の検証に組み込まない。

## 決定性と隔離

テストは、実行順序に依存せず、単体でも他のテストと並べても同じ結果を返す。
テストどうしが共有する状態は、実行の前に用意し、後始末を次の実行へ持ち越さない。
並列実行への耐性は、テストごとに独立した資源(接続・スキーマ・一時領域)を割り当てて確かめる。
繰り返し実行して結果が変わる不安定なテストは、隔離の区分へ移し、通常のゲートから外す。
隔離の区分に残せる期間は期限で区切り、期限の値は project が定める。
不安定さを断つ原因の分類と対処は [principles/verification](../../principles/verification.md) に従う。

## 権限

権限は、主体・操作・資源・条件と、期待する許可と拒否の組み合わせの matrix で検証する。
matrix は、公開された interface を越して検証する。
権限の matrix は、業務の振る舞いの検証として対象に含める。
権限の規律は [concerns/authorization](../../concerns/authorization.md) に従う。

## 実依存

adapter は、実の依存をコンテナで起動して検証する。
採用された store([concerns/persistence](../../concerns/persistence.md) に従う)を実コンテナで起動する。
生存と準備の面は、プロセスをコンテナで起動し、面の観測で確かめる。
故障は、effect を型付きで注入して再現する。
副作用の境界の規律は [concerns/effect](../../concerns/effect.md) に従う。

## 性質別の技法

oracle が得にくい対象は、metamorphic な関係で検証する。
移行と置換は、旧と新の経路の差分で検証する。
replay は、イベントから projection を再構築して検証する。
信頼できない入力は、契約を駆動にした fuzz で検証する。
契約駆動の fuzz は、生成した OpenAPI を駆動元にし、道具の採用は [tools の inspection](../../tools/inspection.md) が定める。
公開 API の契約への適合も、同じ機構で検証する。
protocol 経路の適合は、生成物と実装の drift の検査と conformance で検証する。
契約 generator の生成結果は、全 variant の判別子と payload を serialize と deserialize で往復する generated-contract round-trip で検証し、repository の検証入口で失敗として扱う。

## 規範から検証への対応

標準の要求と禁止事項は、観測できる性質ごとに次の検証へ割り当てる。
同じ性質を複数の道具で重複して判定せず、最も内側で確定できる型、静的検査、実行テスト、計測の順に一つの判定を選ぶ。

| 対象 | 必須の検証 |
|---|---|
| domain の不変条件と状態遷移 | constructor の拒否、状態遷移の property、網羅する outcome |
| use-case と workflow | port を制御した振る舞い、workflow の各 step の確定と再開、冪等な再実行、補償開始、未検出 mutant |
| canonical と binding | operation・型・error の欠落と余剰、generated drift、serialize round-trip、POST・PUT・status・cache・405 を含む HTTP method semantics、protocol conformance |
| 認証と認可 | 各認証境界の credential 拒否と actor 構築、credential の core 非流入、主体・操作・資源・条件の許可と拒否 |
| 永続化、transaction、messaging | 実 datastore の制約、version conflict、単一の確定点、状態と outbox の同時確定、停止位置ごとの再開、重複配送、順序、行き止まり |
| effect、concurrency、resilience | 四つの終了、取消と deadline、子処理の drain、並行上限、過負荷、再試行と遮断を決定的に起こす test |
| structure と dependency | root と単位の列挙、依存方向、公開面、配置、循環、禁止 import |
| lifecycle と configuration | 不正設定での起動拒否、生存と準備、受付停止、期限内 drain、突然死後の回復 |
| security と privacy | default deny と最小権限、信頼境界ごとの abuse case、標準暗号の設定、secret と個人情報の非流出、保持期限後の消去、供給物と依存の検査 |
| experience と accessibility | 利用者が観測する状態遷移、keyboard 操作、focus、名前と役割、contrast、回復経路 |
| performance | 固定した workload と環境での SLO 計測、変更前後の比較、計測結果を伴う退行判定 |

canonical operation から core API、surface の binding、公開 interface の scenario までを一つの対応として列挙する。
欠落した operation、実体のない mapping、canonical にない余分な入口、scenario が一つもない公開 operation は失敗する。
ある規範を型、静的検査、実行テスト、計測のいずれでも判定できない場合だけ人手レビューへ割り当て、判定理由と見る箇所を明記する。

## 構造の検証

構造の規則は、依存方向・公開面と可視性・配置と粒度・命名・純粋性のクラスに分けて検証する。
依存方向と参照の禁止は、構造の検査で機械検証する。
公開面は、言語の可視性の機構と構造の検査で守る。
結合・循環・規模などのアーキテクチャ特性は、客観の尺度の適応度関数として測り、閾値を超えたら不合格とする。
特性を客観の尺度で測る規律は [principles/verification](../../principles/verification.md) に従う。
全単位(コンテキスト・機構・surface・runtime)が検査対象として列挙されていることを、実フォルダとの照合で機械確認する。
単位を追加したときに検査の対象へ自動で追従しない構成を、置かない。
構造で検証できない規則は、型と lint・実行テスト・人手レビューのいずれかに割り当てる。
structure と languages の各規律は、検証手段を名指しで持つ。
どの手段にも割り当てない規則を、残さない。
言語ごとの検査の機構は [languages](../../languages/) が定める。

## テストの有効性

テストの有効性は、mutation で検査する。
mutation を絞る場合は、変異演算子と低リスク要素(参照データ表・等価変異)に限る。
層やコンテキストを丸ごと対象から外すことを、しない。
業務 domain と純粋ロジック全体は、composition の写像を含めて検査の対象に含める。
検査を失敗させるしきい値は、0 でない正の値に定める。
mutation は repository の検証入口に配線し、しきい値を割ったら失敗で止める。
未実行の箇所は、カバレッジで見つける。
カバレッジは、仕様から導いたテストの取りこぼしを確かめる手段であり、数値を目標にしない。
数値が高くてもアサーションの強さは示されず、その検査は mutation が担う。
低いカバレッジは、確実に検証の不足を意味する。
各 project は、branch coverage の下限を記録し、repository の検証入口で判定する。
safety analysis で safety-critical と分類した decision は、各基本条件が独立に decision の結果を左右することを MC/DC で確かめる。
safety analysis は decision ごとに安定な `decision_id`、source locator、基本条件の `condition_id` を記録し、`tests/mcdc-cases.json` は同じ ID と各 condition の case pair を持つ。
case pair は二つの case ID、各基本条件の値、decision の期待結果を持つ。
test harness は `decision_id` と、基本条件の値から boolean の decision 結果を返す純粋な production decision symbol の registry を持ち、case 定義を入力としてその symbol を直接呼ぶ。
registry の値は safety analysis の source locator が指す production decision symbol への直接参照に限り、真理値表または別実装へ置き換えない。
検証入口は safety analysis、case 定義、evaluator registry の decision・基本条件を一対一で照合し、registry の参照先 symbol と source locator の一致、pair 内で対象以外の条件が固定され、対象条件と期待結果だけが反転することを判定する。
test harness は全 case を実行し、evaluator の実結果を期待結果と照合する。
coverage report が MC/DC の metric を直接出さない場合は、report だけで MC/DC を満たしたと判定しない。
カバーしない箇所は、見落としでなく判断の結果として残す。
snapshot を、主たる検証にしない。
AI が生成したテストを、有効性の検査なしに受け入れない。
検証の合否の判定は [README](../../README.md) に従う。
テストの緩和は、人間が承認する。
型と lint は、予防として用いる。

## 実行範囲

変更時の検証は、変更の影響を受ける型検査、静的検査、Small test を最初に実行し、触れた境界の Medium test まで広げる。
契約、migration、認証・認可、供給網、検証入口そのものを変えた場合は、対応する全境界の検証を実行する。
Large test、全 mutation、全 SLO 計測は、影響が及ぶ変更、定期実行、release 前の検証で実行する。
同じ source、command、環境、入力の成功結果は、その同一性を確認できる間は再利用し、同じ検証を重ねて実行しない。
失敗後の修正では失敗した検証と、修正した source の依存先と逆依存の consumer に対応する検証を再実行する。
検証を省いたのでなく、影響がないことを差分と依存関係から示せない検証は実行する。
性能の目標は [concerns/performance](../../concerns/performance.md)、耐障害性は [concerns/resilience](../../concerns/resilience.md) と [concerns/lifecycle](../../concerns/lifecycle.md)、security と privacy は [concerns/security](../../concerns/security.md) と [concerns/privacy](../../concerns/privacy.md) に従う。
言語ごとの具体の機構は [languages](../../languages/) が定め、道具の採用は [tools/inspection](../../tools/inspection.md) が定める。
