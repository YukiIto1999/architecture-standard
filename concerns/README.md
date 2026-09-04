# concerns

concerns は、特定のモジュールや技術に閉じず、システム全体を貫く24の横断的な概念に対する規律を定めます。

各概念は [principles](../principles/) の抽象的な設計原則を全系レベルの規律として具象化し、[structure](../structure/) や [tools](../tools/) はこれらの規律を参照してシステムの骨格と技術選定を実現します。

## 概念の体系

24の概念は、システムのライフサイクルや関心領域に応じて以下の5つの群に分類されます。

- 実行・構成: 副作用、並行処理、依存関係、型安全性、コンテキスト伝播など、コードの実行基盤と構成に関する規律。
- 状態・連携: 永続化データ、キャッシュ、スキーマ移行、トランザクション、非同期メッセージング、長期間のワークフローなど、状態管理と分散連携の規律。
- 信頼・情報保護: 認証、認可、プライバシー保護、全体セキュリティ、秘密鍵管理、監査証跡など、堅牢性と説明責任に関する規律。
- 運用・品質: 可観測性、設定管理、耐障害性、性能計測、プロセスライフサイクルなど、本番運用における品質保証の規律。
- 利用者面: UI体験、アクセシビリティなど、外部アクターや利用者と直接対話する表面の規律。

## 読み方と規律の構造

各概念は独立したディレクトリを持ちます。
直下の README には全系で統べる概要と規律台帳を置き、個別のルールは概念ごとの規律ファイルに記述します。
規律ファイルは、概念の README と一対で参照します。

### 規律ファイルの節構成

規律ファイルは、[principles](../principles/README.md) と共通の統一書式を採用します。

- 要求: 概念ごとに守るべき規則を一文単位に分け、命令形で記します。
- 根拠: 原則の単なる再導出ではなく、全系でどう具体化し何が得られるかを概念の視点で述べます。合否判定の対象外です。
- 完了条件と禁止事項: 遵守状態を観測できる述語で完了条件を定め、アンチパターンを禁止事項に明記します。これらを判定の基準とします。
- 行動: 逸脱の検出から是正に至るまでの手順を示します。
- 例: 原則の読み方の例の規則に従い、対比が理解を助ける場合にのみ付与します。

遵守判定は、要求で意図を捉え、完了条件と禁止事項に照らし合わせて行います。

### 分担と正本の原則

概念フォルダを分ける単位は、structure と tools が独立して名指し、従うための契約です。
概念内の規律ファイルを分ける単位は、その契約を守るための規則です。

一つの規律が複数の概念に関連する場合は、変更理由を最も所有する概念に正本を置きます。他の概念側では正本を参照し、自身の文脈への適用のみを記述します。

## 概念

群は探索のための分類であり、正本と参照の関係を変えない。
| ファイル | 群 | 統べる規律 |
|---|---|---|
| [effect](./effect/README.md) | 実行・構成 | 副作用の統合。純粋核と効果の殻・エラーモデル・合成 |
| [concurrency](./concurrency/README.md) | 実行・構成 | 非同期と並行 |
| [dependency](./dependency/README.md) | 実行・構成 | 依存の向きと合成 |
| [types](./types/README.md) | 実行・構成 | 型による不変条件の保護 |
| [context-propagation](./context-propagation/README.md) | 実行・構成 | 同一実行に随伴する metadata の carrier と伝播 |
| [persistence](./persistence/README.md) | 状態・連携 | 永続データの設計。分類・追記・版の変換・正規化・制約 |
| [caching](./caching/README.md) | 状態・連携 | 正本から再構築できる導出状態の鮮度・無効化・不在 |
| [migration](./migration/README.md) | 状態・連携 | 稼働中の系の移行。段の分割・同一時点の検証・cutover |
| [transaction](./transaction/README.md) | 状態・連携 | 書き込みパスの一貫性と確定点 |
| [messaging](./messaging/README.md) | 状態・連携 | event の契約と配送・消費 |
| [workflow](./workflow/README.md) | 状態・連携 | 複数の確定点にまたがる業務目的の順序・分岐・再開・補償 |
| [authentication](./authentication/README.md) | 信頼・情報保護 | 資格情報の検証と actor の構築 |
| [authorization](./authorization/README.md) | 信頼・情報保護 | アクセス制御の流れ |
| [privacy](./privacy/README.md) | 信頼・情報保護 | 個人情報の最小化と期限の消去 |
| [security](./security/README.md) | 信頼・情報保護 | 安全の姿勢 |
| [secrets](./secrets/README.md) | 信頼・情報保護 | 資格情報と鍵の保存・参照・回転・失効・監査 |
| [audit-trail](./audit-trail/README.md) | 信頼・情報保護 | 説明責任を立証する証跡 |
| [observability](./observability/README.md) | 運用・品質 | 外部出力から内部状態を推し量る。構造化 event と探索可能性 |
| [configuration](./configuration/README.md) | 運用・品質 | 設定の方針 |
| [resilience](./resilience/README.md) | 運用・品質 | 障害への耐性 |
| [performance](./performance/README.md) | 運用・品質 | 計測の後の最適化 |
| [lifecycle](./lifecycle/README.md) | 運用・品質 | プロセスの起動・健全性・終了 |
| [experience](./experience/README.md) | 利用者面 | 利用者に向けた画面の体験 |
| [accessibility](./accessibility/README.md) | 利用者面 | 利用者面の可達性と識別性。keyboard 操作・色に頼らない識別・対比・pointer target の下限 |

