# protocol 層

protocol 層は、canonical を非 HTTP のローカル protocol へ束ねる binding を定める層である。
protocol は、プロセスまたは言語の ABI をまたぐ非 HTTP のローカル通信に置き、埋め込み surface との通信と、webview と host の IPC を含める。
protocol は [layout](./layout.md) の依存に従い、canonical を参照する。

## wire への射影

protocol は、canonical の操作を、選んだ protocol の要求と応答へ写像する。
protocol は固有の意味を持たず、canonical の意味を wire へ表すだけである。
この binding から生成したデータ型を、提供側と利用側の要求と応答に使う。
通信 stub はその通信を所有する境界に置く。
core の業務操作へ接続する受信口は、生成したデータ型を契約 adapter の保護された公開入口へ渡す。
host の設定や要求の中継と取消など、host が所有する技術操作は host の公開 Interface へ接続し、そのための core の operation を新設しない。
データ型と stub の分離と生成能力は [generated](./generated.md) に従う。
同一プロセスの native 境界でも、ABI は生成した codec の payload を渡す媒体とし、業務の DTO や管理された object の配置を ABI の共有構造にしない。
ABI の呼出規約、buffer と handle の所有権、初期化・準備・停止、非同期要求の識別・完了・取消を binding に定め、両端の stub を同じ定義から生成する。

## スタイル

protocol は、言語非依存の単一の形式に従う。
エラーの表現は、canonical のエラーを protocol の失敗の形へ写す。

## 機構

具体の protocol は標準に固定せず、project が単一の採用を決定の記録に明記する。
失敗の形式も、protocol の採用とあわせて決定の記録に明記する。
HTTP と違い、ローカル protocol には problem+json のような単一の標準形式が定まらないためである。
