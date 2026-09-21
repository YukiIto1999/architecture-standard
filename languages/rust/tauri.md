# Tauri

用途は、被ホストの viewer と core を利用者の端末で動かす host である。
採用は、core が Rust のときは desktop・mobile ともに Tauri である。
判断基準は、OS 内蔵の webview に同じ viewer を載せ、core を host の back-end に置けることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化を再評価のトリガーとする。

## desktop と mobile の host

### 要求
Rust の core を持つ desktop と mobile の host は Tauri とし、同じ viewer と同じ core を desktop と mobile の shell で共有する。
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
同じ viewer と core が、両方の shell で共有されている。
desktop と mobile の各 IPC の認証境界が、host の認証 adapter の資格情報を検証して actor を構築している。
core の公開 API が、actor と検証済み入力だけを受け取っている。
認証の資格情報が host の認証 adapter に、業務の secret と判断が core に置かれ、frontend に出ていない。

### 禁止事項
secret や業務の判断を、frontend に置くこと。
actor または資格情報を、frontend から IPC の command へ渡すこと。
資格情報を、core の公開 API へ渡すこと。

### 行動
host を Tauri にし、IPC を型付きの command で一元化する。
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
