# Tauri

用途は、被ホストの viewer を利用者の端末で動かす native の shell である。
採用は、core の言語によらない desktop と mobile の host として Tauri を使い、webview の runtime は wry の runtime crate を選ぶ。
判断基準は、[desktop](../../structure/runtimes/desktop/layout.md) が定める対象の OS すべてと mobile で内蔵 webview に同じ viewer を載せ、core の直接組込・別言語のバックエンドの同梱・remote への接続を公開契約で使い分けられ、対象 OS で host と runtime と使用する plugin が成立する一組へ固定できることである。
撤回条件は、判断基準を満たさなくなることであり、webview と OS の対応状況の変化、保守の停止、採用する系の安定版の到達を再評価のトリガーとする。

## desktop と mobile の host

### 要求
desktop と mobile を持つ project は、core の言語によらず host に Tauri を使う。
UI は viewer に閉じ、native の widget を別に作らない。
core の接続と組立は [desktop](../../structure/runtimes/desktop/layout.md) と [mobile](../../structure/runtimes/mobile/layout.md) に従う。
remote の core だけを利用する host は生成した通信 client で接続し、ローカルの core を同梱しない。
webview の runtime は、host の組立点で一つだけ選ぶ。
core の公開 API を直接呼ぶ経路では、host の認証 adapter が保持する資格情報を IPC の認証境界で検証して認証主体を確定する。
IPC の command は認証主体と資格情報を frontend から受け取らない。
core の公開 API を直接呼ぶ経路で業務操作を呼ぶ場合は、host が確定した認証主体と検証済み入力を [structure/contracts/adapters](../../structure/contracts/adapters.md) の宣言された保護を適用する入口へ渡す。
別プロセスまたは native library へ接続する経路では、受信側の認証境界で資格情報を検証し、その側の契約 adapter の保護された入口へ接続する。
core の公開 API が受け取るのは、検証済み入力と、主体を必要とする operation の認証主体から対応づけた業務入力だけにする。
認証の資格情報は frontend 外の認証 adapter に置き、業務の secret と判断は core に置いて frontend に出さない。
IPC の公開契約と生成物は [structure/contracts/protocol](../../structure/contracts/protocol.md) と [generated](../../structure/contracts/generated.md) に従い、両端で同じ正本から生成した入出力の型と codec を使う。
host が所有する技術操作は host の公開 Interface へ接続し、core の operation を経由させない。

### 根拠
Tauri の host プロセスは webview との IPC を受け、webview は viewer を動かす。
core の言語と shell の選定を分ければ、業務の実装を移植せず同じ desktop と mobile の機構を使える。
core の直接組込と別言語のバックエンドへの接続を分け、実際に core を呼ぶ側で入口を保護すれば、shell に業務判断や認可を複製せずに済む。
認証の資格情報を frontend 外の認証 adapter に置き、業務の secret と判断を core に置けば、frontend へ秘密が出ない。

### 完了条件
desktop と mobile の host が、core の言語によらず Tauri である。
UI が viewer に閉じ、native の widget が別に作られていない。
webview の runtime が、host の組立点で一つだけ選ばれ、その単一性が Cargo 依存の検査で確かめられている。
同じ viewer と core を使う各 host が、既存の成果物と公開契約を共有している。
remote の core だけを利用する host が、ローカルの core を同梱していない。
core の公開 API を直接呼ぶ経路の IPC の認証境界が、host の認証 adapter の資格情報を検証して認証主体を確定している。
IPC の command の引数に認証主体と資格情報の型が現れないことが、構造検査で確かめられている。
core の実際の呼出側での資格情報から認証主体への確定と、adapter の入口が認証主体から対応づけた業務入力と検証済み入力による core の公開 API の呼出が、実行テストで確かめられている。
core の公開 API が、認証主体と資格情報を受け取らず、必要な業務入力と検証済み入力だけを受け取っている。
認証の資格情報が frontend 外の認証 adapter に、業務の secret と判断が core に置かれ、frontend に出ていない。
IPC の実際の受信経路で、契約どおりの結果と状態変化、契約違反の拒否と状態不変、技術入口による業務操作の保護の迂回の拒否が確かめられている。

### 禁止事項
secret や業務の判断を、frontend に置くこと。
認証主体または資格情報を、frontend から IPC の command へ渡すこと。
資格情報と認証主体を、core の公開 API へ渡すこと。
native の widget を、viewer と別に作ること。
別プロセスまたは native library の core にある業務判断や契約 adapter の写像を、shell に複製すること。

