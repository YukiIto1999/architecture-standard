# translation

## 概要
translation は、TypeScript で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、TypeScript の機構で満たす。
共通の生成経路は [tools/build/typespec](../../tools/build/typespec.md) が、受信側固有の業務値と公開契約外の入力を検証する schema は [valibot](./valibot.md) が定める。
生成した型と client の使い分けの規律は [connection](./connection.md) が持つ。

## 生成した契約値の構築と所有権を守る

### 要求
distinct scalar は非公開の brand を持つ primitive の型とし、alias は同じ型への参照として扱う。
通常の field 制約は所有する生成モデルの構築と decode で検証し、制約名だけを理由に brand や class を増やさない。
生成した object の構築は検証付き factory に閉じ、local 構築と decode は受理値または位置・規則を持つ構造化した違反情報を返す。
variant と operation の各結果は判別子つき union とし、判別子と payload の対応を検証する。
strictNullChecks と exactOptionalPropertyTypes を有効にし、required nullable・optional nonnullable・optional nullable を区別する。
local 構築でも明示的な undefined を未指定へ潰さず拒否し、JSON が表せない状態を local だけで受理しない。
readonly を公開型に付け、外部の可変な object と配列は完成時に切り離して凍結し、検証後に別参照から変更できないようにする。
既に生成された不変な子は共有し、primitive の型分離のために heap object を作らない。
decimal と日時は、必要な値域・同値性・精度・scale・offset を保存する検証済み表現を使い、number や Date の範囲・丸め・正規化へ契約を合わせない。
深い値の全経路は [structure/contracts/generated](../../structure/contracts/generated.md) の「生成能力」に従い、構築・凍結・default・encode を明示的な走査状態で処理する。
JSON の字句解析は既存 parser を再利用し、[structure/contracts/layout](../../structure/contracts/layout.md) の「JSON の相互運用 profile」を満たす受入処理へ接続する。
JSON.parse の後では失われる重複名や数値精度を、復元後の object の検査だけで保証したと扱わない。

