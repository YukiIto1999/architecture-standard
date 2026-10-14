# adapters 層

adapters は、公開契約と core の公開 application 入口を接続する層である。
依存と配置は [layout](./layout.md) に従い、認可の強制は [concerns/authorization](../../concerns/authorization/README.md) に従う。

## フォルダ構成

```
contracts/adapters/
└─ <operation>    一つの公開 operation と application の接続。
```

adapter は、canonical の operation ごとに置く。
同じ公開契約を使う surface と host は、同じ adapter の公開入口を使う。
core を埋め込まない client は generated のデータ型と通信実装を使い、この層へ依存しない。

## 依存方向

| 参照元 | 参照可 | 参照不可 |
|---|---|---|
| operation の adapter | generated のデータ型、core の公開 API、libs の公開 API | core の domain と非公開実装、surface、runtime、deploy、tests |

core の組み立ては [core/composition](../core/composition.md) に従う。
adapter は組み立て済みの core API と、宣言された入口の保護に必要な技術能力を、起動側の組立点から受け取る。
通信の起動、資格情報の取得、DB driver の生成を adapter 内へ隠さない。

## 入出力の写像

公開契約の DTO とコンテキストの application 入出力との写像は、この層だけが所有する。
adapter は生成 DTO の field を core API が公開する application の入力構築へ渡し、公開 result と outcome を生成した結果型とエラー型へ写す。
公開契約の形式と制約は、generated の decoder または契約から導く境界の変換器で検証する。
コンテキスト固有の不変条件は、application の入力構築から内部の domain の検証付き constructor へ通す。
同じ性質を内側で再検証せず、業務型の構築と検証はコンテキストが所有する一点に保つ。
adapter のためにドメイン型や constructor をコンテキストの外へ公開しない。

区分の写像は、公開する選択肢とコンテキストの型が取りうる場合の対応を持つ。
名前の一致で対応を推測せず、公開しない場合と、複数の内側の場合を一つの公開区分へ写す場合も、その対応に含める。
公開契約の型と application の型は、外部表現と業務の保証の違いで分け、同じ保証の中間 DTO を写像の都合だけで増やさない。
生成物の不足は、canonical、binding、生成器の入力へ戻して直す。

## 保護された公開入口

adapter は、公開 operation、対象、認可方針と適用点の宣言を、core の公開入口の実行契約へ結び付ける。
入口の保護は [concerns/authorization](../../concerns/authorization/declarative-access-guards.md) の「認可の宣言を公開入口で強制する」に従う。
surface と host へ渡す呼び出し口は、宣言された保護を適用する入口に限定する。
認証主体と資格情報の許可範囲は、認証と認可の境界内に保ち、core へ principal、token、claim、認証方式の型を渡さない。
業務が当事者を必要とする操作だけ、検証された主体との対応を経たコンテキストの業務入力を構築する。

対象に依存する認可の適用点は、application が所有する対象取得の Interface と、その読み取りを含む確定範囲へ結び付ける。
対象の取得結果から認可に必要な事実だけを取り出し、domain の非公開実装を認可の機構から参照しない。
adapter が use-case 全体を transaction で包んだり、業務本体へ認可 engine の呼び出しを埋め込んだりしない。
実行文脈は [concerns/context-propagation](../../concerns/context-propagation/README.md) に従い、業務入力と認証の文脈から分ける。

## 呼び出しと event の接続

adapter は、一つのコンテキストの公開 use-case または workflow へ接続する。
use-case の順序、結果による分岐、再開、補償は [core/application](../core/application.md) が定める。
コンテキストをまたぐ状態変更を同期の呼び出しで束ねない。
公開 event から受信側の application 入力への翻訳は、受信側の公開契約の adapter が所有する。
上流の公開 event の意味と下流の入力の対応を明示し、上流の型を受信側の domain へ流さない。
冪等キーと実行する主体の範囲を外部の契約から取り出す処理も、この層の写像として application の公開入力へ接続する。
