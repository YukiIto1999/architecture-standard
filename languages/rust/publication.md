# publication

## 概要
publication は、Rust で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization.md) が定める入口での評価・[security](../../concerns/security.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication.md) が定める本人性の確立と資格情報の非流出を、Rust の機構で満たす。

## server

### 要求
server は axum で組み、依存は State で handler へ渡す。
router はコンテキストごとに分けて合成し、境界の仕込みは tower の middleware で一括して積む。
認証は route の一致時にだけ走る層に置く。

### 根拠
依存を State で handler へ渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
router をコンテキストごとに分けて合成すれば、面が変更理由ごとに分かれる。
境界の仕込みを tower の middleware で一括して積めば、横断の関心が入口に集まる。
認証を route の一致時にだけ走る層に置けば、未一致の要求が 404 のまま留まり、認証で 404 が 401 に化けて対象の存在を露出しない。

### 完了条件
server が axum で組まれ、依存が State で handler へ渡されている。
router が、コンテキストごとに合成されている。
境界の仕込みが middleware で一括して積まれ、認証が route の一致時にだけ走る層に置かれている。

### 禁止事項
認証を、route の一致に関わらず走る層に置き、404 を 401 に化けさせること。
依存を、handler の中で直接生成すること。

### 行動
依存を State で渡し、router をコンテキストごとに nest・merge で合成する。
境界の仕込みを ServiceBuilder で積み、認証は route の一致時にだけ走る層に置く。

### 例
```rust
// 認証を全体の層に置くと、未一致の要求の 404 が 401 に化ける
let app = Router::new().route("/", get(handler)).layer(middleware::from_fn(auth));

// 依存は State、router はコンテキストごと、認証は route の一致時だけ
#[derive(Clone)] struct AppState { /* pool, policy port */ }
let app = Router::new()
    .nest("/api", api_router())
    .route_layer(middleware::from_fn(auth))          // 一致時だけ。404 を保つ
    .layer(ServiceBuilder::new().layer(TraceLayer::new_for_http()))
    .with_state(state);
```

## BFF

### 要求
session は tower-sessions で扱い、store は fred で Valkey に保持する。
OIDC は openidconnect を使う。
CSRF の検査は [concerns/authentication](../../concerns/authentication.md) に従う。
access token と refresh token は server 側の session に保持し、ブラウザへは session を指す cookie だけを渡す。
token の更新は、単一の更新に制御し、競合による上書きを防ぐ。
resource への要求は server が中継し、内部の JWT を付与してから転送する。中継の機構は project が単一の採用を ADR に明記する。

### 根拠
BFF が token を server 側で保持し、ブラウザへ session を指す cookie だけを渡せば、token がブラウザに出ず、持ち出しの面が消える。
tower-sessions の cookie は既定で Secure・HttpOnly・SameSite=Strict なので、漏れにくい既定で守れる。
session の store を fred で Valkey に保持すれば、複数のプロセスの間で session の状態が一致し、[authentication](../../concerns/authentication.md) が定めるプロセス外の共有ストアへの保持を満たす。
OIDC の ID Token を nonce と at_hash で検証すれば、token のすり替えを防げる。
token の更新を単一の更新に制御すれば、競合した更新が互いを上書きせず、有効な token を失わない。
server が中継して内部の JWT を付与すれば、resource が外部の opaque token を直接受け取らず、ブラウザも中継先の token を知らない。

### 完了条件
session が tower-sessions で扱われ、fred で Valkey に保持されている。
OIDC が openidconnect で、ID Token が nonce と at_hash で検証されている。
access token・refresh token が server 側の session に保持され、ブラウザへ token が出ていない。
token の更新が、単一の更新に制御されている。
resource への要求が、server の中継を経て内部の JWT を付与されてから転送されている。
CSRF の検査が、[concerns/authentication](../../concerns/authentication.md) の方式で行われている。

### 禁止事項
access token・refresh token を、ブラウザへ渡すこと。
cookie の Secure・HttpOnly・SameSite を、緩めること。
token の更新を、競合の制御なく並行に許すこと。

