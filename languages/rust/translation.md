# translation

## 概要
translation は、Rust で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、Rust の機構で満たす。
失敗の型そのものの宣言は [thiserror](./thiserror.md) が持つ。
server が外へ出す表現の形式は [axum](./axum.md) が持つ。
境界での parse の実現は [serde](./serde.md) が持つ。
契約生成と drift 検査の規律は [progenitor](./progenitor.md) が持つ。

## 境界表現の型を surface の crate に置き、From で写す

### 要求
公開契約の body とエラーのデータは、生成 DTO をそのまま使う。
surface の枠組みが要求する応答 status、header、終了の値と trait は、その surface の crate が所有する境界表現の型で表す。
境界表現の型は生成 DTO を保持または参照し、同じ意味の field や variant を手書きで再定義しない。
surface の枠組みが要求する trait は、その crate で定義した境界表現の型へ実装する。
このローカル型への写しは、同じ crate に置く `From` の実装で書き、`Into` と `TryInto` は実装しない。
生成 DTO とコンテキストの application 入出力の写像は core の composition が所有し、両型が foreign なときは mapper 関数で書く。
`From` の本体で失敗を写す場合は、公開された失敗の enum を match で網羅し、variant ごとに status や終了の値を決める。
境界表現の値に、エラーの `Display` の文字列、`source()` がたどる連鎖、`{:?}` の出力を入れない。
console の entry point は、その crate で定義した境界表現の型を返し、その型へ `Termination` を実装する。

### 根拠
orphan rule は、trait と対象の型のいずれかがその crate のものでなければ、trait の実装を拒む。
[structure/skeleton](../../structure/skeleton.md) が定める依存方向は、core から surface への依存を持たない。
よって core の型へ枠組みの trait を実装する道は、どちらの crate から書いても初めから無い。
surface が status、header、終了の値を持つローカル型を所有すれば、生成 DTO を写し直さず、その型に枠組みの trait を実装できる。
`Into` と `TryInto` は `From` と `TryFrom` から blanket 実装で導かれるので、別に書くと同じ変換が二本になる。
thiserror の `#[from]` は同じ field を `#[source]` として扱い、`#[error(transparent)]` は `Display` と `source` を下位のエラーへ素通しする。
したがって文字列化と `source()` の連鎖を境界表現へ載せると、下位の crate が書いた文言がそのまま外へ届く。
`Result` に対する `Termination` の実装は、`Err` を `Debug` の書式で標準エラー出力へ書いてから `ExitCode::FAILURE` を返す。
`Debug` の書式は enum の variant 名と field をそのまま並べるので、そこに載った下位のエラーが利用者の端末へ出る。
entry point の戻り値を自前の型にすれば、終了の値の決定が同じ `From` の実装に集まる。

### 完了条件
公開契約の body とエラーが生成 DTO を使い、surface 固有の status、header、終了の値を表す型だけが surface の crate にある。
枠組みの trait の実装が、その crate で定義した型に対して書かれている。
surface のローカル型への写しが同じ crate の `From` にあり、生成 DTO と application 入出力の写像が composition にある。
`Into` と `TryInto` の実装が、無い。
失敗を写す `From` の本体が、公開された失敗の enum の全ての variant を match で網羅している。
境界表現の値に、`Display` の文字列、`source()` の連鎖、`{:?}` の出力が入っていない。
console の entry point の戻り値が、`Termination` を実装した自前の型である。

### 禁止事項
core の型に対して、surface の枠組みの trait を実装すること。
`Into` と `TryInto` を実装すること。
エラーの文字列化、`source()` がたどる連鎖、`{:?}` の出力を、境界表現の値へ入れること。
console の entry point から `Result` を返し、終了の値の決定を `Termination` の既定の実装へ委ねること。
枠組みの trait を実装するために、公開契約と同じ意味の手書き DTO を surface に置くこと。

### 行動
生成 DTO を保持または参照する surface 固有の境界表現の型を定義し、枠組みの trait をその型へ実装する。
同じ crate に、core の公開 operation が返す生成されたエラーや公開 outcome からの `From` を置く。
match の各腕で、binding に従う status、header、終了の値を決め、契約のデータを再定義しない。
console は entry point の戻り値を自前の型にし、その型の `report` で `ExitCode` を返す。
エラーの文字列化は報告の経路に限り、境界表現の組み立てには使わない。

### 例
core の型へ枠組みの trait を実装しようとすると、orphan rule と依存の向きの両方に当たる。

```rust
impl IntoResponse for OrderError { /* ... */ }
fn main() -> Result<(), ImportError> { run() }
```

surface の crate に HTTP の status と生成されたエラーを束ねる境界表現の型を置き、`From` の match で status を決める。

```rust
pub struct OrderProblem {
    status: StatusCode,
    body: generated::OrderError,
}
impl From<generated::OrderError> for OrderProblem {
    fn from(error: generated::OrderError) -> Self {
        let status = match &error {
            generated::OrderError::NotFound => StatusCode::NOT_FOUND,
            generated::OrderError::Conflict => StatusCode::CONFLICT,
        };
        Self { status, body: error }
    }
}
impl IntoResponse for OrderProblem {
    fn into_response(self) -> Response { /* ... */ }
}
```

console は自前の型に `Termination` を実装し、終了の値を `From` で決める。

```rust
pub struct ImportOutcome(ExitCode);
impl From<ImportError> for ImportOutcome {
    fn from(error: ImportError) -> Self {
        Self(match error {
            ImportError::NotFound => ExitCode::from(NOT_FOUND_CODE),
            ImportError::Invalid => ExitCode::from(INVALID_CODE),
        })
    }
}
impl Termination for ImportOutcome {
    fn report(self) -> ExitCode { self.0 }
}
fn main() -> ImportOutcome {
    match run() {
        Ok(()) => ImportOutcome(ExitCode::SUCCESS),
        Err(error) => ImportOutcome::from(error),
    }
}
```

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、未知フィールドの残存と収縮は [evolution](../../principles/evolution/README.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
