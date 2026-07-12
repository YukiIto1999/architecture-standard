# stack

stack は、骨格を握る採用と、骨格から呼ばれる部品の採用を定める。
骨格は、プロセスや面の制御を握り、実装の呼び出しを枠組みの側が行う。
部品は、骨格や業務の核から呼ばれ、直列化・非同期実行・接続・検証など個別の性質を満たす。
エントリは、[README](./README.md) の書式と選定の共通基準に従う。
core の言語に依存する採用は、言語ごとに単一の名指しを持つ。
使い方の規律は、[languages](../languages/) の該当する実現軸に従う。

## server

用途は、HTTP の API を公開する surface の骨格である。
採用は、Rust は axum、C# は ASP.NET Core の Minimal API である。
判断基準は、依存を組立点から handler へ注入でき、境界の仕込みを middleware で一括して積めることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止とリリースポリシーの変化を再評価のトリガーとする。

## console

用途は、CLI の surface の骨格である。
採用は、Rust は clap、C# は ConsoleAppFramework である。
判断基準は、引数を型で宣言して境界で一度 parse でき、依存を組立点から注入できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 非同期の runtime

用途は、非同期の実行を担う runtime である。
採用は、Rust は Tokio である。C# と TypeScript は言語・実行環境に組み込みの非同期基盤を使い、外部の runtime を別に選ばない。
判断基準は、runtime を一つに固定でき、タスクの生成・取り消し・channel の扱いを一貫させられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## worker

用途は、背景処理と定期実行の daemon の骨格である。
採用は、Rust は apalis、C# は Wolverine であり、いずれも PostgreSQL を backend にした queue に限って使う。
判断基準は、queue と scheduler を既存の datastore に閉じ、外部の broker を開かないことである。
撤回条件は、判断基準を満たさなくなることであり、backend の対応状況の変化と apalis の 1.0 リリースを再評価のトリガーとする。

## viewer

用途は、GUI の surface を組む骨格である。
採用は、SolidJS である。
判断基準は、composition root から provider と ui port を注入する形で組め、被ホストの surface として host から切り離せることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## styling の機構

用途は、styling を組む機構である。
採用は、TypeScript は Tailwind CSS の Vite plugin である。
判断基準は、design token を一元化でき、CSS をビルド時に静的に出せることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## headless component の振る舞い

用途は、見た目を持たない振る舞いだけの UI component を提供する機構である。
採用は、TypeScript は Kobalte である。
判断基準は、振る舞いと design token による見た目を分離できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## web の host

用途は、web の host の entry と bundler である。
採用は、Vite である。
判断基準は、index.html を entry として扱え、build の設定をテストと共有できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## desktop と mobile の host

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が Rust のときは desktop・mobile ともに Tauri、core が C# のときは desktop は Photino.NET、mobile は .NET MAUI の HybridWebView である。
判断基準は、OS 内蔵の webview に同じ viewer を載せ、core を host の back-end に置けることである。
core が C# のときの desktop は、core の言語と host の言語を合わせて構成の複雑さを避けるため Photino.NET を採り、Tauri に C# の sidecar を載せる形は採らない。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化を再評価のトリガーとする。

## BFF の token 管理

用途は、BFF が保持する token の交換と更新を担う機構である。
採用は、C# は Duende.AccessTokenManagement である。Rust は project が単一の採用を ADR に明記する。
判断基準は、Apache License 2.0 の OSS で token の保持と更新を server 側で担えることであり、Duende の商用製品(BFF・IdentityServer)は範囲に含めない。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。

## BFF の session 管理

用途は、BFF が session を保持し cookie で運ぶ機構である。
採用は、Rust は tower-sessions である。C# は ASP.NET Core 標準の cookie 認証を使い、外部ライブラリを別に選ばない。
判断基準は、既定で Secure・HttpOnly・SameSite=Strict な安全な cookie を発行できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## BFF の中継

用途は、BFF が resource への要求を中継する機構である。
採用は、C# は YARP である。Rust は project が単一の採用を ADR に明記する。
判断基準は、同一オリジンの中継で内部の JWT を付与できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## OIDC クライアント

