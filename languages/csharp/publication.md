# publication

## 概要
publication は、C# で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization/README.md) が定める認可の宣言と公開入口での強制・[security](../../concerns/security/README.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication/README.md) が定める資格情報の検証と認証主体の確定を、C# の機構で満たす。
surface ごとの規律は、[aspnet-core](./aspnet-core.md)・[consoleappframework](./consoleappframework.md)・[wolverine](./wolverine.md)・[streamjsonrpc](./streamjsonrpc.md) が持つ。
desktop と mobile の shell と同梱するバックエンドの接続機構は [tauri](../rust/tauri.md) が定める。
同梱する C# のバックエンドの配置と公開入口は [structure/surfaces/embedded](../../structure/surfaces/embedded/layout.md) に従う。

## 可視性

### 要求
コンテキストは assembly の境界と一致させ、内部の実装は internal に保ち、1ファイルに閉じる型は file 修飾子で閉じる。
`InternalsVisibleTo` は、そのコンテキストの tests の assembly に限り、コンテキスト間の可視の穴にしない。

### 根拠
通る最も狭い可視性を既定にすれば、public が意図した API の表面に限られ、内部の実装が外から触れない。
1ファイルに閉じる型を file 修飾子で閉じれば、生成物の名前の衝突を避けつつ表面を広げない。

### 完了条件
内部の実装が、internal に保たれている。
1ファイルに閉じる型が、file 修飾子で閉じられている。
`InternalsVisibleTo` の宛先が、同じコンテキストの tests の assembly に限られている。

### 禁止事項
内部の実装を、public で公開すること。
`InternalsVisibleTo` を、別のコンテキストの assembly へ向けること。

### 行動
公開する API だけを public にし、内部を internal、1ファイルに閉じる型を file 修飾子で閉じる。
`InternalsVisibleTo` の宛先を、同じコンテキストの tests の assembly だけに保つ。

### 例
アセンブリ内だけで使う型は `internal`、1ファイルに閉じる型は `file` にする。

```csharp
internal sealed class OrderStore { }
file sealed class JsonHelper { }
```

## mobile の native 組込入口

### 要求
mobile に同梱する C# の core は、契約 adapter とともに [embedded surface](../../structure/surfaces/embedded/layout.md) へ組み込み、Native AOT の共有ライブラリとして publish する。
`PublishAot` を有効にし、公開する assembly 自身に `UnmanagedCallersOnly` と空でない `EntryPoint` を持つ export を置く。
export は、[protocol](../../structure/contracts/protocol.md) の binding から生成した C ABI に従い、blittable な型で buffer の pointer と長さ、要求の識別子と完了通知を受け渡す。
管理された object、業務の DTO、Task、CancellationToken を ABI へ直接出さない。
受信した payload は生成した codec で decode し、認証と契約 adapter の保護された入口へ接続する。
非同期の業務操作を export で同期的に待たず、要求の識別子で完了と取消を対応付け、[coordination](./coordination.md) に従って期限と取消を内側へ渡す。
buffer と handle の生成・借用・所有権移譲・解放を ABI に定め、処理中の要求と callback が参照する資源を完了前に解放しない。
管理例外を ABI の外へ伝播させず、想定内失敗・欠陥・取消を区別した完了を返す。
共有ライブラリはプロセスの生存中に unload せず、論理的な停止と資源解放を library の unload と分ける。
対象の OS と CPU に対し、core・契約 adapter・生成 codec・依存物を含む Native AOT と trimming の互換性を検査し、警告を未解決のまま配布しない。
Android の Native AOT は experimental であることを実行条件に記録し、採用する SDK と対象端末での実行を配布の受入条件にする。
iOS の共有ライブラリは framework として同梱し、shell と一組で署名する。

### 根拠
[Native AOT の共有ライブラリ](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/libraries) は、別途の .NET runtime のインストールなしに他言語から呼べる。
[native export](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/interop) は公開する assembly の `UnmanagedCallersOnly` を入口にし、[Rust の FFI](https://doc.rust-lang.org/nomicon/ffi.html) は C ABI の共有ライブラリへ接続できる。
これにより C# の業務実装を移植せず、shell と独立した生成契約の入口を保てる。
[Native AOT の対応表](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/#platformarchitecture-restrictions) は Android を experimental とし、[iOS の組込手順](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/ios-like-platforms/creating-and-consuming-custom-frameworks) は framework の同梱と署名を求めるため、desktop 向けの publish 成功だけでは mobile への配布を証明しない。

### 完了条件
C# の core と契約 adapter が embedded surface の組立点に残り、Native AOT の共有ライブラリが対象の OS と CPU ごとの配布成果物に含まれている。
export と両端の stub が同じ ABI 定義に一致し、管理型と業務の DTO が native の署名へ露出していない。
配布成果物の実受信経路で、正常入力の結果と状態変化、不正な payload と偽造した認証主体の拒否、拒否後の業務状態不変を確かめている。
空の payload、pointer と長さの不整合、並行要求、期限・取消と完了の競合を検査し、要求ごとの完了と資源の解放が一度だけ行われている。
初期化失敗・準備前・停止開始後の要求を拒否し、正常停止で要求と callback の完了前に資源が解放されていない。
想定内失敗・欠陥・取消の分類が ABI の両端で維持され、管理例外が native の呼出側へ伝播していない。
対象 SDK の AOT と trimming の警告が解消され、対象端末で [mobile](../../structure/runtimes/mobile/layout.md) の配布の受入が成立している。

### 禁止事項
mobile の追加のために C# の core を別言語へ移植し、または offline の要件を remote 接続へ置き換えること。
業務操作の途中で管理例外を native の呼出境界へ通すこと。
異なる allocator で buffer を解放し、または完了前の要求や callback が使う資源を解放すること。
共有ライブラリの load を準備完了と扱い、または中断からの復帰のために unload と reload を行うこと。
AOT の互換性や対象端末での未確認を、機能の非対応として黙認すること。

### 行動
embedded surface の export と host の stub を protocol の binding から生成し、C# の受信口で core と契約 adapter を組み立てる。
要求の受理、完了通知、取消、停止と資源解放を接続し、codec の検査を通った入力だけを保護された入口へ渡す。
対象の OS と CPU ごとに publish し、AOT の依存解析、最終成果物の同梱と署名、端末上の受入を一つの配布経路で確かめる。

## 参照
境界と依存の向きは [separation](../../principles/separation/README.md)、認可の宣言と公開入口での強制は [authorization](../../concerns/authorization/README.md)、攻撃面の最小化は [security](../../concerns/security/README.md)、資格情報の検証と認証主体の確定は [authentication](../../concerns/authentication/README.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
