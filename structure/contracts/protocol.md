# protocol 層

protocol 層は、canonical を非 HTTP のローカル protocol へ束ねる binding を定める層である。
protocol は、埋め込み surface とのプロセスをまたぐ通信の媒体にだけ置く。
protocol は [layout](./layout.md) の依存に従い、canonical を参照する。

## wire への射影

protocol は、canonical の操作を、選んだ protocol の要求と応答へ写像する。
protocol は固有の意味を持たず、canonical の意味を wire へ表すだけである。

## スタイル

protocol は、言語非依存の単一の形式に従う。
エラーの表現は、canonical のエラーを protocol の失敗の形へ写す。

## 機構

具体の protocol は標準に固定せず、project が単一の採用を ADR に明記する。
失敗の形式も、protocol の採用とあわせて ADR に明記する。HTTP と違い、ローカル protocol には problem+json のような単一の標準形式が定まらないためである。
