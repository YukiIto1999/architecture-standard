# secrets

## 概要
secrets は、資格情報・鍵の保存・参照・回転・失効・監査の lifecycle を統べる規律である。
principles の [separation](../principles/separation.md) が定める関心の隠蔽を、全系の secrets の扱いとして具象化する。
secret の値と lifecycle の正本は secrets であり、[configuration](./configuration.md) は secret 参照の型と起動時の解決を書く。

## secret を分けて専用の型に封じる

### 要求
secret は設定と分けて扱い、専用の型に封じる。
secret を平文で保存せず、ログや応答に出さない。
設定には secret の値でなく参照を置き、値は起動時に専用の仕組みから解決する。
secret は回転・失効・期限・監査の対象にする。

### 根拠
secret を一般の設定と同じに扱うと、ログや応答に紛れて漏れる。
専用の型に封じれば、表示や直列化を型で塞げる。
平文の保存は、保存先の漏洩でそのまま流出する。
値でなく参照を置き起動時に解決すれば、値が設定やコードに残らない。
回転・失効・期限の対象にすれば、漏れた secret の有効な期間を短くできる。

### 完了条件
secret が、設定と分けて専用の型に封じられている。
secret が、平文で保存されていない。
secret が、ログや応答に出ていない。
設定が secret の値でなく参照を持ち、値が起動時に解決されている。
secret が、回転・失効・期限と、誰がいつ使ったかの監査の対象になっている。
リポジトリを公開しても、資格情報が漏れない。

### 禁止事項
secret を、平文の設定やコードに置くこと。
secret を、ログや応答に出すこと。
secret を、ビルドの成果物やイメージへ焼き込むこと。
secret を、必要のない子プロセスへまで継承させること。

### 行動
secret を専用の型に封じ、表示と直列化を塞ぐ。
設定には参照だけを置き、値は起動時に専用の仕組みから解決する。
secret の保存・回転・監査は、専用の仕組みへ委ねる。

### 例

secret を一般の設定と同じ値として扱うと、ログへ漏れる。

```
log(config)
```

secret を専用の型へ封じ、表示と直列化を塞ぐ。平文を取り出せる経路は必要な箇所へ限定する。

```
class Secret { toString() { return "***" }; expose(): string { ... } }
```

## 参照
設定へ secret の参照を置き、起動時に値を解決する適用は [configuration](./configuration.md) が書く。
暗号の姿勢は [security](./security.md) に従う。
配備における secret の置き場は [structure/deploy](../structure/deploy/) が定める。
