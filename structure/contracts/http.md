# http 層

http 層は、canonical を HTTP の wire へ束ねる binding を定める層である。
http は、プロセスをまたぐ通信の媒体にだけ置く。
http は [layout](./layout.md) の依存に従い、canonical を参照する。

## wire への射影

http は、canonical の操作を path・method・status へ写像する。
http は、固有の意味を持たず、canonical の意味を wire へ表すだけである。
path の階層に、リソースの親子関係を深く刻まない。
階層は、一度公開すると変えにくい。
提供しない method は、405 で拒む。

## リクエストの置き場所

操作の入力は、body を既定にする。
header は、認証や追跡のような横断的関心事に限り、エンドポイント固有の入力を置かない。
query は、集合の絞り込み・並び・頁に限る。

## スタイル

http は、REST と OpenAPI 3.x に従う。
表現の形式は、JSON に統一する。
エラーの表現は、RFC 9457 の problem+json に束ねる。
HTTP 仕様の SHOULD の規定には、明確な理由がない限り従う。
エラーの内部の詳細は外部の応答へ出さず、利用者の語彙へ翻訳して返す。
内部の詳細を出さない規律は [concerns/effect](../../concerns/effect.md) に従う。

## 作成の応答

作成の成功は、201 と、作成されたリソースの表現と、Location header で返す。

## cache 可能性

POST と PUT の wire 上の違いは、応答の cache 可能性に現れる。
cache の扱いは、RFC 9111 に従う。
部分的な表現を、cache 可能として返さない。

## 通信様式

http は、request と response の往復を既定とし、状態の変化は client からの再取得で反映する。
push(server から client への配信)は、標準外とする。
片方向の push は SSE、双方向の push は WebSocket とする。
push を採る project は、標準の単一性([README](../../README.md))に従い project の ADR に記録する。
