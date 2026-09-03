# clap

用途は、CLI の surface の骨格である。
採用は、Rust は clap である。
判断基準は、引数を型で宣言して境界で一度 parse でき、依存を組立点から注入できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## console

### 要求
console は clap で組み、引数を型で宣言して境界で一度 parse する。

### 根拠
引数を型で宣言し境界で一度 parse すれば、引数が型に現れ、未検証の値が内側に入らない。
文字列のキーで引数を取り出すと、型に現れず手で復元することになる。

### 完了条件
console が clap で組まれている。
引数が型で宣言され、境界で一度 parse されている。

### 禁止事項
引数を、文字列のキーで取り出すこと。

### 行動
引数を struct・enum と derive で宣言し、入口で一度 parse する。

### 例
文字列のキーで引数を取り出すと、引数が型に現れず、手作業での復元が必要になる。

```rust
let matches = Command::new("app").arg(Arg::new("verbose")).get_matches();
```

derive で引数の型を宣言し、入口の一度の parse で構造化する。

```rust
#[derive(Parser)] struct Cli { #[arg(short, long)] verbose: bool, #[command(subcommand)] command: Commands }
let cli = Cli::parse();
```
