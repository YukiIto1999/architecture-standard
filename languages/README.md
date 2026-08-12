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

| 言語 | 役割 |
|---|---|
| [rust](./rust/) | server・console・worker・desktop と mobile の host・extension が接続する core のプロセスと言語サービス |
| [csharp](./csharp/) | server・console・worker・desktop と mobile の host・extension が接続する core のプロセス |
| [typescript](./typescript/) | viewer・extension・web と ide の host |

標準は project の実装言語を選定しない。
実装単位と言語の対応を適用時の入力とし、[tools/language](../tools/language.md) が定める対象言語のうち使用する各言語の規律を適用する。
自己ホストの surface と、desktop・mobile の host は、core の言語に従う。
web の host の platform は browser であり、言語を持たない。
その bundler と entry は typescript が担う。
基盤の版は [tools/language](../tools/language.md) が定め、改訂は standard-update で行う。
遵守は、各実現軸の採用機構と規律の完了条件・禁止事項で照合して判定する。

## 単一性

同じ目的の機構は、一つの言語の中で一つに固定する。
languages が機構を定めていない目的では、project が単一の採用を ADR に明記する。
逸脱は、root の [README](../README.md) が定める要件に従う。
機構の採用は、[tools](../tools/) の選定の共通基準に従う。

## 読み方

各ファイルは、`## 概要` で従う上位規律への参照を述べる。
その下に軸内の規律ごとの `## 規律名` を置き、各規律を必須の5節で書く。末尾に `## 参照` を置く。
conventions.md も同じ書式に従うが、置き場を持たず全ての実現軸に一様に適用する規律である点だけが異なる。
inspection.md は、`## 参照` の直前に `## 規則と検証機構の対応` の付表を置き、規律ごとの検証手段を一覧にする。

- 要求では、言語機構ごとに守る規則を一文単位に分け、命令形で記す。
- 根拠は、上位規律の再導出でなく、その言語の機構で上位規律をどう満たすかを述べる。
- 完了条件は、満たされた状態を観測できる形で示す。
- 禁止事項は、してはならないことを書く。
- 行動は、適用と是正の手順を書く。
- 例は、避けたい書き方と望ましい書き方をその言語の実コードで対比し、規律を明確にするのに役立つときだけ加える。

採用するツール・機構・framework は、ファイル名にせず本文に書く。
機構の規律が上位規律と重なるときは、上位規律が正である。
