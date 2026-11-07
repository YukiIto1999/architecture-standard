# oxlint

用途は、型情報を要さない規則の違反をビルドで止める linter である。
採用は、TypeScript は oxlint である。
判断基準は、[typescript](./inspection.md) の inspection が割り当てる規則を TypeScript の全体に一律に強制し、警告をリポジトリの検証入口でエラーとして扱え、規則の設定を [vite-plus](./vite-plus.md) の `vite.config.ts` の `lint` block に置けることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 汎用名と添字ループと自由文出力を lint で止める

### 要求
識別子の汎用名は、id-denylist で data・info・temp・result などの一覧を定めて禁止する。
添字だけで要素を読む for 文は、typescript/prefer-for-of で禁止し、for-of か名前のある集合操作で書く。
console への出力は、no-console で禁止し、telemetry の port と console 相当の出力層だけを許可指定で除く。

### 根拠
data・info・temp のような汎用名は生成時に混入しやすく、id-denylist は [restrict-generic-names](../../principles/naming/restrict-generic-names.md) の「汎用名・略語・一時名を制限する」を識別子の denylist として機械化する。
添字だけで要素を読む for 文は範囲と増分の誤りの余地を持つので、typescript/prefer-for-of で for-of へ直させる。
この lint は反復の形だけを検出し、集合の規則の置き場と実装の形の選択は [named-collection-operations](../../principles/construction/named-collection-operations.md) の「集合処理を名前のある操作で表す」が定める。
自由文の console 出力は [structured-events](../../concerns/observability/structured-events.md) の「事実をイベントとして表し、構造化して出す」を素通りするため、no-console で止める。

### 完了条件
id-denylist に汎用名の一覧が定められ、違反が検証入口でエラーとして扱われている。
typescript/prefer-for-of が有効になっている。
no-console が有効で、許可が telemetry の port と console 相当の出力層に限られている。

### 禁止事項
汎用名の一覧を空にして id-denylist を無効化すること。
telemetry を経ない console 出力を業務コードに置くこと。

### 行動
[vite-plus](./vite-plus.md) の `vite.config.ts` の `lint` block へ id-denylist・typescript/prefer-for-of・no-console を定め、違反箇所は名前の付け直し・for-of か名前のある集合操作・telemetry の port へ直す。

