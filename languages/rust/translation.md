# translation

## 概要
translation は、Rust で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信を、Rust の機構で満たす。
失敗の型そのものの宣言は [thiserror](./thiserror.md) が持つ。
server が外へ出す表現の形式は [axum](./axum.md) が持つ。
境界での parse の実現は [serde](./serde.md) が持つ。
共通の生成経路は [tools/build/typespec](../../tools/build/typespec.md) が定める。

## 境界表現の型を surface の crate に置き、From で写す

### 要求
公開契約の body とエラーのデータは、生成 DTO をそのまま使う。
公開契約の HTTP・protocol の status・header・body と dispatch は生成した提供側接続が所有し、surface はその登録と配線だけを行う。
境界表現の型は生成 DTO を保持または参照し、同じ意味の field や variant を手書きで再定義しない。
console の終了表現など、生成した提供側接続が所有しない surface 固有の trait は、その surface の crate が所有する境界表現の型へ実装する。
このローカル型への写しは、同じ crate に置く `From` の実装で書き、`Into` と `TryInto` は実装しない。
生成 DTO とコンテキストの application 入出力の写像は [structure/contracts/adapters](../../structure/contracts/adapters.md) が所有し、両型が foreign なときは mapper 関数で書く。
`From` の本体で失敗を写す場合は、公開された失敗の enum を match で網羅し、variant ごとに surface 固有の終了の値を決める。
境界表現の値に、エラーの `Display` の文字列、`source()` がたどる連鎖、`{:?}` の出力を入れない。
console の entry point は、その crate で定義した境界表現の型を返し、その型へ `Termination` を実装する。

### 根拠
orphan rule は、trait と対象の型のいずれかがその crate のものでなければ、trait の実装を拒む。
[structure/skeleton](../../structure/skeleton.md) が定める依存方向は、core から surface への依存を持たない。
よって core の型へ枠組みの trait を実装する道は、どちらの crate から書いても初めから無い。
surface が独自の終了の値を持つローカル型を所有すれば、core の型を外部 framework に依存させずに、その型へ trait を実装できる。
`Into` と `TryInto` は `From` と `TryFrom` から blanket 実装で導かれるので、別に書くと同じ変換が二本になる。
thiserror の `#[from]` は同じ field を `#[source]` として扱い、`#[error(transparent)]` は `Display` と `source` を下位のエラーへ素通しする。
したがって文字列化と `source()` の連鎖を境界表現へ載せると、下位の crate が書いた文言がそのまま外へ届く。
`Result` に対する `Termination` の実装は、`Err` を `Debug` の書式で標準エラー出力へ書いてから `ExitCode::FAILURE` を返す。
`Debug` の書式は enum の variant 名と field をそのまま並べるので、そこに載った下位のエラーが利用者の端末へ出る。
entry point の戻り値を自前の型にすれば、終了の値の決定が同じ `From` の実装に集まる。

### 完了条件
公開契約の body とエラーが生成型を使い、HTTP・protocol の結果と wire 表現の対応が生成した提供側接続に閉じている。
枠組みの trait の実装が、その crate で定義した型に対して書かれている。
surface のローカル型への写しが同じ crate の `From` にあり、生成 DTO と application 入出力の写像が contracts/adapters にある。
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
HTTP・protocol は生成した提供側接続を登録し、契約 adapter の handler と認証境界を配線する。
console 固有の終了表現はその crate の型として定義し、同じ crate に公開された失敗からの From を置く。
match の各腕で console の終了の値を決め、契約の status・header・body の写像を手書きしない。
console は entry point の戻り値を自前の型にし、その型の `report` で `ExitCode` を返す。
エラーの文字列化は報告の経路に限り、境界表現の組み立てには使わない。

### 例
core の型へ枠組みの trait を実装しようとすると、orphan rule と依存の向きの両方に当たる。

