# core の構造

core のフォルダ構成と、単位間の依存・契約・粒度の規則を定める。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
各層と composition の内部は、[domain](./domain.md)・[application](./application.md)・[infrastructure](./infrastructure.md)・[composition](./composition.md) で規定する。

## フォルダ構成

project が複数の境界付けられたコンテキストを持つとき、core はコンテキストごとに層を分ける。

```
core/
├─ <context>/
│  ├─ domain/
│  │  ├─ <aggregate>
│  │  ├─ <common-value>
│  │  ├─ values/
│  │  └─ events/
│  ├─ application/
│  │  ├─ <use-case>
│  │  ├─ workflows/<workflow>
│  │  └─ ports/<port>
│  └─ infrastructure/
│     ├─ persistence/<aggregate>-store
│     ├─ migrations/
│     └─ <external-system>
└─ composition/
   └─ build_core
```

境界付けられたコンテキストが一つだけの project では、`<context>/` を置かず domain・application・infrastructure を core 直下に畳む。
この畳み込みは、集約が一つだけのコンテキストで common-value を畳むのと同じ一様規則である。

```
core/
├─ domain/
├─ application/
├─ infrastructure/
└─ composition/
```

`composition/` は常に置く。
`<context>/` は、境界付けられたコンテキストが複数あるときにのみ置く。
`<context>/` の直下に置ける層は domain・application・infrastructure の3層であり、必要な層のみを置く。
generic と分類したコンテキストには、業務の不変条件を持つ集約を置かない。
集約を持たなければ domain 層も置かない。
分類は [principles/separation](../../principles/separation/README.md) に従う。
`<common-value>` は、一つのコンテキスト内で複数の集約が共有する値である。
集約が一つだけのコンテキストでは、common-value を置かず集約のファイル内に畳む。
値が一つのときは `<common-value>` を直に置き、二つ以上で `values/` に集める。
エラーの型は、値と同じ規則で置く。
複数のコンテキストに共通の業務型を置く `core/shared/` は設けない。
業務を知らない技術機構の共用は [libs](../libs/layout.md) が定める。

## 単位

core 直下の単位の役割を示す。

| 単位 | 役割 |
|---|---|
| `<context>/` | 業務の判断・状態・確定・進行を独立して所有する境界付けられたコンテキストを置く |
| `composition/` | 各コンテキストと adapter の公開された構築用 API を使い、独立した application 入口と技術能力を配線する |

コンテキストの分割は [principles/separation](../../principles/separation/context-relationships.md) の「コンテキストを業務上独立させる」に従う。
業務上の独立性を満たした境界を、相互参照の禁止と可視性で実装する。
一つのコンテキストの複数モデルを扱う業務動作は、その application の use-case が組み立てる。
同じコンテキスト内で複数の確定点にまたがる進行は application が所有し、独立した調整の責務がある場合だけ workflow を置く。
独立した外部の操作と事実への接続は、各コンテキストが宣言する port と公開 application Interface を通す。
一つの業務操作、不変条件、transaction、進行を複数のコンテキストが必要とする場合は、port、integration event、workflow、composition に調整を移さず、境界を引き直す。

コンテキストの境界は、言語の可視性の単位(assembly・crate・package)と一致させ、境界の遵守を可視性の機械検査に載せる。
コンテキストに属する単体の test は、そのコンテキストの内に置き、コンテキストを跨いだ平置きにしない。

## 依存方向

composition から独立した各コンテキストへ依存し、コンテキストどうしは参照しない。
依存を一方向に保つ原則は [principles/separation](../../principles/separation/README.md) と [concerns/dependency](../../concerns/dependency/README.md) に従う。

単位をまたぐ参照は、参照先の公開面にのみ到達する。

| 参照元 | 公開面で参照可 | 参照不可 |
|---|---|---|
| composition | 各コンテキスト | なし |
| コンテキスト | なし | 他のコンテキスト、composition |

コンテキストは、独立して所有する use-case と必要な workflow の入口、公開入力構築、command・result・outcome を公開する。
この Interface は application が業務上の責務から手で定義し、外部の公開契約や生成 Interface の写しにしない。
port は application が要求する能力の契約であり、adapter を構築するために必要な範囲だけを公開する。
コンテキストの domain は公開面に含まれず、domain event はコンテキストの内部に閉じる。
外部へ公開する event は、application が integration event へ写像し、公開 outcome に含める。
infrastructure は公開面に含まれない。
composition が配線で使う adapter の constructor は、構築用の公開面として明示する。
組立点も公開された構築用 API だけを使い、非公開の adapter や内部の型へ到達しない。
公開面の要素だけを公開し、公開面の外にある要素は、言語の可視性の機構で閉じる。
全要素を一律に公開する構成や、公開面を定めず内側へ直接到達できる構成は認めない。
コンテキストの内部では、参照は infrastructure から application、application から domain へ向かう。
同一層内の参照は、各層の規則に従う。
循環は全域で禁止する。

## 公開契約と業務モデルの独立

外部の公開契約の定義、binding、生成物と adapter は [contracts](../contracts/layout.md) が定める。
公開契約と core の業務モデルは、それぞれが異なる責務と変更理由から独立して所有し、共通のモデル定義や型から生成しない。
core と contracts のあいだで許す参照は [skeleton](../skeleton.md) に従う。
core は composition を含め、公開契約の定義、生成した型・構築・codec・Interface、binding、通信実装を参照しない。
コンテキスト固有の command、result、domain 型はそのコンテキストが所有し、独立した application Interface と公開契約の写像は [contracts/adapters](../contracts/adapters.md) が担う。

## 1 ファイル 1 概念

ファイル一つを変更単位一つに対応させる。
変更単位は、集約・use-case・workflow・store・operation などの末端要素である。
下位の型は変更単位のファイル内に記述する。
下位の型のうち、複数の変更単位で共有するもの、または肥大したもののみを別ファイルへ分離する。
values・events・ports などの集合フォルダは、要素が二つ以上の場合に置く。

## 外部公開

core の構築入口は composition の `build_core` だけである。
`build_core` は組み立て済みの API を返し、公開 application 入口、公開入力構築、result と outcome の Interface を利用側へ渡す。
プロセスの起動は、core を埋め込む surface または host が担う。
外部からの実行は、組み立て済みの API が公開する application の入口を通し、infrastructure の関数や識別子を composition から再公開しない。
業務を知らずに定められる技術的な子 process の契約と実行入口は [libs](../libs/layout.md) が所有し、core をその仲介にしない。
