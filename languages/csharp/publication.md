# publication

## 概要
publication は、C# で外部公開面と host を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界と依存の向きと、concerns の [authorization](../../concerns/authorization/README.md) が定める入口での評価・[security](../../concerns/security/README.md) が定める攻撃面の最小化・[authentication](../../concerns/authentication/README.md) が定める資格情報の検証と actor の構築を、C# の機構で満たす。
surface ごとの規律は、[aspnet-core](./aspnet-core.md)・[consoleappframework](./consoleappframework.md)・[wolverine](./wolverine.md)・[photino](./photino.md)・[maui-hybridwebview](./maui-hybridwebview.md)・[streamjsonrpc](./streamjsonrpc.md) が持つ。

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

### 禁止事項
内部の実装を、public で公開すること。

### 行動
公開する API だけを public にし、内部を internal、1ファイルに閉じる型を file 修飾子で閉じる。

### 例
アセンブリ内だけで使う型は `internal`、1ファイルに閉じる型は `file` にする。

```csharp
internal sealed class OrderStore { }
file sealed class JsonHelper { }
```

## 参照
境界と依存の向きは [separation](../../principles/separation/README.md)、入口での評価は [authorization](../../concerns/authorization/README.md)、攻撃面の最小化は [security](../../concerns/security/README.md)、資格情報の検証と actor の構築は [authentication](../../concerns/authentication/README.md) に従う。
配置は [structure/surfaces](../../structure/surfaces/)・[structure/runtimes](../../structure/runtimes/)・[structure/skeleton](../../structure/skeleton.md) に従う。
コンテキストの境界は [structure/core](../../structure/core/layout.md) に従う。
