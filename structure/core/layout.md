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
│     └─ <external-system>
├─ shared/
│  └─ <shared-kernel>
└─ composition/
   ├─ build_core
   └─ operations/<operation>
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
`shared/` は、複数のコンテキストが値を共有するときにのみ置く。
`<context>/` の直下に置ける層は domain・application・infrastructure の3層であり、必要な層のみを置く。
generic と分類したコンテキストには、業務の不変条件を持つ集約を置かない。集約を持たなければ domain 層も置かない。分類は [principles/separation](../../principles/separation.md) に従う。
`<common-value>` は、一つのコンテキスト内で複数の集約が共有する値である。
集約が一つだけのコンテキストでは、common-value を置かず集約のファイル内に畳む。
値が一つのときは `<common-value>` を直に置き、二つ以上で `values/` に集める。
エラーの型は、値と同じ規則で置く。
`<shared-kernel>` は、複数のコンテキストが共有する値・エラーの型である。
shared-kernel は、値オブジェクトの constructor・不変条件・基本演算を持つ。
shared-kernel は、use-case と policy を持たない。
shared-kernel へ型を置けるのは、共有する全てのコンテキストで意味と変更理由が同一だと記録した場合に限る。
domain event はコンテキストの内部に閉じ、integration event は公開する application が所有するため、イベントの型は shared-kernel に置かない。
コンテキスト間の関係と型の共有の判定は [principles/separation](../../principles/separation.md) に従う。

## 単位

core 直下の単位の役割を示す。

| 単位 | 役割 |
|---|---|
| `<context>/` | 境界付けられたコンテキストを境界ごとに置く。コンテキストは互いに参照しない |
| `shared/` | 複数のコンテキストが共有する値・エラーの型を置く |
| `composition/` | コンテキストと adapter を配線し、canonical の写像と外部への入口を公開する |

同じコンテキストの複数の use-case にまたがる流れは、そのコンテキストの application workflow が担う。
コンテキストをまたぐ状態変更は、integration event で非同期に連携する。

## 依存方向

単位は依存の上下で3つの tier に分かれる。
下から shared、コンテキスト、composition の順に積み重なる。
参照は上位 tier から下位 tier へ向かう。
依存を一方向に保つ原則は [principles/separation](../../principles/separation.md) と [concerns/dependency](../../concerns/dependency.md) に従う。

単位をまたぐ参照は、参照先の公開面にのみ到達する。

| 参照元 | 公開面で参照可 | 参照不可 |
|---|---|---|
| composition | 各コンテキスト・shared | なし |
| コンテキスト | shared | 他のコンテキスト、composition |
| shared | なし | コンテキスト、composition |

コンテキストの公開面は、use-case と workflow の公開入口、公開の command・result・outcome 型、ports である。
コンテキストの domain は公開面に含まれず、domain event はコンテキストの内部に閉じる。
外部へ公開する event は、application が integration event へ写像し、公開 outcome に含める。
shared の公開面は shared-kernel である。
infrastructure は公開面に含まれない。
ただし composition は、配線のためにコンテキストの adapter の constructor を参照できる。
これが infrastructure を単位の外から参照する唯一の経路である。
公開面の要素だけを公開し、公開面の外にある要素は、言語の可視性の機構で閉じる。
全要素を一律に公開する構成や、公開面を定めず内側へ直接到達できる構成は認めない。
コンテキストの内部では、参照は infrastructure から application、application から domain へ向かう。
同一層内の参照は、各層の規則に従う。
循環は全域で禁止する。

## 正本契約の独立

canonical は contracts の正本スキーマであり、契約の定義と層は [contracts](../contracts/layout.md) で規定する。
wire 契約と生成物も contracts の層であり、これらを利用するのは [surfaces](../surfaces/) と [runtimes](../runtimes/) である。
core と contracts のあいだで許す参照は [skeleton](../skeleton.md) に従う。
core の内部では composition だけが canonical に触れ、canonical とコンテキストの入出力の写像を [composition](./composition.md) に置く。

## 1 ファイル 1 概念

ファイル一つを変更単位一つに対応させる。
変更単位は、集約・use-case・workflow・store・operation などの末端要素である。
下位の型は変更単位のファイル内に記述する。
下位の型のうち、複数の変更単位で共有するもの、または肥大したもののみを別ファイルへ分離する。
values・events・ports などの集合フォルダは、要素が二つ以上の場合に置く。
shared-kernel も、値・エラーが二つ以上になれば、同じ規則で集合フォルダに分ける。

## 外部公開

core が外部へ公開するのは composition の `build_core` のみである。
`build_core` は組み立て済みの API を返し、起動は行わない。
プロセスの起動は、core を埋め込む surface または host が担う。
