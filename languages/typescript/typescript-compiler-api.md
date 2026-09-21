# TypeScript compiler API

用途は、依存方向と境界の禁止、および構文で判定できる形を実行可能な検査として検証する道具である。
採用は、TypeScript の構造検査に @typescript/typescript6 の compiler API を使う。
判断基準は、層の参照禁止・公開面・副作用の参照禁止を規則として書け、違反をリポジトリの検証入口で止められることである。compiler API が call expression の symbol、callee expression の型、parameter の initializer、destructuring の binding element を取得できることを含む。
撤回条件は、判断基準を満たさなくなることであり、@typescript/typescript6 の保守停止と、TypeScript 本体が安定 API を再び同梱したことを再評価のトリガーとする。

## 構造検査

### 要求
採用している TypeScript の構造検査は、@typescript/typescript6 の compiler API で構文木と semantic model を取得する。
call expression の symbol、callee expression の型、parameter の initializer、destructuring の binding element を構造検査で取得する。
取得した構造と型を、依存方向・公開面・副作用の参照禁止の規則へ照合する。

### 根拠
採用している TypeScript は検査が必要とする安定した compiler API を同梱せず、@typescript/typescript6 がその compiler API と宣言を提供する。
compiler API の構文木と semantic model を使えば、call expression、callee expression の型、parameter の initializer、destructuring の binding element を同じ構造検査で照合できる。

### 完了条件
構造検査が、@typescript/typescript6 6.0.2 の compiler API を取得している。
構造検査が、call expression の symbol と callee expression の型を取得している。
構造検査が、parameter の initializer と destructuring の binding element を取得している。
取得した構造と型が、依存方向・公開面・副作用の参照禁止の規則へ照合されている。

### 禁止事項
検査が必要とする安定した compiler API の代わりに、採用している TypeScript の unstable な subpath API だけへ依存すること。
compiler API が取得できる構造を、文字列の検索だけで判定すること。

### 行動
@typescript/typescript6 6.0.2 から compiler API を取得する。
compiler API で call expression の symbol、callee expression の型、parameter の initializer、destructuring の binding element を列挙する。
列挙した構造と型を、検証入口で規則へ照合する。
