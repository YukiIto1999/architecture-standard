# publication

## 概要
publication は、Rust で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization/README.md) が定める入口での評価・[security](../../concerns/security/README.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication/README.md) が定める資格情報の検証と actor の構築を、Rust の機構で満たす。
surface ごとの規律は、[axum](./axum.md)・[tower-sessions](./tower-sessions.md)・[clap](./clap.md)・[apalis](./apalis.md)・[tauri](./tauri.md)・[tower-lsp-server](./tower-lsp-server.md) が持つ。

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
内部の実装まで `pub` にすると、crate の外から直接触れられる。

```rust
pub struct Connection { pub raw_handle: RawHandle }
```

外向き API だけを `pub` にし、内部は `pub(crate)` 以下に保つ。

```rust
pub struct Connection { pub(crate) raw_handle: RawHandle }
pub fn open() -> Connection { open_internal() }
```

## 参照
境界と依存の向きは [separation](../../principles/separation/README.md)、入口での評価は [authorization](../../concerns/authorization/README.md)、攻撃面の最小化は [security](../../concerns/security/README.md)、資格情報の検証と actor の構築は [authentication](../../concerns/authentication/README.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
