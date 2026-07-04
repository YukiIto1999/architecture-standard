# core の構造

core のフォルダ構成と、単位間の依存・契約・粒度の規則を定める。
横断的な規律は [concerns](../../concerns/) に、言語別の実現は [languages](../../languages/) に置く。
各層と composition の内部は、[domain](./domain.md)・[application](./application.md)・[infrastructure](./infrastructure.md)・[composition](./composition.md) で規定する。

## フォルダ構成

```
core/
├─ modules/
│  └─ <module>/
│     ├─ domain/
│     │  ├─ <aggregate>
│     │  ├─ <common-value>
│     │  ├─ values/
│     │  └─ events/
│     ├─ application/
│     │  ├─ <use-case>
│     │  └─ ports/<port>
│     └─ infrastructure/
│        ├─ persistence/<aggregate>-store
│        └─ <external-system>
├─ submodules/
│  └─ <submodule>/
│     ├─ domain/
│     ├─ application/
│     └─ infrastructure/
├─ shared/
│  └─ <shared-kernel>
└─ composition/
   ├─ build_core
   ├─ config
   └─ operations/<operation>
```

`modules/` と `composition/` は常に置く。
`submodules/` と `shared/` は、必要なときにのみ置く。
`<module>/` と `<submodule>/` の直下に置ける層は domain・application・infrastructure の3層であり、必要な層のみを置く。
`<common-value>` は、一つの module 内で複数の集約が共有する値である。
集約が一つだけの module では、common-value を置かず集約のファイル内に畳む。
値が一つのときは `<common-value>` を直に置き、二つ以上で `values/` に集める。
エラーの型は、値と同じ規則で置く。
`<shared-kernel>` は、複数の module が共有する値・エラー・イベントの型である。
shared-kernel は、value object の constructor・不変条件・基本演算を持つ。
shared-kernel は、use-case と policy を持たない。

## 単位

core 直下の4つの単位の役割を示す。

| 単位 | 役割 |
|---|---|
| `modules/` | 業務 module を業務境界ごとに置く。module は互いに参照しない |
| `submodules/` | 技術的関心の submodule を置く。submodule は業務を参照しない |
| `shared/` | 複数の module が共有する値・エラー・イベントの型を置く |
| `composition/` | module を配線し、module をまたぐ流れを担い、外部への入口を公開する |

module をまたぐ流れは composition が担う。
submodule の内部構造は module と同一であり、相違は対象が技術であって業務を参照しない点のみである。
submodule は、自前の domain を持つ独立した技術のパッケージであり、複数の module から port を介して使われるものに限って作る。
submodule は技術的関心なので、domain の単位は業務の集約でなく一つの技術機構である。
機構の境界は提供する目的が決め、その中身は目的を実現する型と判断の凝集である。
全文検索の索引、ジョブのスケジューリング、識別子の採番のように、純粋な判断と自前の port を持つ技術の subsystem がこれにあたる。
submodule は、煩雑な扱いを抽象化して単一の責務に閉じた能力である。
submodule は、公開してもよいリリース単位のパッケージとして凝集させる。
一緒にリリースし、一緒に変わり、一緒に使う機構を一つにまとめる。
単一の機能ごとに割らず、雑多な寄せ集めにもしない。
名は提供する能力を表す記述的で精密なものにし、effect・clock・common・util のような一般名を付けない。
複数の module が共有する値や型そのものは shared に置き、port と判断を伴う能力は submodule に置く。
能力に属する値や型は、その submodule の domain に置く。
単一の module の中で port の実装を与えるだけの技術接続は、submodule に切り出さず infrastructure の adapter に置く。
判断を持たず境界の殻で行う横断の関心は、submodule にせず composition の観測に置く。

## 言語拡張の companion

