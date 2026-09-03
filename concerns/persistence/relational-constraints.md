## 関係の意図を制約で表す

### 要求
外部キー・一意・NOT NULL・検査で関係の意図を表す。
任意の項目は本体の nullable でなく、値があるときだけ行が存在する別の関係に切り出す。
整合性をデータ層で守る規則は、[data](../../principles/data/README.md) に従う。

### 根拠
データ層の制約で守る理由は [data](../../principles/data/README.md) に従う。
外部キーは関係の意図そのものを表し、NOT NULL と一意は欠けてはならない値と重複してはならない値を保証する。
NULL は三値論理を持ち込んで一意や検査の意味を崩すので、任意の項目は別の関係へ切り出す。

### 完了条件
業務上必要な関係が、外部キー制約で表されている。
欠けてはならない値に NOT NULL、重複してはならない値に一意制約が付いている。
任意の項目が、本体の nullable でなく、値があるときだけ行が存在する別の関係に切り出されている。

### 禁止事項
任意の項目を、本体の nullable な列として持つこと。
NULL を含む列に、一意制約や検査制約の意味を頼ること。

### 行動
データ間の関係を確認し、外部キーで表せる関係を制約にする。
欠けてはならない値と重複してはならない値に、NOT NULL と一意制約を付ける。
任意の項目は、本体の nullable でなく別の関係へ切り出す。

### 例

関係をアプリケーションの規約だけで守り、任意項目を同じ関係の nullable な列に置くと、データベースが不正な状態を拒否できない。

```sql
order_lines(id, order_id, sku, qty, note)
```

関係と一意性を制約で守り、任意項目は別の関係へ切り出す。

```sql
order_lines(
  id,
  order_id  REFERENCES orders(id),
  sku       NOT NULL,
  qty       NOT NULL CHECK (qty > 0),
  UNIQUE(order_id, sku)
)
order_line_notes(line_id REFERENCES order_lines(id) PRIMARY KEY, note NOT NULL)
```