### 行動
OIDC を code と PKCE で server で終端し、ID Token を nonce と at_hash で検証する。
token を server 側の session に保持し、ブラウザへは session を指す cookie だけを渡す。
session の store を fred backed の実装に差し、Valkey に保持する。
token の更新経路に、単一の更新に絞る制御を入れる。
resource への要求を server で中継し、内部の JWT を付与してから転送する。中継の機構は project の ADR に明記する。
CSRF の検査は [concerns/authentication](../../concerns/authentication.md) に従って実装する。

### 例
```rust
// access token をブラウザへ渡す。持ち出しの面が開く
Json(TokenResponse { access_token, refresh_token })

// token は session に保持、ブラウザへは安全な既定の session cookie だけ
let session_layer = SessionManagerLayer::new(store); // Secure・HttpOnly・SameSite=Strict は既定
let claims = id_token.claims(&client.id_token_verifier(), &nonce)?;  // nonce を検証
verify_at_hash(claims.access_token_hash(), &access_token)?;          // at_hash で token のすり替えを防ぐ
session.insert("actor", to_actor(claims)).await?;                    // principal を actor へ写す
```

## console

### 要求
console は clap で組み、引数を型で宣言して境界で一度 parse する。

### 根拠
引数を型で宣言し境界で一度 parse すれば、引数が型に現れ、未検証の値が内側に入らない。
文字列のキーで引数を取り出すと、型に現れず手で復元することになる。

### 完了条件
console が clap で組まれている。
引数が型で宣言され、境界で一度 parse されている。

### 禁止事項
引数を、文字列のキーで取り出すこと。

### 行動
引数を struct・enum と derive で宣言し、入口で一度 parse する。

### 例
```rust
// 文字列のキーで取り出す。型に現れず手で復元する
let matches = Command::new("app").arg(Arg::new("verbose")).get_matches();

// derive で型宣言し、parse 一発で構造化する
#[derive(Parser)] struct Cli { #[arg(short, long)] verbose: bool, #[command(subcommand)] command: Commands }
let cli = Cli::parse();
```

## worker

### 要求
worker は apalis を、PostgreSQL を backend にした queue と scheduler に限って使う。
broker・durable workflow・外部の message bus としての利用は標準外とする。
handler の依存は `Data` extractor で受け取り、handler の中で直接生成しない。

### 根拠
queue を PostgreSQL に閉じれば、外部の broker や message bus を開かず、攻撃面が増えない。
apalis の cron 機構を scheduler に使えば、定期実行も同じ PostgreSQL backend の queue に閉じる。
job の処理を queue から受ける形にすれば、副作用が処理の中に集まる。
`Data` extractor で依存を渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
broker・durable workflow・外部の message bus は別の関心で、ここで担うと面が広がる。

### 完了条件
worker が、apalis を PostgreSQL を backend にした queue と scheduler に限って使っている。
broker・durable workflow・外部の message bus として、使われていない。
handler の依存が、`Data` extractor で受け取られ、handler の中で直接生成されていない。

### 禁止事項
worker を、broker・durable workflow・外部の message bus として使うこと。
handler の中で、依存を直接生成すること。

### 行動
queue を PostgreSQL の backend に限り、apalis で enqueue と worker を組む。
定期実行は apalis の cron 機構で scheduler として組む。
worker の起動は WorkerBuilder で組み、apalis の Monitor で走らせる。
handler の依存は `Data` extractor で渡す。

### 例
```rust
// queue を PostgreSQL の backend に閉じる。外部 broker を開かない
PostgresStorage::setup(&pool).await?;          // schema の用意。setup は pool の参照を取る静的関数
let mut storage = PostgresStorage::new(&pool); // push は &mut self を要する
storage.push(SendEmail { to }).await?;         // enqueue
// worker の起動は WorkerBuilder で組み、apalis の Monitor で走らせる(具体の呼び出し形は版で変わるため、ここでは固定しない)
```

## desktop と mobile の host

### 要求
Rust の core を持つ desktop と mobile の host は Tauri とし、同じ viewer と同じ core を desktop と mobile の shell で共有する。
secret と業務の判断は core に置き、frontend に出さない。

