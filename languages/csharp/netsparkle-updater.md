# NetSparkleUpdater

用途は、配布した desktop の成果物を、署名を検証しながら自動で更新する機構である。
採用は、C# は NetSparkleUpdater である。
判断基準は、PhotinoX と組み合わせて [desktop](../../structure/runtimes/desktop/layout.md) が定める対象の OS の成果物を採用している .NET の版から更新でき、Ed25519 の app cast と更新 package の署名を Strict で検証できることである。
撤回条件は、署名検証を必須にできなくなること、PhotinoX または採用している .NET の版の対象外となること、上流の保守停止、または同じ用途を満たす機構の出現であり、次の .NET の GA と上流の安定版到達を再評価のトリガーとする。

## desktop の自動更新

### 要求
C# の desktop は `NetSparkleUpdater.SparkleUpdater` の `Ed25519Checker(SecurityMode.Strict, ...)` を使い、app cast と更新 package の署名を検証してから更新する。
app cast の署名ファイルと更新 package の `sparkle:signature` を、更新を適用する前に必ず検証する。
更新 feed と更新 package は、project が管理する HTTPS の配布先から取得する。
更新署名の公開鍵は desktop の検証設定へ固定し、秘密鍵を desktop や配布する成果物へ含めない。
更新署名鍵の保管、参照、回転、失効は [concerns/secrets](../../concerns/secrets/README.md) に従う。
成果物の署名と provenance は [tools/build/cosign](../../tools/build/cosign.md) に従い、この file で手順を重複して規定しない。

### 根拠
NetSparkleUpdater は Windows・macOS・Linux の更新 package を扱い、C# の .NET 6 以降で利用できる。
`Ed25519Checker(SecurityMode.Strict, ...)` は app cast と更新 package の署名検証を有効にし、`SecurityMode.Unsafe` は署名検証を無効にする。
app cast の署名ファイルと enclosure の更新 package 署名が別々に検証されるため、feed と package の改ざんをそれぞれ拒否できる。
PhotinoX は .NET の desktop host であり、NetSparkleUpdater の built-in UI を使わずに core package と desktop の UI を組み合わせられる。

### 完了条件
desktop が `Ed25519Checker(SecurityMode.Strict, ...)` を使っている。
検証公開鍵が desktop の検証設定へ固定されている。
app cast の署名ファイルと更新 package の署名が存在し、正しい署名だけが更新へ進む。
署名のない更新 package と不正な署名の更新 package が適用されない。
production の配線に、署名検証を迂回する `IAppCastHandler` が存在しない。
更新 feed と更新 package が project 管理の HTTPS 配布先から取得されている。
更新署名の秘密鍵が desktop と配布する成果物に含まれていない。
成果物の署名と provenance が [tools/build/cosign](../../tools/build/cosign.md) の定める検証を満たしている。
成果物の署名と provenance が、更新署名と混同されずに扱われている。

### 禁止事項
`SecurityMode.Unsafe` を使うこと。
署名検証を迂回する `IAppCastHandler` を使うこと。
app cast の署名ファイルまたは更新 package の署名がない更新を適用すること。
更新署名の秘密鍵を desktop、app cast、更新 package、または配布先へ置くこと。
成果物の署名と provenance の手順を、この file に重複して規定すること。

### 行動
`NetSparkleUpdater.SparkleUpdater` を参照し、`Ed25519Checker(SecurityMode.Strict, ...)` と検証公開鍵を `SparkleUpdater` に渡す。
App Cast Generator で app cast の署名ファイルと各更新 package の署名を生成する。
app cast と署名ファイル、更新 package を project 管理の HTTPS 配布先へ配置する。
更新署名の秘密鍵を [concerns/secrets](../../concerns/secrets/README.md) の規律で管理し、検証公開鍵だけを desktop の検証設定へ固定する。
成果物の署名と provenance を [tools/build/cosign](../../tools/build/cosign.md) の採用に従って生成し、検証する。
`SecurityMode.Unsafe` と署名検証を迂回する handler を採用しない。
