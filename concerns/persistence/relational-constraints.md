## 関係の意図を制約で表す

### 要求
外部キー・一意・NOT NULL・検査で関係の意図を表す。
属性の配置は [normalization](./normalization.md) に従い、同じ変更・保持・消去の単位の任意属性は、その関係の nullable な列で値の不在を表す。
独立した存在意味やライフサイクルを持つ任意の関係は、行の有無で存在を表す。
参照は一方向にし、表どうしの参照を循環させない。
業務事実、期間に付く属性、期間の中でだけ成り立つ現在関係の外部キーは、それが成り立つ最も内側の期間の始まりの行を参照し、人を表すリソースの属性もこれに従う。
互いに入れ子でない最も内側の期間が複数あれば、それぞれを参照し、どの期間にも属さない行はリソースを参照する。
この参照先の規則は、行がどの期間に属するかを示す外部キーに当てはめ、値として別のリソースや定義を指す外部キーには当てはめない。
参照先を参照元より先に消す契約がある場合(期間より長く残す証明書など)は、参照元から参照先を参照せず、両者を結ぶ関係を参照先の保持期限で置く。
結ぶ関係の行は、参照元を書く確定で一緒に書く書き換えない事実の行とし、連鎖削除を付けず、参照先の保持期限で消せる行のビューを通して参照先より先に消す。
同じものに属することは、共通の不変のキーを含む複合外部キーで守る。
連鎖削除は、同じ集約内で、単独で意味を持たない従属する行だけに付ける。
従属する行とは、終わりの業務事実、予定した終わりを定める業務事実、取り消しと訂正の業務事実、消去のために業務事実から分けた行、可変属性、現在関係である。
期間の内側で起きる業務事実(所属を参照する注文、貸出を参照する延長など)は従属する行に含めず、それ自身の保持期限で消し、参照先を先に消す契約がなければ、参照される始まりの行はそれが消えるまで残す。
値として別のリソースを指す外部キーに連鎖削除を付けるのは、指す側が同じ集約の可変属性か現在関係の場合に限り、定義を指す外部キーには付けない。
参照動作で列を空にする削除規則と、確定時まで検査を遅らせる制約を使わない。
関係をまたぐ排他のように、外部キー・一意・NOT NULL・検査では表せない不変条件は、決定の記録に列挙し、全ての書き込み経路が従う競合制御を [transaction](../transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従って割り当てる。
整合性をデータ層で守る規則は、[data](../../principles/data/database-integrity.md) に従う。

### 根拠
データ層の制約で守る理由と、守るために仕組みを足す基準は [data](../../principles/data/database-integrity.md) に従う。
外部キーは関係の意図そのものを表し、NOT NULL と一意は欠けてはならない値と重複してはならない値を保証する。
nullable な列を使う制約は、NULL が値の不在を表すことと三値論理を踏まえて設計し、欠如を許す範囲を明示する。
最も内側の期間の始まりの行を参照すれば、その期間を始めた対象にだけ参照元の行が付くことを、循環なしに外部キーが守る。
外部キーは参照先の行があることしか確かめないので、期間が今開いていること(退会していない、脱退していない)は守れず、書き込み経路が守る。
表どうしの参照を循環させると、どちらの行も先に作れないため確定時の検査が要り、片方を後から埋めるための空にできる列も要る。
複合外部キーのために写す不変のキーは、元の値が変わらず、一致を外部キーが常に強制するので、同期の作業を生まない。
参照動作で列を空にすると、参照元の行を書き換えるので、事実の行には使えない。
独立して存在できるデータへ連鎖削除を付けると、親の削除が無関係な行まで消す。
定義を指す関係へ連鎖削除を付けると、定義の削除が使われている行を黙って消す。
各関係の制約は自分の関係の行だけを検査するので、別の関係の行との同時成立は表せない。
たとえば同じ利用者に終わりのない停止が二つあることや、退会した利用者に開いた所属があることを、外部キーと一意制約は拒めない。

### 完了条件
業務上必要な関係が、外部キー制約で表されている。
欠けてはならない値に NOT NULL、重複してはならない値に一意制約が付いている。
任意属性の値の不在と、独立した関係の不在が区別され、任意性だけを理由に同じ変更・保持・消去の単位の属性が分割されていない。
外部キーのグラフに、表どうしの循環がない。
業務事実と期間に付く属性の外部キーが、参照先を先に消す契約がある場合を除き、それが成り立つ最も内側の期間の始まりの行を参照している。
同じものに属するべき行の組が、共通の不変のキーを含む複合外部キーで結ばれている。
連鎖削除が、同じ集約内の従属する行だけに付いており、別の集約が所有する行と定義を指す関係には付いていない。
参照動作で列を空にする削除規則と、確定時まで検査を遅らせる制約が使われていない。
外部キーで表せない関係をまたぐ不変条件が、決定の記録に列挙され、それぞれに書き込み経路の競合制御が割り当てられている。

### 禁止事項
任意性だけを理由に、同じ変更・保持・消去の単位の属性を別の関係へ分割すること。
NULL の扱いを定めず、nullable な列への一意制約や検査制約だけで欠如や重複を拒めるとみなすこと。
表どうしの参照を循環させること。
業務事実と期間に付く属性の外部キーを、成り立つ最も内側の期間の始まりの行より外側の行へ向けること。
参照動作で列を空にする削除規則や、確定時まで検査を遅らせる制約を使うこと。
独立に存在できるデータや、別の集約が所有するデータへ、連鎖削除を付けること。
定義を指す関係へ、連鎖削除を付けること。
期間が今開いていることや、関係をまたぐ排他を、外部キーまたは一つの関係の制約で守られているとみなすこと。

### 行動
データ間の関係を確認し、外部キーで表せる関係を制約にする。
欠けてはならない値と重複してはならない値に、NOT NULL と一意制約を付ける。
任意属性は変更・保持・消去の単位で配置し、nullable な列の欠如と独立した関係の行の有無を区別する。
外部キーごとに、行が属する最も内側の期間を確かめ、その始まりの行を参照させ、削除規則を付ける。
同じものに属するべき行の組を見つけ、共通の不変のキーを含む複合外部キーで結ぶ。
外部キーのグラフに循環があれば、片方の参照を除き、除いた参照が守っていた条件を書き込み経路の規則にする。
外部キーで表せない不変条件を洗い出して決定の記録に列挙し、書き込みパスの競合制御へ割り当てる。

### 例

関係をアプリケーションの規約だけで守ると、データベースが不正な参照や数量を拒否できない。

```sql
order_lines(id, order_id, sku, qty, note)
```

関係と一意性を制約で守る。
この例のメモは、明細と異なる編集と消去の単位を持つため別の関係に置く。

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

利用者にログインに使うメールアドレスが一つ以上あることを、利用者の行から代表のメールアドレスへの参照で守ると、表どうしの参照が循環し、確定時の検査が要る。
利用者のキーの行に列が増え、退会でメールアドレスを消すには利用者の行を書き換えることになる。

```sql
CREATE TABLE users (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  primary_email_id BIGINT NOT NULL
);
CREATE TABLE user_emails (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id),
  email VARCHAR(254) NOT NULL UNIQUE
);
ALTER TABLE users ADD FOREIGN KEY (primary_email_id)
  REFERENCES user_emails (id) DEFERRABLE INITIALLY DEFERRED;
```

参照を一方向にし、件数の下限は、利用者の集約の鍵の下で書き込み経路が書いた後に確かめる規則として決定の記録に列挙する。

```sql
CREATE TABLE users (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
CREATE TABLE user_emails (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id),
  email VARCHAR(254) NOT NULL UNIQUE
);
```

注文が利用者と組織を別々に参照すると、利用者がその組織の一員として注文したことを外部キーが表さず、所属していない組織での注文も拒めない。

```sql
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id),
  organization_id BIGINT NOT NULL REFERENCES organizations (id)
);
```

注文は、それが成り立つ最も内側の期間である所属を参照し、注文の時刻は datastore の既定値で付くので、例では既定値を省く。
所属に付けるロールは、所属とロールが同じ組織に属することを、組織のキーを含む複合外部キーで守る。
ロールの付与は事実として残さない今の値なので、ロールの削除で連鎖して消える。

```sql
CREATE TABLE memberships (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id),
  organization_id BIGINT NOT NULL REFERENCES organizations (id),
  UNIQUE (id, organization_id)
);
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  membership_id BIGINT NOT NULL REFERENCES memberships (id),
  occurred_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE organization_roles (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations (id),
  name VARCHAR(50) NOT NULL,
  UNIQUE (id, organization_id),
  UNIQUE (organization_id, name)
);
CREATE TABLE membership_roles (
  membership_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  organization_id BIGINT NOT NULL,
  PRIMARY KEY (membership_id, role_id),
  FOREIGN KEY (membership_id, organization_id)
    REFERENCES memberships (id, organization_id) ON DELETE CASCADE,
  FOREIGN KEY (role_id, organization_id)
    REFERENCES organization_roles (id, organization_id) ON DELETE CASCADE
);
```