### 根拠
Tauri は core のプロセスが唯一の入口として IPC を一元に統べ、webview は viewer を動かす。
secret と業務の判断を core に置けば、frontend の攻撃面が小さくなる。
同じ viewer と core を両方の shell で共有すれば、面の重複が避けられる。

### 完了条件
desktop と mobile の host が、Tauri である。
同じ viewer と core が、両方の shell で共有されている。
secret と業務の判断が core に置かれ、frontend に出ていない。

### 禁止事項
secret や業務の判断を、frontend に置くこと。

### 行動
host を Tauri にし、IPC を型付きの command で一元化する。
secret と業務の判断を core に置く。

### 例
```rust
// 検証・認可・業務の判断は core 側。secret は frontend に出さない
#[tauri::command]
fn place_order(state: State<AppState>, request: OrderRequest) -> Result<OrderId, AppError> { /* ... */ }
```

## extension の接続

### 要求
extension が接続する core のプロセスは、外へ出すのを小さい契約だけにして公開する。これを JSON-RPC で満たし、直列化は serde を使う。
JSON-RPC の framing の機構は、project が単一の採用を ADR に明記する。
言語機能を提供する場合に限り tower-lsp-server で LSP を公開する。
フル LSP を自作しない。

### 根拠
serde は値の直列化と逆直列化を担うだけで、JSON-RPC のメッセージの区切りや相関を扱う framing までは担わない。
framing の機構を project の ADR に固定すれば、実装ごとに框組みが割れない。
core を JSON-RPC の小さい契約で公開すれば、外へ出すのは契約だけになる。
tower-lsp-server は protocol と transport を担うので、自前で書くのは振る舞いだけになる。
フル LSP を自作すると、framing の手書きが関心を境界の外へ漏らす。

### 完了条件
core のプロセスが JSON-RPC で公開され、直列化に serde が使われている。
JSON-RPC の framing の機構が、project の ADR に明記されている。
言語機能の提供が、tower-lsp-server で行われている。
フル LSP を、自作していない。

### 禁止事項
LSP の framing や protocol を、自作すること。
JSON-RPC の framing の機構を、project の ADR に明記せず場当たりに選ぶこと。

### 行動
core を JSON-RPC で公開し、直列化を serde で行う。
framing の機構は project の ADR に選定と単一採用を明記する。
言語機能は tower-lsp-server で LanguageServer を実装する。

### 例
```rust
// 振る舞いだけを実装し、transport と protocol は委譲する
impl LanguageServer for Backend {
    async fn initialize(&self, _: InitializeParams) -> Result<InitializeResult> { Ok(Default::default()) }
    async fn shutdown(&self) -> Result<()> { Ok(()) }
}
let (service, socket) = LspService::new(|client| Backend { client });
Server::new(stdin(), stdout(), socket).serve(service).await;
```

## 可視性

### 要求
公開面は crate の境界で閉じ、crate の外へ出すもの以外は pub(crate) 以下に保つ。
skeleton の境界の分割と依存方向の検証は、inspection の構造検査に従う。

### 根拠
crate の境界で公開面を閉じ、外へ出すもの以外を pub(crate) 以下に保てば、内部の実装が外から触れない。
skeleton の境界を workspace の crate に分けて依存方向を Cargo の依存で強制する検証は inspection が正本として持ち、publication では重ねて定めない。

### 完了条件
公開面が、crate の境界で閉じている。
crate の外へ出すもの以外が、pub(crate) 以下である。

### 禁止事項
内部の実装を、crate の外から触れる形で公開すること。

### 行動
外向きの API だけを pub にし、内部を pub(crate) 以下に保つ。

### 例
```rust
// 内部の実装まで全部 pub。crate の外から触れる
pub struct Connection { pub raw_handle: RawHandle }

// 外向き API だけ pub、内部は pub(crate)
pub struct Connection { pub(crate) raw_handle: RawHandle }
pub fn open() -> Connection { open_internal() }
```

## 参照
境界と依存の向きは [separation](../../principles/separation.md)、入口での評価は [authorization](../../concerns/authorization.md)、攻撃面の最小化は [security](../../concerns/security.md)、本人性の確立と資格情報の非流出は [authentication](../../concerns/authentication.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
認証チケットの永続化は [retention](./retention.md) に従う。
