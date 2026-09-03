# http 層

http 層は、canonical を HTTP の wire へ束ねる binding を定める層である。
http は、プロセスをまたぐ通信の媒体にだけ置く。
http は [layout](./layout.md) の依存に従い、canonical を参照する。

## wire への射影

http は、canonical の操作を path・method・status へ写像する。
request semantics は method 自身が持ち、target resource は method と矛盾しない形で操作を処理する。
http は、canonical の意味を、method が定める protocol semantics と整合させて wire へ表す。
path の階層に、リソースの親子関係を深く刻まない。
階層は、一度公開すると変えにくい。
提供しない method は、405 で拒む。

## method の選択

POST は、target resource 固有の意味に従って request content を処理する操作に使う。
server が新しい resource の URI を選ぶ作成は、POST に写像する。
PUT は、client が既知の target URI を指定し、その target resource の完全な desired state を作成または置換する操作に使う。
PUT は idempotent であり、POST は HTTP の定義上 idempotent ではない。
method は操作の意図で選び、応答の cache 可能性を中核の差にしない。

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
内部の詳細を出さない規律は [concerns/effect](../../concerns/effect/README.md) に従う。

## 作成の応答

新しい resource を作成した場合は、201 を返す。
POST の処理で resource を作成した場合は、primary resource を識別する `Location` header を返すべきである。
client が target URI を指定した PUT では、`Location` header を一律に要求しない。
既存の target resource を PUT で変更した場合は、表現を返すなら 200、表現を返さないなら 204 を返す。

## cache 可能性

cache の扱いは、RFC 9111 に従う。
POST の応答を cache するには、明示的な freshness 情報と、target URI に一致する `Content-Location` の両方を必要とする。
PUT の応答は cache しない。
cache は、unsafe method への non-error response を受けたとき、その request の target URI に対する保存済み応答を無効にする。
この無効化は POST、PUT、DELETE に共通する規則であり、各 method の応答を cache できるかとは別に扱う。

## 通信様式

http は、request と response の往復を既定とし、状態の変化は client からの再取得で反映する。
push(server から client への配信)は、標準外とする。
片方向の push は SSE、双方向の push は WebSocket とする。
push を採る project は、標準の単一性([README](../../README.md))に従い project の ADR に記録する。