### 行動
host を Tauri にし、IPC の command を契約から生成した入出力で型付け、codec を実際の受信経路に適用する。
host の組立点で webview の runtime を一つ選び、その runtime crate を依存に置く。
core の公開 API を直接呼ぶ経路では、IPC の入口で host の認証 adapter の資格情報を検証し、認証主体を確定する。
core の公開 API を直接呼ぶ経路で業務操作を呼ぶ command は、確定した認証主体と検証済み入力を adapter の宣言された保護を適用する入口へ渡し、その入口が対応づけた業務入力と検証済み入力だけを core の公開 API へ渡す。
別プロセスまたは native library へ接続する command は生成した client・stub と codec を使い、受信側の認証と保護された入口を通す。
認証の資格情報を frontend 外の認証 adapter に、業務の secret と判断を core に置く。

### 例
Rust の core をプロセス内に組み込む経路では、資格情報を host 側で検証して認証主体を確定し、frontend の入力と認証主体を adapter の入口へ渡す。

```rust
#[tauri::command]
fn place_order(state: State<AppState>, request: OrderRequest) -> Result<OrderId, AppError> {
    let subject = state.authentication.verify()?;
    state.place_order.invoke(&subject, request)
}
```

## desktop の外部バックエンド

### 要求
C# の core をローカルで使う desktop は、core を組み込んだ [embedded surface](../../structure/surfaces/embedded/layout.md) の成果物を Tauri の sidecar として同梱起動する。
sidecar の実行ファイルを `bundle.externalBin` に登録し、配布対象の OS と CPU に対応する target triple をファイル名へ付ける。
実行に必要な runtime と補助ファイルも配布成果物へ含め、利用者の開発環境に依存させない。
sidecar の起動と入出力は Rust の `tauri_plugin_shell::ShellExt` から扱い、frontend に任意のプロセスを起動する権限を与えない。
host と sidecar の通信は [structure/contracts/protocol](../../structure/contracts/protocol.md) に従い、両端で同じ正本から生成したデータ型と codec を使う。
sidecar の認証境界と契約 adapter の保護は [embedded surface](../../structure/surfaces/embedded/layout.md) に従い、host が送る認証主体の値だけを信頼しない。
sidecar の準備確認・停止・異常終了後の回収と、shell と一組の配布・更新は [desktop](../../structure/runtimes/desktop/layout.md) に従う。

