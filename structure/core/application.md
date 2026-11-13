# application 層

application 層は、一つのコンテキストが独立して所有する業務操作を公開し、その内の手順と進行を組み立てる層である。
業務の判断は domain を呼び出し、副作用は port を通じて行う。
application は [layout](./layout.md) の単位と依存に従う。

## port

port は、use-case や workflow が要求する能力を宣言する interface である。
port は、業務上の操作や進行の記録といった能力の単位で分割し、技術名で分割しない。
port の名前は、能力を表す語で付ける。
port のメソッドは、副作用を effect 型で返す。
外部の I/O を実装する adapter は infrastructure に置き、外部の公開契約と application の Interface の写像は [contracts/adapters](../contracts/adapters.md) が所有する。
application は port の抽象のみに依存し、adapter の実装型を参照しない。
effect の規律は [concerns/effect](../../concerns/effect/README.md) に従う。

## use-case

use-case は、一つのコンテキストが所有する単一の業務動作である。
use-case は、同じコンテキストの port と domain、および libs の公開技術 API のみに依存する。
use-case は、別の use-case を参照しない。
use-case は、業務動作の要求から同時に確定する範囲を決め、同じコンテキストの複数のモデルの判断を呼んで一度に確定してよい。
確定の範囲の判断は [aggregate-integrity](../../principles/data/aggregate-integrity.md) の「整合性を集約境界に閉じる」に、競合制御は [concerns/transaction](../../concerns/transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従う。
use-case は、一つの use-case を一つのフォルダに置く。
port への到達に共有の wrapper 層(capability accessor)を挟まず、use-case は port の抽象を直接受ける。
use-case の名前は、単一の動作を表す動詞と名詞の組とする。
use-case は、モデリング上のアクターの目的と変更理由、開始の契機、成功と拒否、確定する業務事実から分ける。
アクターの人数、認証 role、table、entity の数だけで use-case を分割しない。
複数の domain モデルの判断を要することだけを理由に、use-case の分割も、モデルの統合も、集約の追加も決めない。
分割の判断は [principles/separation](../../principles/separation/split-by-change-reason.md) の「変更理由で分ける」に従う。
命名は [principles/naming](../../principles/naming/README.md) に従う。
表記の規約は [languages](../../languages/) が定める。

## workflow

workflow は、同じコンテキストの複数の業務動作にまたがる順序・分岐・再開・補償を、独立した進行の責務として組み立てる場合に置く。
一つの use-case で完結する業務動作は、複数のモデルを扱う場合や停止を越えて再開する場合も、その use-case が手順と進行を所有し、転送するためだけの workflow を置かない。
workflow は、use-case の公開入口を呼び、順序、結果に基づく分岐、再開点、打ち消しの開始を担う。
workflow の順序・分岐・再開・補償の規律は [concerns/workflow](../../concerns/workflow/README.md) に従う。
業務の不変条件と業務状態の遷移は domain に、単一の業務動作は use-case に置き、workflow に重複させない。
分岐の意味を決める業務規則は domain の policy に置き、workflow は型付きの outcome に従って次の入口を選ぶ。
業務の状態は use-case を通して変更し、実行上の進行の記録は、進行を調整する use-case または workflow が宣言する port を通して保存する。
停止を越えることや記録を保存することだけを理由に、新たな domain の集約や業務規則を作らない。
workflow は、adapter の実装型を参照せず、直接 I/O を行わない。
workflow は、別のコンテキストの use-case または workflow を参照しない。
workflow は、別の workflow を呼ばない。
workflow は、application 自身がトランザクションを制御する use-case の公開入口を受け取り、その実装や driver を構築しない。
一つの workflow は、一つの業務目的と一つの再実行単位に閉じる。

## 入力構築と保護の適用点

use-case と workflow は、コンテキストが独立して定義した型付きの command と result・outcome の Interface を公開する。
application の Interface は業務操作の責務から手で定義し、contracts から生成せず、生成 Interface を実装しない。
command の公開入力構築は、[contracts/adapters](../contracts/adapters.md) が渡す field を内部の domain の検証付き constructor へ通し、コンテキスト固有の不変条件を型に残す。
公開契約の定義と生成した型・構築・codec・Interface を application や domain へ import せず、業務型を外から直接構築できるように公開しない。
型の構築時に保証する性質、現在状態に対する遷移条件、競合下での確定条件を分ける。
検証を一点に集める規律は [concerns/types](../../concerns/types/README.md) に従う。
公開入口の Interface は、操作の保護と、対象を取り出した後の保護を適用する位置を持つ。
認可の宣言は [contracts/adapters](../contracts/adapters.md) がその Interface へ接続し、業務本体は認可 engine や許可・拒否の結果を受け取らない。
当事者を必要とする操作だけ、コンテキスト固有の業務主体を入力へ含め、認証主体や共通の actor 型を全操作へ要求しない。
workflow は application が定める型の保護された子 use-case の入口を組立点から受け取り、契約 adapter の実装を参照しない。
子 use-case の呼び出しも保護と対象取得の契約を通し、workflow 自体の許可を子操作の許可へ流用しない。
認可の保証は [concerns/authorization](../../concerns/authorization/README.md) に従う。
実行文脈の由来と寿命は [concerns/context-propagation](../../concerns/context-propagation/README.md) に従い、domain の純粋な関数へ渡さない。

## 結果と副作用

use-case は、結果を公開 outcome として返す。
domain event はコンテキストの内部に閉じる。
独立した外部へ公開する事実は、その event を公開する application の入口が domain event から integration event へ写像し、公開 outcome に含める。
外部副作用は、port または libs の公開技術能力の抽象を通じてのみ行う。
use-case は、直接の I/O、現在時刻の取得、乱数生成、ログを行わない。
use-case は、業務の判断を domain の純粋関数に閉じる。
試行回数、待ち時間、次の実行時刻のように業務の意味を持たない再実行の判断は、use-case と workflow の本体にも domain にも書かず、進行を記録する port の実装か [libs](../libs/layout.md) の公開技術能力に委ねる。
読む・判断する・書くの順と純粋核と効果の殻の分離は [concerns/effect](../../concerns/effect/README.md) に従う。

## 更新と参照

use-case は、不変条件を守って状態を変える更新と、状態を変えずに値を返す参照を分け、参照の形(一覧、集計、検索)は、更新に使う集約の形から独立に決める。
更新と参照の分離(CQRS)は、責務とモデルの分離であり、別の datastore、確定の後に更新する派生読みモデル、broker、イベント列を状態の正本とする方式の採用を意味しない。
同じ datastore の正本を、更新は集約を通して、参照は port の問い合わせで読んでよい。
参照ごとに整合の強さと読む形を定め、確定の後に更新する派生読みモデルは、その遅れを許す参照だけが読む。
書き込みの検証が読む状態は、確定の範囲の正本か、同じ確定で更新する控えに限り、確定の後に更新する派生読みモデルを読まない。
domain イベント、業務事実の保持、integration event の配送、イベント列を状態の正本とする方式の関係は、[domain](./domain.md) の「イベント」とそれぞれの正本の規律に従い、更新と参照の分離から保持や配送の契約を追加しない。
控えと派生読みモデルの条件は [principles/data](../../principles/data/derive-state-from-facts.md) の「今の状態を事実の行から導く」に、更新方式の性質は [concerns/persistence](../../concerns/persistence/measured-physical-optimization.md) の「物理の最適化は計測した根拠で行う」に従う。

## トランザクション

use-case は、同じコンテキストの同時に確定する変更と事実、判断に必要な読み取り、確定条件を所有し、開始から確定または中止までを制御する。
同時に確定する範囲は、業務動作の要求から決め、一つの集約や一つの table の単位に機械的に合わせない。
複数のモデルの判断を要する use-case は、同じコンテキストの各モデルの domain の純粋な関数を呼んで結果を組み、必要な変更を同じ確定に含める。
制御は、port または libs の公開技術能力の抽象を通して、言語が定める遅延した効果として組む。
domain の純粋な判断は、状態と入力から遷移の結果または拒否を返し、transaction の境界を受け取らない。
application は、その結果に含まれる状態と出来事を [domain](./domain.md) の「常に正しい構築」に従って扱い、業務判断を再実装せずに保持の契約と確定する変更へ対応付ける。
application が定める開始と transaction scope の抽象と、具体的な DB driver の transaction handle を区別し、後者を application の Interface へ流さない。
冪等性が必要な use-case は、idempotency の store を port として宣言する。
状態の変更、必要な業務事実、同じ確定で更新する控え、公開する integration event の outbox 記録を同じ確定に含める。
workflow の step の確定は、workflow と step の組の一意性、状態の変更、outbox 記録、step の完了記録を同じ範囲へ含める。
競合、確定前の拒否、失敗、取消では中止を制御し、確定の結果が不明なときは成功や確実な未確定へ丸めない。
制御の所有は [concerns/transaction](../../concerns/transaction/application-owned-transactions.md) の「トランザクションの制御を application に置く」に従う。
workflow は複数の use-case を一つのトランザクションで包まず、各 use-case の確定点と公開 outcome を用いて進行する。
同時に確定する必要がある複数のモデルは、workflow が複数の use-case を包んで確定するのでなく、一つの use-case が確定の範囲に含める。
進行の途中からの再開は、所有するコンテキストの永続化した状態から続ける。
独立した外部への通知は outbox に記録し、受信側はその事実を自分の公開入力へ写して、自分が所有する処理を開始する。
同じ workflow を再実行する場合は、workflow の識別子と進行済みの確定点を永続し、完了した use-case を重ねて実行しない。
workflow は、子 use-case の呼び出しに workflow の識別子と step の識別子を渡す。
トランザクションの規律は [concerns/transaction](../../concerns/transaction/README.md) に、冪等性の規律は [concerns/resilience](../../concerns/resilience/README.md) に従う。