### 根拠
[exactOptionalPropertyTypes](https://www.typescriptlang.org/tsconfig/exactOptionalPropertyTypes.html) は項目の欠落と明示的な undefined の型上の区別を保つが、外部値や型 assertion の実行時の正当性は保証しない。
readonly は別参照からの変更を止めないため、検証後の値を守るには storage の所有と完成時の凍結を合わせる必要がある。

### 完了条件
役割の取り違えと variant の payload 不一致が型検査で拒否され、alias の互換と通常の field の primitive 表現が保たれている。
local 構築と decode が同じ規則へ照合され、明示的な undefined と不正値が拒否される。
元の配列と object の変更が受理済み値を変えず、存在状態と契約の全受理値域が保持されている。
共通の wire profile と深さ・診断保持の検査が、[structure/tests/methods](../../structure/tests/methods.md) の「契約の意味と生成」へ接続されている。

### 禁止事項
型 assertion や any で未検証の値を契約型として信頼すること。
readonly の型だけを、可変 alias がない証拠にすること。
brand を実行時の値の出自の証明とみなすこと。
通常の構築・decode の違反を throw だけで返すこと。

### 行動
TypeScript emitter に非公開 brand、検証付き構築、codec、存在状態と所有権の処理を含める。
型構築の assertion を検証を完結する生成 factory の内側に閉じ、検証済み graph の public factory での再走査を避ける。

## 公開契約の境界を生成 codec に通す

### 要求
HTTP・IPC・postMessage の公開契約の入力は unknown で受け、共通 toolchain が IR から生成する codec に通す。
公開契約の field・variant・制約を Valibot 等の consumer 固有の schema に書き写さない。
codec は既知項目と判別子を検証し、全 variant と入れ子・配列内 object の未知キーを受容して、位置とキーを受理値とは別の診断で返す。
通信を所有する host の adapter は診断の位置とキーを警告として記録し、捕捉値を業務入力・再送値・ログへ流さない。
生成型と独立した application の入力構築への写像は contracts/adapters が所有し、業務の保証と公開契約の保証を同じ schema にしない。
受信側に新しい業務上の保証がある場合だけ、受信側が所有する構築へ写し、公開契約と同じ性質を再検証しない。

### 根拠
生成 codec が解釈済み IR を使えば、型と検証の正本を分けずに、公開契約の全受信経路へ同じ保証を適用できる。
業務値を独立に所有すれば、公開契約の変更から業務モデルを切り離せる。

### 完了条件
公開契約の実際の受信経路が生成 codec を通り、不正な既知項目が業務処理前に拒否される。
未知キーの位置とキーが境界の警告へ届き、捕捉値が業務データと送信 payload に入らない。
consumer に公開契約の同義 schema がなく、Adapter が独立した application Interface へ接続されている。

### 禁止事項
生成した静的型への cast だけで境界を通すこと。
公開契約の decode を consumer の手書き schema や生成後の編集で補うこと。

### 行動
受信を生成 codec へ接続し、受理値と診断を分けて取り出す。
業務側の検証は、独立した入力構築の責務に従って Adapter から呼ぶ。

## 生成した通信処理を既存の効果へ接続する

### 要求
純粋な型・構築・codec の公開入口と consumer transport・提供側 dispatch の実行機構を分け、純粋な入口に通信 runtime と Effect runtime を要求しない。
生成した通信操作は [ts-results-es](./ts-results-es.md) と [coordination](./coordination.md) の Effect・AsyncResult・絶対期限・AbortSignal へ接続し、呼出しごとの signal を通信の最下層へ渡す。
transport は host が注入し、TLS・proxy・呼出しごとの上限・再試行を生成物の既定設定へ隠さない。
生成した通信処理は [structure/contracts/generated](../../structure/contracts/generated.md) の「応答の分類」に従い、status・media type・明示した識別情報から結果を選び、body を decode してから返す。
宣言した各成功は識別できる outcome、宣言した拒否は操作の想定内失敗の Result にし、成功の body の未検証値や生の例外を consumer に返して解釈させない。
502・503・504 の中継由来の不一致と通信の不成立は通信の Result の err、その他の契約不一致と要求組立の欠陥は throw にする。
自身の上限の超過は DeadlineExceeded と別の失敗とし、DeadlineExceeded は withDeadlineEffect の戻りだけに使う。
transport 自身の timeout と内部取消は呼出側の取消や自身の上限に混ぜず、通信の失敗にする。
中断の識別と signal の帰属は coordination に従い、呼出側の取消は失敗の Result にせず、受信と decode を完了した結果は後着の取消で書き換えない。
提供側 handler・dispatch の生成 Interface は contracts 側で使い、手書き Adapter が独立した application Interface へ接続する。

### 根拠
生成通信処理が codec と結果対応を所有すれば、consumer は成功例外の補償、status と body の再照合、通信と取消の再分類を実装しなくて済む。
純粋な入口の分離により、型と codec だけの利用に host の通信実装を強制しない。

### 完了条件
純粋な生成入口の依存 closure に通信 client・transport・Effect runtime がなく、生成用の依存も製品の runtime と型検査へ流入していない。
全宣言結果、body 不在、binary、契約不一致、通信・上限・取消が生成通信処理で分類されている。
生成物が製品の採用する TypeScript で型検査され、提供側 dispatch と consumer transport の両端が接続されている。

### 禁止事項
consumer が成功の例外を捕捉して補償し、生の body を再 decode すること。
status の範囲だけで応答を分類し、payload の形を順に試して結果を選ぶこと。
通信の不成立・上限・取消と、実装の欠陥を一括して Result の err にすること。

### 行動
通信を port の実装に接続し、生成通信処理の中で宣言結果と既存の効果チャネルを対応付ける。
複数の成功・body 不在・media type の表記差・不正 body・本文途中切断・上下位の上限・取消の競合を inspection の検証へ接続する。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md) に従う。