用途は、OIDC の code と PKCE のフローを終端し ID Token を検証するクライアントである。
採用は、Rust は openidconnect である。C# は ASP.NET Core 標準の handler を使い、外部ライブラリを別に選ばない。
判断基準は、ID Token を nonce と at_hash で検証できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 効果の表現(viewer・extension・host)

用途は、viewer・extension・host の軽い役割に見合う、副作用と想定内失敗を型で表す機構である。
採用は、TypeScript は neverthrow である。Rust と C# は言語機構(Future・Result / Effect 型)で表し、外部ライブラリを採らない。
判断基準は、軽量な Result 型を提供することである。effect-ts のような要求チャネル・依存注入・fiber runtime を含む重い FW は、server 側の効果と永続化を持たない役割に対して過大である。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 境界の値検証

用途は、外部入力を schema で検証し、検証済みの値だけに型を名乗らせる機構である。
採用は、TypeScript は valibot である。
判断基準は、schema から型を導出でき、Standard Schema V1 に適合し他のツールとの相互運用を保てることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## エラー型の定義

用途は、責務の単位でエラー型を宣言し表示と変換を導出する機構である。
採用は、Rust は thiserror である。C# は sealed record の階層、TypeScript は判別子つきの union という言語機構で表し、外部ライブラリを採らない。
判断基準は、エラー型の表示と変換の定型実装を導出でき、`?` による伝播と組み合わせられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## dyn な非同期 port

用途は、実行時に差し替える非同期の port を動的ディスパッチで扱う機構である。
採用は、Rust は async-trait である。
判断基準は、edition のネイティブな async trait が dyn に乗らない制約を補い、trait の非同期メソッドを dyn で差し替え可能にすることである。
撤回条件は、判断基準を満たさなくなることであり、edition のネイティブな async trait が dyn に対応することを再評価のトリガーとする。

## 直列化

用途は、値を wire 形式と相互に直列化・逆直列化する機構である。
採用は、Rust は serde である。C# は言語標準の source generation(JsonSerializerContext)を使い、TypeScript は境界の値検証に使う schema から導出し、いずれも外部の直列化ライブラリを別に選ばない。
判断基準は、値の直列化と逆直列化を型に基づいて行え、境界の DTO の宣言と一体で使えることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 永続化アクセス

用途は、SQL を型で扱いながら書く永続化アクセス層である。
採用は、Rust は sqlx、C# は Npgsql の上の Dapper である。
判断基準は、SQL を隠さず、事実の形がそのまま型に写ることである。フル ORM は SQL を不透明にしたり、変更追跡で確定の時点を暗黙にしたりするため採らない。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 一時 store への接続

用途は、Valkey へ接続する client である。
採用は、Rust は fred、C# は StackExchange.Redis である。
判断基準は、接続の pooling と再接続を備え、session・cache・一時データの読み書きを一つの client に集約できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## ide の host

用途は、extension の surface を動かす ide の host である。
採用は、VSCode である。
判断基準は、host の能力を port の adapter で満たせ、webview で viewer をホストできることである。
撤回条件は、判断基準を満たさなくなることであり、市場と拡張 API の変化を再評価のトリガーとする。

## 言語サービスの公開

用途は、extension が接続する core のプロセスが言語機能を公開する骨格である。
採用は、tower-lsp である。
判断基準は、protocol と transport を枠組みが担い、自前で書くのが振る舞いだけになることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
言語サービスは Rust の役割であり、他言語の採用を持たない。

## extension が接続する core への JSON-RPC

用途は、extension が接続する core のプロセスとの間で、JSON-RPC の小さい契約だけを外へ出す機構である。
採用は、C# は StreamJsonRpc、TypeScript は vscode-jsonrpc である。Rust は project が JSON-RPC の framing の機構を単一の採用として ADR に明記する。
判断基準は、protocol と transport を担い、自前で書くのを振る舞いだけにできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
