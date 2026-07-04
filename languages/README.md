# languages

languages は、言語ごとの実現である。
principles・concerns・structure の上位規律に従属し、上位規律を再定義しない。
上位規律が定めた形を、各言語の採用機構でどう満たすかだけを定める。

## 実現軸

言語ごとのファイルは、実現軸で分ける。
実現軸は、コード上で責務が現れる場所を表す。
各言語に、同じ7つの実現軸を置く。
採用するツール・機構・framework は、ファイル名にせず本文に書く。

| ファイル | 実現軸の意味 |
|---|---|
| formation | 値・型・不変条件のモデリング |
| translation | 外界境界での意味の出し入れ |
| connection | 副作用と依存の渡し方 |
| retention | 永続化と共有される状態 |
| coordination | 非同期・並行・取り消しの実行 |
| publication | 外部公開面と host |
| inspection | 検証 |

## 言語と役割

| 言語 | 役割 | 基盤の版 |
|---|---|---|
| [rust](./rust/) | server・console・worker・desktop と mobile の host・extension が接続する core のプロセスと言語サービス | edition 2024 |
| [csharp](./csharp/) | server・console・worker・desktop と mobile の host・extension が接続する core のプロセス | .NET 10・C# 14 |
| [typescript](./typescript/) | viewer・extension・web と ide の host | TypeScript 6.0 |

project は、core の言語を一つ選び、選定の理由と単一採用を project の ADR に記録する。
選ぶ基準は、上表の役割の差である。
extension が言語サービスを要する構成では、rust を選ぶ。
自己ホストの surface と、desktop・mobile の host は、core の言語に従う。
web の host の platform は browser であり、言語を持たない。
その bundler と entry は typescript が担う。
基盤の版の改訂は、standard-update で行う。

rust と csharp は、skeleton が定める companion の境界にビルド時のツール crate・project を持つ。
typescript は、型が compile 時にのみ存在し実行時には消えるので、companion に相当する別のビルド時ツールを持たない。
未充足の台帳は [gaps](./gaps.md) に置く。

## 単一性

同じ目的の機構は、一つの言語の中で一つに固定する。
languages が機構を定めていない目的では、project が単一の採用を ADR に明記する。
逸脱は、project の ADR に採用理由・撤回条件・単一採用を明記する。
機構は、無償の部品を土台にし、残った不足分だけを自作する。

## 読み方

各ファイルは、`## 概要` で従う上位規律への参照を述べる。
その下に実現軸内の規律ごとの `## 規律名` を置き、各規律を必須の5節で書く。末尾に `## 参照` を置く。
inspection.md は、`## 参照` の直前に `## 規則と検証機構の対応` の付表を置き、規律ごとの検証手段を一覧にする。

- 要求は、その言語でどの機構をどう使うかを命令の一文で書く。
- 根拠は、上位規律の再導出でなく、その言語の機構で上位規律をどう満たすかを述べる。
- 完了条件は、満たされた状態を観測できる形で示す。
- 禁止事項は、してはならないことを書く。
- 行動は、適用と是正の手順を書く。
- 例は、避けたい書き方と望ましい書き方をその言語の実コードで対比し、規律を明確にするのに役立つときだけ加える。

採用するツール・機構・framework は、ファイル名にせず本文に書く。
機構の規律が上位規律と重なるときは、上位規律が正である。
