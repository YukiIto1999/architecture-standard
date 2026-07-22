# languages

languages は、言語ごとの実現である。
principles・concerns・structure の上位規律に従属し、上位規律を再定義しない。
上位規律が定めた形を、各言語の採用機構でどう満たすかだけを定める。

## 実現軸

言語ごとのファイルは、実現軸で分ける。
実現軸は、コード上で責務が現れる場所を表す。
各言語に、同じ7つの実現軸と1つの全域規律を置く。
実現軸はコード上で責務が現れる場所ごとに分かれ、全域規律は特定の置き場を持たず全ての実現軸に一様に適用する。
採用するツール・機構・framework は、ファイル名にせず本文に書く。

| ファイル | 意味 |
|---|---|
| formation | 値・型・不変条件のモデリング(実現軸) |
| translation | 外界境界での意味の出し入れ(実現軸) |
| connection | 副作用と依存の渡し方(実現軸) |
| retention | 永続化と共有される状態(実現軸) |
| coordination | 非同期・並行・取り消しの実行(実現軸) |
| publication | 外部公開面と host(実現軸) |
| inspection | 検証(実現軸) |
| conventions | 命名・整形・ドキュメントコメント・型名接尾辞(全域規律) |

## 言語と役割

| 言語 | 役割 | 基盤の版 |
|---|---|---|
| [rust](./rust/) | server・console・worker・desktop と mobile の host・extension が接続する core のプロセスと言語サービス | edition 2024 |
| [csharp](./csharp/) | server・console・worker・desktop と mobile の host・extension が接続する core のプロセス | .NET 10・C# 14 |
| [typescript](./typescript/) | viewer・extension・web と ide の host | TypeScript 6.0 |

core の言語の選定は、[tools/language](../tools/language.md) が定める。
自己ホストの surface と、desktop・mobile の host は、core の言語に従う。
web の host の platform は browser であり、言語を持たない。
その bundler と entry は typescript が担う。
基盤の版の改訂は、standard-update で行う。
遵守は、各実現軸の規律の完了条件と禁止事項で照合して判定する。

rust と csharp は、[structure/libs/layout](../structure/libs/layout.md) が定める libs の機構として、companion のビルド時ツール crate・project を持つ。
typescript は、型が compile 時にのみ存在し実行時には消えるので、companion に相当する別のビルド時ツールを持たない。

## 単一性

同じ目的の機構は、一つの言語の中で一つに固定する。
languages が機構を定めていない目的では、project が単一の採用を ADR に明記する。
逸脱は、root の [README](../README.md) が定める要件に従う。
機構は、無償の部品を土台にし、残った不足分だけを自作する。

## 読み方

各ファイルは、`## 概要` で従う上位規律への参照を述べる。
その下に軸内の規律ごとの `## 規律名` を置き、各規律を必須の5節で書く。末尾に `## 参照` を置く。
conventions.md も同じ書式に従うが、置き場を持たず全ての実現軸に一様に適用する規律である点だけが異なる。
inspection.md は、`## 参照` の直前に `## 規則と検証機構の対応` の付表を置き、規律ごとの検証手段を一覧にする。

- 要求は、その言語でどの機構をどう使うかを命令の一文で書く。
- 根拠は、上位規律の再導出でなく、その言語の機構で上位規律をどう満たすかを述べる。
- 完了条件は、満たされた状態を観測できる形で示す。
- 禁止事項は、してはならないことを書く。
- 行動は、適用と是正の手順を書く。
- 例は、避けたい書き方と望ましい書き方をその言語の実コードで対比し、規律を明確にするのに役立つときだけ加える。

採用するツール・機構・framework は、ファイル名にせず本文に書く。
機構の規律が上位規律と重なるときは、上位規律が正である。
