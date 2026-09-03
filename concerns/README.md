# concerns

concerns は、システム全体を通す、概念ごとの規律をまとめる。
各概念は principles の抽象を具象化し、structure と languages はこれらの規律を参照して実現する。

## 読み方

各概念は、`## 概要` に全系で統べる規律と具象化する principle を述べる。
その下に規律ごとの `## 規律名` を置き、各規律を必須の5節で書く。
末尾に `## 参照` を置く。

- 要求では、概念ごとに守る規則を一文単位に分け、命令形で記す。
- 根拠は、原則の再導出でなく、全系でどう具象化し何が得られるかを概念の高度で述べる。
- 完了条件は、規律を満たした状態を観測できる述語で書く。
- 禁止事項は、その概念の下でしてはならないことを書く。
- 行動は、違反の検出から是正までの手順を書く。
- 例は、避けたい形と望ましい形を擬似コードや構造で対比し、規律の理解に役立つときだけ加える。
  対比の差と帰結はコメントで述べ、望ましい形を後に置き、記号に頼らない。

遵守の判定は、要求で意図を捉えたうえで、完了条件と禁止事項に照合する。
根拠の根本は principles 側にあり、ここでは具象化の理由に留める。

file を分ける単位は、structure と languages が独立に名指して従う契約である。
file の中の規律を分ける単位は、その契約を守るための規則である。
完了条件と禁止事項には、具象化する principle の完了条件・禁止事項に含まれない観測だけを書く。
principle と同じ観測を別の語で言い直さず、参照だけを置く。
一つの規律が複数の概念に効くときは、その規律の変更理由を所有する概念に正本を置き、他の概念は正本を参照して自分の文脈への適用だけを書く。
分担は、正本の概念の概要と、適用する概念の本文の参照で宣言し、この台帳には重ねて書かない。

## 概念

群は探索のための分類であり、正本と参照の関係を変えない。
| ファイル | 群 | 統べる規律 |
|---|---|---|
| [effect](./effect.md) | 実行・構成 | 副作用の統合。純粋核と効果の殻・エラーモデル・合成 |
| [concurrency](./concurrency.md) | 実行・構成 | 非同期と並行 |
| [dependency](./dependency.md) | 実行・構成 | 依存の向きと合成 |
| [types](./types.md) | 実行・構成 | 型による不変条件の保護 |
| [context-propagation](./context-propagation.md) | 実行・構成 | 同一実行に随伴する metadata の carrier と伝播 |
| [persistence](./persistence.md) | 状態・連携 | 永続データの設計。分類・追記・版の変換・正規化・制約 |
| [caching](./caching.md) | 状態・連携 | 正本から再構築できる導出状態の鮮度・無効化・不在 |
| [migration](./migration.md) | 状態・連携 | 稼働中の系の移行。段の分割・同一時点の検証・cutover |
| [transaction](./transaction.md) | 状態・連携 | 書き込みパスの一貫性と確定点 |
| [messaging](./messaging.md) | 状態・連携 | event の契約と配送・消費 |
| [workflow](./workflow.md) | 状態・連携 | 複数の確定点にまたがる業務目的の順序・分岐・再開・補償 |
| [authentication](./authentication.md) | 信頼・情報保護 | 資格情報の検証と actor の構築 |
| [authorization](./authorization.md) | 信頼・情報保護 | アクセス制御の流れ |
| [privacy](./privacy.md) | 信頼・情報保護 | 個人情報の最小化と期限の消去 |
| [security](./security.md) | 信頼・情報保護 | 安全の姿勢 |
| [secrets](./secrets.md) | 信頼・情報保護 | 資格情報と鍵の保存・参照・回転・失効・監査 |
| [audit-trail](./audit-trail.md) | 信頼・情報保護 | 説明責任を立証する証跡 |
| [observability](./observability.md) | 運用・品質 | 外部出力から内部状態を推し量る。構造化 event と探索可能性 |
| [configuration](./configuration.md) | 運用・品質 | 設定の方針 |
| [resilience](./resilience.md) | 運用・品質 | 障害への耐性 |
| [performance](./performance.md) | 運用・品質 | 計測の後の最適化 |
| [lifecycle](./lifecycle.md) | 運用・品質 | プロセスの起動・健全性・終了 |
| [experience](./experience.md) | 利用者面 | 利用者に向けた画面の体験 |
| [accessibility](./accessibility.md) | 利用者面 | 利用者面の可達性と識別性。keyboard 操作・色に頼らない識別・対比・pointer target の下限 |

