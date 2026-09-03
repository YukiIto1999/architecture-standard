# axum

用途は、HTTP の API を公開する surface の骨格である。
採用は、Rust は axum である。
判断基準は、依存を組立点から handler へ注入でき、境界の仕込みを middleware で一括して積めることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止とリリースポリシーの変化を再評価のトリガーとする。

## server

### 要求
server は axum で組み、依存は State で handler へ渡す。
router はコンテキストごとに分けて合成し、境界の仕込みは tower の middleware で一括して積む。
認証は route の一致時にだけ走る層に置く。
server の認証境界は検証済み principal を actor へ写し、route から埋め込んだ core の公開 API へ actor だけを渡す。
principal、token、claim を core の公開 API または業務へ渡さない。
server の想定内の失敗は、RFC 9457 の problem+json へ `IntoResponse` の実装で写す。
server の未処理の panic は、`CatchPanicLayer` で捕捉して内部の詳細を含まない problem+json へ写す。
server の取り消しは、想定内の失敗の応答へ変換しない。
冪等な endpoint は、認証済み actor ID、匿名の安定した session または client の opaque scope、logical system actor ID を要求の種別に応じた actor scope として retention へ渡す。
multi-tenant operation は、認証済み claim または membership、authorization 済み選択、匿名の検証済み host または route と session/client context、system の logical actor 設定のいずれかから `TenantId` を構築する。
single-tenant operation は正準な single-tenant sentinel を、tenant の概念を持たない operation は正準な no-tenant sentinel を retention へ渡す。
安定した匿名 scope がない endpoint は、server 発行の全体で一意な key と proof だけを受け付ける。

### 根拠
依存を State で handler へ渡せば、依存がシグネチャに現れ、組立点だけが具象を知る。
router をコンテキストごとに分けて合成すれば、面が変更理由ごとに分かれる。
境界の仕込みを tower の middleware で一括して積めば、横断の関心が入口に集まる。
認証を route の一致時にだけ走る層に置けば、未一致の要求が 404 のまま留まり、認証で 404 が 401 に化けて対象の存在を露出しない。
`IntoResponse` に集約すれば、想定内の失敗の HTTP 表現が handler ごとに揺れない。
`CatchPanicLayer` で server の最上位を覆えば、欠陥を個々の handler で想定内の失敗に変えずに報告できる。

### 完了条件
server が axum で組まれ、依存が State で handler へ渡されている。
router が、コンテキストごとに合成されている。
境界の仕込みが middleware で一括して積まれ、認証が route の一致時にだけ走る層に置かれている。
検証済み principal が server の認証境界で actor へ写され、core の公開 API が actor だけを受け取っている。
想定内の失敗が、`IntoResponse` の実装で problem+json へ写されている。
未処理の panic が、`CatchPanicLayer` で内部の詳細を含まない problem+json へ写されている。
取り消しが、想定内の失敗の応答へ変換されていない。
冪等な endpoint が actor と tenant の全種別を retention の scope へ写し、未検証 tenant と `TenantId`・single-tenant sentinel・no-tenant sentinel の相互混同を拒否し、proof のない別 client へ保存済み response を返さないことが結合テストで検証されている。

### 禁止事項
認証を、route の一致に関わらず走る層に置き、404 を 401 に化けさせること。
principal、token、claim を core の公開 API または業務へ渡すこと。
依存を、handler の中で直接生成すること。
想定内の失敗の写像を、handler ごとに散らすこと。
未処理の panic の内部詳細を、problem+json に出すこと。
取り消しを、想定内の失敗の problem+json へ写すこと。
安定した scope のない匿名要求で client 指定 key を受け付けること。
発行時の proof を検証せずに保存済み response を返すこと。
未検証の tenant context を `TenantId` として retention へ渡すこと。

### 行動
依存を State で渡し、router をコンテキストごとに nest・merge で合成する。
境界の仕込みを ServiceBuilder で積み、認証は route の一致時にだけ走る層に置く。
検証済み principal を認証 middleware で actor へ写し、route から actor と検証済み入力だけを core の公開 API へ渡す。
想定内の失敗を `IntoResponse` の実装で problem+json へ写す。
`CatchPanicLayer` を ServiceBuilder に積み、未処理の panic を内部詳細のない problem+json へ写す。
actor と tenant の種別を retention の scope へ写し、安定した匿名 scope がなければ server 発行 key と proof を使う。
multi-tenant は認証済み、匿名、system の検証済み context から `TenantId` を構築する。
single-tenant は正準な single-tenant sentinel、tenant の概念外は正準な no-tenant sentinel を使う。
全 actor/tenant 種別の競合、未検証 tenant と三つの tenant scope 表現の相互混同、proof のない別 client への response 漏洩拒否を結合テストで確かめる。

### 例
認証 middleware を router 全体へ置くと、未一致の要求に返すべき 404 が 401 に変わる。

```rust
let app = Router::new().route("/", get(handler)).layer(middleware::from_fn(auth));
```

依存は `State` で渡し、router はコンテキストごとに分け、認証は route が一致した後だけ適用する。

```rust
#[derive(Clone)] struct AppState { /* ... */ }
impl IntoResponse for ApiError {
    fn into_response(self) -> Response { /* ... */ }
}
let app = Router::new()
    .nest("/api", api_router())
    .route_layer(middleware::from_fn(auth))
    .layer(ServiceBuilder::new()
        .layer(CatchPanicLayer::custom(problem_without_internal_detail))
        .layer(TraceLayer::new_for_http()))
    .with_state(state);
```
