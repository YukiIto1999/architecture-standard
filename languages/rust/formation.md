# formation

## 概要
formation は、Rust で値・型・不変条件をモデリングする実現軸である。
principles の [modeling](../../principles/modeling.md) が定める業務意味の型封入と、concerns の [types](../../concerns/types.md) が定める型の規律を、Rust の機構で満たす。

## 業務の値を型に封じる

### 要求
業務の値は単一フィールドの tuple struct(newtype)で表し、内部のフィールドを非公開にする。
構築は不変条件を検証して Result を返す関連関数に一点化し、読み出しは参照を返す accessor で行う。

### 根拠
newtype は実行時の負荷なく、型に業務の意味を載せる。
フィールドを非公開にし、検証を通った構築だけを公開すれば、その型の値を持つこと自体が検証済みの証になる。
プリミティブのまま渡し回すと、検証が呼び出し側に散り、取り違えと未検証の値が内側に紛れる。

### 完了条件
業務の値が、newtype で表されている。
内部のフィールドが、非公開である。
構築が検証付きの関連関数に限られ、検証を通らない値を作れない。

### 禁止事項
業務の値を、プリミティブのまま渡し回すこと。
検証を経ない構築経路を、公開すること。

### 行動
プリミティブで渡している業務概念を newtype にし、非公開フィールドと検証付きの `try_new` あるいは `TryFrom` に構築を集める。
`#[derive(Debug, Clone, PartialEq, Eq, Hash)]` で付随する実装を得る。

### 例
プリミティブをそのまま受け取ると、任意の文字列が通り、検証が呼び出し側に散る。

```rust
fn send(to: String) { /* ... */ }
```

newtype に封じ、構築を検証付き関連関数に一点化する。

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Email(String);
impl Email {
    pub fn try_new(value: String) -> Result<Self, EmailError> {
        if value.contains('@') { Ok(Email(value)) } else { Err(EmailError::Invalid) }
    }
    pub fn as_str(&self) -> &str { &self.0 }
}
```

## 不正な状態を構築できなくする

### 要求
場合分けのある概念は enum で表し、crate の内部では網羅の match で分岐の漏れを型検査に検出させる。
不在は Option で表し、null の代わりの番兵値を使わない。
crate の外へ公開する enum にだけ `#[non_exhaustive]` を付ける。

### 根拠
enum は取りうる状態を型で枚挙し、データ付きバリアントは状態固有のデータを同梱する。
網羅の match は、バリアントの取りこぼしをコンパイルエラーにする。
bool の組み合わせや番兵値は、ありえない組を表現できてしまう。
Option は不在を型で表し、値の有無の取り違えを型検査で防ぐ。
crate の外の列挙は契約の進化に備えて開き、下流は寛容な読み手として既定分岐を持つ。内部の閉じた直和には付けない。

### 完了条件
場合分けが、enum で表されている。
内部の分岐が網羅の match で書かれ、バリアントの追加がコンパイルエラーで気づける。
不在が、Option で表されている。
内部の enum に、`#[non_exhaustive]` が付いていない。

### 禁止事項
取りうる状態を、bool や番兵値の組み合わせで表すこと。
網羅でない分岐で、バリアントの追加を見逃すこと。

### 行動
状態の集合を enum にし、内部の分岐を網羅の match で書く。
不正な遷移を静的に禁じたい箇所は、状態を型引数に載せ遷移メソッドの戻り型を変える型状態で表す。

### 例
状態を bool の組で表すと、active かつ deleted のような不正な組を作れる。

```rust
struct User { active: bool, deleted: bool }
```

状態を enum で枚挙すれば、網羅の match によって分岐の漏れがコンパイルエラーになる。

```rust
enum UserStatus { Active, Suspended, Deleted }
```

静的に遷移を制限する箇所では、状態を型引数に載せ、許可する遷移だけをメソッドとして公開する。

```rust
struct Active;
struct Suspended;
struct Deleted;
struct User<S> { name: String, state: std::marker::PhantomData<S> }
impl User<Active> {
    fn suspend(self) -> User<Suspended> { User { name: self.name, state: std::marker::PhantomData } }
}
```

## 不変の束縛と共有参照を既定にする

### 要求
domain の集約、値、イベントと、境界を越えて共有する値は、不変に扱う。
domain の状態遷移は既存の値を `&mut T` で変更せず、新しい値と発生したイベントを返す。
束縛は immutable を既定とし、共有する読み出しは `&T` で受ける。
`&mut T` による局所更新は、infrastructure が所有する状態または構築途中の値のうち、共有されず外部から観測されない所有範囲に限る。

### 根拠
domain の値を不変にする理由は、[construction](../../principles/construction.md) に従う。
発生したイベントを不変な事実として残す理由は、[data](../../principles/data.md) に従う。
domain の既存値を `&mut T` で変更すると、遷移前の状態が失われ、状態の変更と発生したイベントの対応が戻り値に現れない。
新しい値とイベントを一緒に返せば、遷移後の状態と発生した事実が呼び出し側へ明示される。
Rust の排他借用は同じ値への参照の共存を防ぐが、それだけでは domain の値を不変に扱う規律を表さない。
共有されず外部から観測されない所有範囲の局所更新は、他の読み手が見る値を背後で変えない。