```rust
impl IntoResponse for OrderError { /* ... */ }
fn main() -> Result<(), ImportError> { run() }
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

## 生成した契約値の構築と所有権を守る

### 要求
distinct scalar は private field の newtype、object は private field の struct、判別付き直和と operation の各結果は閉じた enum に生成する。
alias は同じ型への参照として扱い、通常の field 制約は所有する model の構築と decode で検証し、制約名だけを理由に newtype を足さない。
local 構築と decode は Result で受理値または位置・規則を持つ構造化した違反情報を返し、検証なしの Deserialize、制約を破る Default、公開 mutable field を生成しない。
読み出しは共有参照、所有する値の取り出しは消費する accessor とし、String と Vec を受け取って所有権を移せる構築で clone を加えない。
required nullable の存在は Option の値と別に追跡し、optional nullable は未指定・null・値を区別する生成型と専用 codec で保持する。
decimal と日時は、契約が要求する値域・同値性・精度・scale・offset を保存する検証済み表現を使い、標準型や有限精度型の範囲へ契約を狭めない。
生成した enum に non_exhaustive を付けて、宣言結果の追加を利用側の網羅検査から隠さない。
深い値の全経路は [structure/contracts/generated](../../structure/contracts/generated.md) の「生成能力」に従い、非公開 storage と明示的な走査状態で処理する。
Drop と、公開する Clone・Debug・等価性・hash の実装も対象にし、parse だけを非再帰にして derive や解放に再帰を残さない。
JSON の字句解析は既存 parser を再利用し、[structure/contracts/layout](../../structure/contracts/layout.md) の「JSON の相互運用 profile」を満たす受入処理へ接続する。

### 根拠
private field と fallible constructor は生成値の検証を構築の一点に閉じ、所有権の移動は可変 alias を残さず不要な複製を避ける。
Option だけでは field の欠落と明示的な null が同じ形になりうるため、codec が存在を追跡する必要がある。

### 完了条件
役割の異なる scalar が型検査で取り違えを拒否し、alias の互換と通常の field の primitive 表現が保たれている。
local 構築と decode が同じ制約へ照合され、存在状態と契約の全受理値域が保存されている。
検証を迂回する Default・Deserialize・mutable accessor がなく、移せる storage が不要に clone されていない。
共通の wire profile と深さ・診断保持の検査が、[structure/tests/methods](../../structure/tests/methods.md) の「契約の意味と生成」へ接続されている。

### 禁止事項
生成値の不変条件を derive の既定動作だけで満たしたと扱うこと。
通常の制約を全て newtype にし、役割の別型化と混同すること。

### 行動
Rust emitter に private field、fallible constructor、検証付きの codec と消費する accessor を含める。
入力処理と local 構築は、検証済み graph を public constructor で再走査せず、private な検証・完成処理を共有する。
生成した契約値は業務型と独立に所有し、contracts/adapters の mapper を application の公開入力構築へ接続する。

## 生成した通信処理を既存の効果へ接続する

### 要求
型・構築・codec の crate を consumer transport と提供側 dispatch の実行機構から分け、reqwest・Tokio なしで利用できるようにする。
通信操作は [connection](./connection.md) の Future・Result と [coordination](./coordination.md) が定める期限・取消の機構へ接続する。
HTTP transport は接続先と rustls を有効にした reqwest の instance を引数で受け、[structure/contracts/generated](../../structure/contracts/generated.md) の「応答の分類」に従って status・media type・識別情報から結果を選び、body の decode まで完了して返す。
宣言した全成功を異なる outcome として保持し、宣言した拒否は操作の想定内失敗の Err に写す。
502・503・504 の中継由来の不一致と通信の不成立は通信の Err、自身の上限超過は別の Err、その他の契約不一致と要求組立の欠陥は panic にする。
reqwest や OS 自身の timeout は自身の timeout の Elapsed と混同せず通信の Err にし、呼出側の取消は tokio-util の既存の機構で終了する。
非 streaming の body は呼出中に読み切り、binary を text に変換せず、完了後の取消で確定した結果を変えない。
生成した提供側 handler・dispatch の trait は contracts 側の Interface とし、手書き Adapter が独立した application Interface へ接続し、core は composition を含めて全生成 crate を参照しない。

### 根拠
生成した通信処理が結果の識別と codec を所有すれば、consumer が生の body を復元したり成功の種別を制限したりする必要がない。
crate の依存を分ければ、型と codec の利用に通信 runtime を強制せず、core の非依存も crate graph で照合できる。

### 完了条件
純粋な生成型の crate の依存 closure に reqwest と通信 runtime がなく、core の全 crate に生成 crate への参照がない。
複数の成功、body のない結果、拒否、契約不一致、通信・上限・取消が生成通信処理で区別されている。
提供側 dispatch が手書き Adapter と独立した application Interface に接続されている。

### 禁止事項
生成器の制限に合わせて成功結果の body を同じ一種類へ揃えること。
consumer の mapper で生の応答を再 decode し、status の範囲や最初に decode できた payload から outcome を決めること。
core の composition にデータだけの生成 crate を参照させること。

### 行動
通信を含まない crate と通信を含む crate を別に生成し、実行する port の実装へ接続する。
実応答、本文途中切断、接続拒否、組立失敗、上下位の timeout と取消の競合を inspection の検証へ接続する。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、未知フィールドの受容と検知は [serde](./serde.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
