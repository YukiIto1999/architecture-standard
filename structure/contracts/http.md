# http 層

http 層は、canonical を HTTP の wire へ束ねる binding を定める層である。
http は、プロセスをまたぐ通信の媒体にだけ置く。
http は [layout](./layout.md) の依存に従い、canonical を参照する。

## wire への射影

http は、canonical の操作を path・method・status へ写像する。
http は、固有の意味を持たず、canonical の意味を wire へ表すだけである。

## スタイル

http は、REST と OpenAPI 3.x に従う。
表現の形式は、JSON に統一する。
エラーの表現は、RFC 9457 の problem+json に束ねる。

## 通信様式

http は、request と response の往復を既定とし、状態の変化は client からの再取得で反映する。
push(server から client への配信)は、標準外とする。
片方向の push は SSE、双方向の push は WebSocket とする。
push を採る project は、標準の単一性([README](../../README.md))に従い project の ADR に記録する。