### 根拠
Tauri の [sidecar](https://v2.tauri.app/develop/sidecar/) は外部の実行ファイルを同梱起動でき、C# は [.NET の publish](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview) で対象の OS と CPU 向けの実行ファイルを作れる。
core と契約 adapter をバックエンドに残せば、shell の言語に合わせた業務の移植を要しない。
生成した通信経路と受信側の保護された入口を使えば、同梱によって契約や認可の検査を迂回しない。

### 完了条件
C# のローカル core が embedded surface に組み込まれ、Tauri の配布成果物に含まれている。
対象の OS と CPU ごとの実行ファイルと依存物が同梱され、開発環境のない端末で起動できることが確かめられている。
host と sidecar の実受信経路で、契約どおりの結果と状態変化、契約違反と偽造した認証主体の拒否、拒否後の業務状態不変が確かめられている。
sidecar の起動失敗・準備前・通信断・host の正常終了と異常終了で、要求の受付、失敗の通知、子プロセスの回収が desktop の規律どおりであることが確かめられている。
要求の期限・取消・相関が sidecar へ伝わり、取消要求と処理の完了を区別できることが確かめられている。
frontend に任意のプロセス起動の権限がなく、shell に業務判断と契約 adapter の写像が複製されていない。

### 禁止事項
desktop の追加のために、C# の core を Rust へ移植すること。
sidecar の保護された入口を迂回して、業務操作を実行すること。
sidecar の runtime や補助ファイルを、開発端末にだけ存在するものへ依存させること。
sidecar の起動成功を、要求を処理できる準備完了とみなすこと。

### 行動
C# の core と契約 adapter を embedded surface の組立点で組み立て、対象の OS と CPU ごとの成果物を作る。
成果物を `bundle.externalBin` と必要な同梱資源へ登録し、Rust 側から起動して準備を確認する。
生成した通信 client と提供側 stub を接続し、実受信経路の成功・拒否と lifecycle の失敗経路を検証する。
shell と sidecar を一組で配布・更新し、更新後の成果物から準備確認と業務操作まで通す。

## mobile の native バックエンド

### 要求
C# の core をローカルで使う mobile は、[C# の publication](../csharp/publication.md) の「mobile の native 組込入口」に従う embedded surface の共有ライブラリを同梱し、Rust の host から C ABI で接続する。
Rust の core をローカルで使う mobile は、host が core と契約 adapter を直接組み立てる。
native library の接続は runtime の adapter に閉じ、[connection](./connection.md) の「FFI を安全な境界に閉じる」に従う safe な wrapper を使う。
同梱する library だけを link し、frontend が library の path や native の symbol を指定する入口を作らない。
host の組立点で library を初期化し、準備を確認してから生成した stub と codec を通して要求を渡す。
Rust の panic を ABI の外へ unwind させず、native 境界の失敗を想定内失敗・欠陥・取消に分けて呼出側へ返す。
mobile で desktop の sidecar 起動や updater を使わず、配布・更新と中断・終了の扱いは [mobile](../../structure/runtimes/mobile/layout.md) に従う。

### 根拠
[Tauri 2](https://v2.tauri.app/blog/tauri-20/) は同じ web frontend を Android と iOS でもホストするが、[shell plugin](https://v2.tauri.app/plugin/shell/#supported-platforms) の mobile 対応は URL を開く機能だけである。
[.NET の native library](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/libraries) と [Rust の C ABI](https://doc.rust-lang.org/nomicon/ffi.html) を接続すれば、別プロセスを起動せず C# の core を利用できる。
契約の受信口と業務の組立を C# 側に残せば、Rust 側は同梱・接続・寿命の管理に閉じられる。

### 完了条件
C# のローカル core が同梱する共有ライブラリにあり、Rust のローカル core は host が直接組み立てている。
native library の実際の呼出が safe な wrapper と生成した契約を通り、frontend に library の選択や任意 symbol の呼出権限がない。
対象端末で、準備前と初期化失敗時の拒否、業務操作の結果と状態、契約違反と偽造主体の拒否、期限・取消・完了と正常停止時の資源解放が確かめられている。
ネットワークを切った配布成果物で offline の要件が満たされ、OS の中断と強制終了後に必要な状態へ回復できる。
Rust の panic と C# の管理例外が ABI を越えず、失敗・欠陥・取消の意味が生成した応答で保持されている。

### 禁止事項
mobile の C# バックエンドを、desktop 用の sidecar として起動すること。
native library の組込を理由に、認証、契約の検証、契約 adapter の保護を省くこと。
共有ライブラリの組込が未成立のまま、offline の要件を満たしたとすること。

### 行動
対象 OS と CPU に対応する共有ライブラリと依存物を mobile の成果物へ組み込み、生成した C ABI と codec を Rust の adapter へ接続する。
組立点で初期化と準備を確認し、mobile の配布成果物から起動・操作・取消・中断と再起動の受入を実行する。

## desktop の自動更新

### 要求
自動更新を使う desktop に、core の言語によらずこの節を適用する。
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
設定した公開鍵を与えた updater が、正しい signature の bundle を受理し、signature の欠落と改竄した bundle を拒否することが、実行テストで確かめられている。
更新の endpoint が、TLS である。
非 HTTPS の endpoint を許す設定が、置かれていない。
release 成果物の署名と provenance だけが、Cosign の定める検証を満たしている。
sidecar を同梱する場合、更新後も shell とバックエンドが一組で切り替わり、配布成果物からの起動・準備確認・業務操作が成立することが確かめられている。

### 禁止事項
署名を生成せず、または Tauri updater の signature 検証を伴わない経路で、更新を配布すること。
非 HTTPS の endpoint を許す設定を、置くこと。
updater signature の秘密鍵を、成果物や設定へ同梱すること。
Cosign の release 成果物の署名または provenance を、updater bundle の signature の代わりに使うこと。
同梱するバックエンドへ、shell とは独立した自動更新の機構を置くこと。

### 行動
updater plugin を導入し、Tauri CLI で生成した公開鍵を設定に置く。
`TAURI_SIGNING_PRIVATE_KEY` を build 環境へ供給し、`bundle.createUpdaterArtifacts` を有効にして updater bundle と signature を生成する。
updater bundle と signature を同じ TLS endpoint から配る。
endpoint を TLS に限り、非 HTTPS を許す設定を置かない。
release 成果物の署名と provenance だけを Cosign の採用に従って生成し、検証する。