### 完了条件
domain の集約、値、イベントと、境界を越えて共有する値が、不変に扱われている。
domain の状態遷移が、既存値を変更せず、新しい値とイベントを返している。
共有する読み出しが、`&T` で行われている。
`&mut T` による局所更新が、infrastructure の所有状態または構築途中の値に限られている。
`&mut T` で更新する値が、更新中に共有されず外部から観測されていない。

### 禁止事項
domain の集約、値、イベントまたは境界を越えて共有する値を、`&mut T` で変更すること。
domain の状態遷移で、既存値だけを変更して新しい値とイベントを返さないこと。
共有される値または外部から観測できる値を、infrastructure の都合で局所更新すること。

### 行動
domain の集約、値、イベントと境界を越えて共有する値を、immutable な束縛と `&T` で扱う。
domain の状態遷移は既存値を読み、新しい値とイベントを組にして返す。
infrastructure の所有状態と構築途中の値だけを、共有と外部観測の前に `&mut T` で局所更新する。
局所更新を終えてから、完成した値を共有または境界へ公開する。

### 例
domain の既存値を直接変更すると、遷移後の値と発生したイベントの対応が戻り値に現れない。

```rust
fn approve(order: &mut Order) { order.status = Status::Approved; }
```

既存値を変えず、新しい値と発生したイベントを一緒に返す。

```rust
fn approve(order: &Order) -> Result<(Order, OrderApproved), ApprovalError> {
    let approved = Order { status: Status::Approved, ..order.clone() };
    let event = OrderApproved { order_id: order.id() };
    Ok((approved, event))
}
```

infrastructure の構築途中の値は、共有と外部観測の前に限って局所更新する。

```rust
let mut batch = Vec::with_capacity(rows.len());
for row in rows { batch.push(to_record(row)?); }
publish(batch);
```

## 意味と単位を型で区別する

### 要求
意味や単位が異なる値は、構造が同じでも別の newtype で区別する。

### 根拠
同じ `f64` でも距離と時間は別の概念で、取り違えると誤った計算になる。
別の newtype にすれば、構造が同型でもコンパイラが取り違えを拒否する。

### 完了条件
意味や単位が異なる値が、別の型で区別されている。
取り違えが、コンパイルエラーになる。

### 禁止事項
意味や単位の異なる値を、同じプリミティブで扱うこと。

### 行動
単位ごと・識別子ごとに newtype を分け、値を取り出すときだけ内部に触れる。

### 例
`Miles` を要求する関数に `Kilometers` を渡すと、型エラーになる。

```rust
struct Miles(f64);
struct Kilometers(f64);
fn is_marathon(distance: &Miles) -> bool { distance.0 >= 26.2 }
```

## 生成と検証の macro を libs の proc-macro crate に分ける

### 要求
値オブジェクトの定型実装を補う derive macro や、規律を compile 時に検査する属性 macro を使う場合、それらは libs の機構として core と別の proc-macro crate に置く。
この crate は `Cargo.toml` の `[lib]` に `proc-macro = true` を設定する。

### 根拠
compile 時のツールが実行時の層に属さず出荷物にも含まれない理由は [structure/libs/layout](../../structure/libs/layout.md) に従う。
Rust の proc-macro crate type は、Rust Reference が「手続き的 macro だけを export しなければならない」と定める crate type で、通常の公開 API を同じ crate から export できない。
crate を分ければ、macro の定義と、それを使う core の実行時コードが、依存の向きでも成果物でも混ざらない。
Rust は enum の網羅の match と Option・Result を言語機構として持つので、他言語に要る網羅検査の補いは要らない。proc-macro が要るのは、定型実装の生成や、言語機構だけでは表せない規律の compile 時検査に限る。

### 完了条件
derive macro・属性 macro が、libs の機構として core と別の proc-macro crate にある。
その crate が `proc-macro = true` の crate type を持ち、通常の型や関数を export していない。

### 禁止事項
proc-macro を、core の crate に同居させること。
proc-macro crate から、通常の型や関数を公開すること。

### 行動
生成と検証の macro を libs 配下の別の proc-macro crate にし、`[lib] proc-macro = true` を設定する。
core の crate は proc-macro crate を通常の依存として参照し、macro の展開だけを使う。

### 例
`Cargo.toml` で proc-macro crate を宣言する。

```toml
[lib]
proc-macro = true
```

`lib.rs` は手続き的 macro だけを export し、core は展開だけを使う。

```rust
#[proc_macro_derive(ValueObject)]
pub fn derive_value_object(input: TokenStream) -> TokenStream { /* ... */ }
```

## 参照
業務意味の型封入は [modeling](../../principles/modeling.md)、型の規律は [types](../../concerns/types.md)、置き場は [structure/core/domain](../../structure/core/domain.md)、proc-macro crate の置き場は [structure/libs/layout](../../structure/libs/layout.md) に従う。
命名と整形、ドキュメントコメントの体裁は [conventions](./conventions.md) に従う。
境界での外部表現の変換は [translation](./translation.md) に従う。
