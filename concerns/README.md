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

## 概念

| ファイル | 統べる規律 |
|---|---|
| [effect](./effect.md) | 副作用の統合。純粋核と効果の殻・エラーモデル・合成 |
| [concurrency](./concurrency.md) | 非同期と並行 |
| [dependency](./dependency.md) | 依存の向きと合成 |
| [types](./types.md) | 型による不変条件の保護 |
| [persistence](./persistence.md) | 永続データの設計。分類・追記・正規化・制約 |
| [transaction](./transaction.md) | 書き込みパスの一貫性と確定点 |
| [messaging](./messaging.md) | イベントによる連携 |
| [authentication](./authentication.md) | 資格情報の検証と actor の構築 |
| [authorization](./authorization.md) | アクセス制御の流れ |
| [observability](./observability.md) | 外部出力から内部状態を推し量る。文脈の伝播と探索可能性 |
| [privacy](./privacy.md) | 個人情報の最小化と期限の消去 |
| [security](./security.md) | 安全の姿勢 |
| [configuration](./configuration.md) | 設定の方針 |
| [resilience](./resilience.md) | 障害への耐性 |
| [performance](./performance.md) | 計測の後の最適化 |
| [lifecycle](./lifecycle.md) | プロセスの起動・健全性・終了 |
| [experience](./experience.md) | 利用者に向けた画面の体験 |

effect は、純粋核と効果の殻・エラーモデル・合成を束ねる親であり、非同期は concurrency、依存は dependency へ委譲する。
冪等・再試行・行き止まりの正本は resilience にあり、transaction は書き込みパスへの適用を、messaging はイベント消費への適用を書く。
自前のスケジューラを作らない規律の正本は concurrency にあり、effect は効果の記述からの委譲を書く。
待ち行列の有界の正本は resilience にあり、concurrency は背圧による需要の制御を書く。
起動時の検証に失敗した停止の正本は lifecycle にあり、configuration は設定の検証の内容を書く。
外部応答に内部の詳細を出さない規律の正本は effect にあり、authorization は拒否の応答への適用を書く。