型の網羅の検査、値オブジェクトの生成、効果の規律の強制のように、言語に欠ける compile 時の検査と生成を補う仕組みは、ビルド時のツールであって実行時の単位ではない。
これは実行時の層に属さず、出荷物にも含まれず、対象とは別のコンパイル単位になる。
だから companion を core の tier(modules・submodules・shared・composition)の外に置き、[skeleton](../skeleton.md) が定める companion の境界に収める。
companion を domain・application・infrastructure のどの層にも、submodule にも入れない。
言語ごとの検査と生成の機構、およびその構築と参照の仕方は [languages](../../languages/) に従う。

## 依存方向

単位は依存の上下で4つの tier に分かれる。
下から submodules、shared、modules、composition の順に積み重なる。
参照は上位 tier から下位 tier へ向かい、submodules の tier の中でも下位の submodule へ向かう。
単方向依存の原則は [principles/separation](../../principles/separation.md) と [concerns/dependency](../../concerns/dependency.md) に従う。

単位をまたぐ参照は、参照先の公開面にのみ到達する。

| 参照元 | 公開面で参照可 | 参照不可 |
|---|---|---|
| composition | modules・shared・submodules | なし |
| modules | shared・submodules | 他の module、composition |
| shared | submodules | modules、composition |
| submodules | 下位の submodule | shared、modules、composition |

submodules の tier の中では、下位の submodule を上位の submodule が参照してよい。
この submodule どうしの依存は非循環の一方向に限り、循環を作らない。

module の公開面は、use-case の公開入口、公開の command・result・outcome 型、ports である。
module の domain は公開面に含まれず、domain の event は use-case が outcome として返す形でのみ外へ出る。
submodule は他の単位へ純粋な判断と値を型として提供するため、公開面に domain を含める。
submodule が domain を公開面に含めるのは、業務判断を内に隠す module とは非対称であり、submodule が技術の再利用部品である点に由来する。
submodule の公開面は、純粋な判断と値を表す domain と、効果を宣言する application の port に分かれる。
shared の公開面は shared-kernel である。
純粋な側が submodule を参照するのは、submodule の domain の純粋な型に限る。
純粋な側とは、shared と各 module の domain、および下位の submodule を使う submodule の domain である。
submodule の application の port を使うのは、各 module の application と infrastructure の adapter、composition、および上位の submodule の application に限る。
infrastructure は公開面に含まれない。
ただし composition は、配線のために module と submodule の adapter の constructor を参照できる。
これが infrastructure を単位の外から参照する唯一の経路である。
公開面の要素だけを公開し、公開面の外にある要素は、言語の可視性の機構で閉じる。
全要素を一律に公開する構成や、公開面を定めず内側へ直接到達できる構成は認めない。
module と submodule の内部では、参照は infrastructure から application、application から domain へ向かう。
同一層内の参照は、各層の規則に従う。
循環は全域で禁止する。

## 正本契約の独立

canonical は contracts の正本スキーマであり、契約の定義と層は [contracts](../contracts/layout.md) で規定する。
wire 契約と生成物も contracts の層であり、これらを利用するのは [surfaces](../surfaces/) と [runtimes](../runtimes/) である。
core と contracts のあいだで許す参照は [skeleton](../skeleton.md) に従う。
core の内部では composition だけが canonical に触れ、canonical と module の入出力の写像を [composition](./composition.md) に置く。

## 1 ファイル 1 概念

ファイル一つを変更単位一つに対応させる。
変更単位は、集約・use-case・store・operation などの末端要素である。
下位の型は変更単位のファイル内に記述する。
下位の型のうち、複数の変更単位で共有するもの、または肥大したもののみを別ファイルへ分離する。
values・events・ports などの集合フォルダは、要素が二つ以上の場合に置く。
shared-kernel も、値・エラー・イベントが二つ以上になれば、同じ規則で集合フォルダに分ける。

## 外部公開

core が外部へ公開するのは composition の `build_core` のみである。
`build_core` は組み立て済みの API を返し、起動は行わない。
プロセスの起動は、core を埋め込む surface または host が担う。
