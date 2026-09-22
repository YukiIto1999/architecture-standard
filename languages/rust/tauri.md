# Tauri

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が Rust のときは desktop・mobile ともに Tauri であり、webview の runtime は wry の runtime crate を選ぶ。
判断基準は、[desktop](../../structure/runtimes/desktop/layout.md) が定める対象の OS すべてと mobile で内蔵 webview に同じ viewer を載せ、core を host の back-end に置け、host と runtime と updater plugin の版を同時に成立する一組へ固定できることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化、保守の停止、採用する系の安定版の到達を再評価のトリガーとする。

## desktop と mobile の host

### 要求
Rust の core を持つ desktop と mobile の host は Tauri とし、同じ viewer と同じ core を desktop と mobile の shell で共有する。
webview の runtime は、host の組立点で一つだけ選ぶ。
desktop と mobile の各 shell は、host の認証 adapter が保持する資格情報を IPC の認証境界で検証して actor を構築する。
IPC の command は actor と資格情報を frontend から受け取らず、認証境界が構築した actor と検証済み入力だけを core へ渡す。
認証の資格情報は host の認証 adapter に置き、業務の secret と判断は core に置いて frontend に出さない。

### 根拠
Tauri は core のプロセスが唯一の入口として IPC を一元に統べ、webview は viewer を動かす。
host が保持する資格情報から IPC の認証境界で actor を構築すれば、frontend が actor を指定できず、core は認証方式を知らずに済む。
認証の資格情報を host の認証 adapter に置き、業務の secret と判断を core に置けば、frontend へ秘密が出ない。
同じ viewer と core を両方の shell で共有すれば、面の重複が避けられる。

### 完了条件
desktop と mobile の host が、Tauri である。
webview の runtime が、host の組立点で一つだけ選ばれ、その単一性が Cargo 依存の検査で確かめられている。
同じ viewer と core が、両方の shell で共有されている。
desktop と mobile の各 IPC の認証境界が、host の認証 adapter の資格情報を検証して actor を構築している。
IPC の command の引数に actor と資格情報の型が現れないことが、構造検査で確かめられている。
資格情報から actor への写像と、actor と検証済み入力による core の公開 API の呼出が、実行テストで確かめられている。
core の公開 API が、actor と検証済み入力だけを受け取っている。
認証の資格情報が host の認証 adapter に、業務の secret と判断が core に置かれ、frontend に出ていない。

### 禁止事項
secret や業務の判断を、frontend に置くこと。
actor または資格情報を、frontend から IPC の command へ渡すこと。
資格情報を、core の公開 API へ渡すこと。

### 行動
host を Tauri にし、IPC を型付きの command で一元化する。
host の組立点で webview の runtime を一つ選び、その runtime crate を依存に置く。
desktop と mobile の各 IPC の入口で host の認証 adapter の資格情報を検証し、actor を構築する。
actor と検証済み入力だけを core の公開 API へ渡す。
認証の資格情報を host の認証 adapter に、業務の secret と判断を core に置く。
### 例
資格情報は host 側で actor へ写し、frontend の入力と actor だけを core へ渡す。

```rust
#[tauri::command]
fn place_order(state: State<AppState>, request: OrderRequest) -> Result<OrderId, AppError> {
    let actor = state.authentication.verify_and_map()?;
    state.core.place_order(actor, request.try_into()?)
}
```

## desktop の自動更新

### 要求
desktop の自動更新は Tauri の updater plugin で行い、Tauri CLI で生成した公開鍵を設定に置いて updater bundle の signature を検証する。
Tauri CLI で生成した秘密鍵を `TAURI_SIGNING_PRIVATE_KEY` から読み、`bundle.createUpdaterArtifacts` を有効にして updater bundle と signature を生成する。
生成した updater bundle と signature を、TLS の endpoint から配布する。
updater signature の秘密鍵は [concerns/secrets](../../concerns/secrets/README.md) に従って扱う。
release 成果物そのものの署名と provenance だけを [tools/build/cosign](../../tools/build/cosign.md) に従って扱う。

### 根拠
updater plugin は Tauri CLI の鍵で生成した signature を検証し、署名検証を無効化できない。
`bundle.createUpdaterArtifacts` は updater bundle と signature の生成を有効にし、`TAURI_SIGNING_PRIVATE_KEY` は build 時の秘密鍵を供給する。
updater bundle の signature と release 成果物の署名・provenance を別の検証物として既存の正本へ委ねれば、Cosign の責務を updater signature へ誤って広げない。

### 完了条件
desktop の自動更新が、Tauri の updater plugin で行われている。
更新成果物の検証に使う公開鍵が、設定に置かれている。
`bundle.createUpdaterArtifacts` が有効で、`TAURI_SIGNING_PRIVATE_KEY` を使う build が updater bundle と signature を生成している。
updater bundle と signature が、TLS の endpoint から配布され、設定した公開鍵で signature が updater bundle を検証できる。
更新の endpoint が、TLS である。
非 HTTPS の endpoint を許す設定が、置かれていない。
release 成果物の署名と provenance だけが、Cosign の定める検証を満たしている。

### 禁止事項
署名を生成せず、または Tauri updater の signature 検証を伴わない経路で、更新を配布すること。
非 HTTPS の endpoint を許す設定を、置くこと。
updater signature の秘密鍵を、成果物や設定へ同梱すること。
Cosign の release 成果物の署名または provenance を、updater bundle の signature の代わりに使うこと。

### 行動
updater plugin を導入し、Tauri CLI で生成した公開鍵を設定に置く。
`TAURI_SIGNING_PRIVATE_KEY` を build 環境へ供給し、`bundle.createUpdaterArtifacts` を有効にして updater bundle と signature を生成する。
updater bundle と signature を同じ TLS endpoint から配る。
endpoint を TLS に限り、非 HTTPS を許す設定を置かない。
release 成果物の署名と provenance だけを Cosign の採用に従って生成し、検証する。

