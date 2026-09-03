# translation

## 概要
translation は、Rust で外部表現とドメイン型の変換を扱う実現軸である。
principles の [separation](../../principles/separation/README.md) が定める境界での変換と、concerns の [types](../../concerns/types/README.md) が定める境界での parse・[security](../../concerns/security/README.md) が定める境界の不信・[effect](../../concerns/effect/README.md) が定めるエラーモデルを、Rust の機構で満たす。
境界での parse の実現は [serde](./serde.md) が持つ。

## 終了を surface の境界表現へ写す

### 要求
server、console、worker、host、extension の全 surface は、終了を成功、想定内の失敗、欠陥、取り消しに同じ基準で分類する。
想定内の失敗は、各 surface の契約が定める失敗表現へ境界で写す。
panic で表す欠陥は、各 surface の最上位の報告境界で記録して失敗させる。
取り消しは、想定内の失敗へ変換しない。
内部の実装の詳細は、surface の出力へ出さない。

### 根拠
終了の分類を surface ごとに変えると、同じ事象が入口によって失敗にも欠陥にもなり、回復方法が揺れる。
想定内の失敗だけを surface の契約へ写せば、利用側が処理できる終了と運用が扱う欠陥を分けられる。
取り消しを失敗へ変換すると、呼び出し側が諦めた計算を業務上の失敗と誤認する。
内部の詳細を出力すると、利用側を実装へ結合させ、攻撃の手がかりを与える。

### 完了条件
全 surface で、終了が成功、想定内の失敗、欠陥、取り消しに同じ基準で分類されている。
想定内の失敗が、各 surface の契約が定める失敗表現へ境界で写されている。
欠陥が、各 surface の最上位の報告境界で記録されている。
取り消しが、想定内の失敗へ変換されていない。
surface の出力に、内部の実装の詳細が出ていない。

### 禁止事項
同じ終了を、surface ごとに異なる基準で失敗または欠陥へ分類すること。
欠陥や取り消しを、想定内の失敗として surface の契約へ写すこと。
内部の実装の詳細を、surface の出力へ出すこと。

### 行動
成功、想定内の失敗、欠陥、取り消しを [effect](../../concerns/effect/README.md) の基準で分類する。
想定内の失敗だけを、各 surface の契約が定める表現へ境界で写す。
欠陥は最上位の報告境界で記録し、取り消しは失敗へ変換せず終了させる。
surface の出力から内部の詳細を除く。

### 例
各 surface は同じ分類を使い、想定内の失敗だけを自身の契約へ写す。panic は最上位で報告し、取り消しは `Err` へ変換しない。

```rust
match run(input).await {
    Ok(value) => surface.publish_success(value),
    Err(failure) => surface.publish_expected_failure(failure),
}
```

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の Rust の client と型は、[tools/build/typespec](../build/typespec.md) が採用した経路で生成する。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から生成すれば、client と型が契約に従う。
生成経路を tools の採用へ一本化すれば、言語文書は生成物の使い方だけを所有できる。

### 完了条件
client と型が、TypeSpec から `@typespec/openapi3` を経て openapi-generator の rust generator で生成されている。

### 禁止事項
契約から生成する client と型を手で書き写すこと、または tools と別の generator を選ぶこと。

### 行動
TypeSpec から `@typespec/openapi3` で OpenAPI を出力し、openapi-generator の rust generator(library=reqwest)で client と型を生成する。

## 参照
境界の到達点となる型は [formation](./formation.md)、エラーモデルは [effect](../../concerns/effect/README.md)、未知フィールドの残存と収縮は [evolution](../../principles/evolution/README.md)、契約の生成物の置き場と drift 検査は [structure/contracts/generated](../../structure/contracts/generated.md)、契約の置き場は [structure/contracts](../../structure/contracts/layout.md) に従う。
