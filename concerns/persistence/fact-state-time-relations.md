## 事実・状態・時間を別の関係に落とす

### 要求
データは [data](../../principles/data/fact-state-time.md) の分類に従い、種類ごとに別の関係へ落とす。
親リソースは、不変の識別子と生成時に決まる不変の属性だけを持つ関係として置き、他の関係はその識別子を外部キーで参照する。
現在有効な状態と所属は、現在関係の行として直接保持し、その行の有無と値を正本にする。
現在関係の変化は、行の挿入、更新、削除で表し、業務事実の関係から読み出しのたびに組み立てない。
契約が保持を求める出来事だけを、現在関係とは別の関係へ業務事実として追記する。
停止、退会、消去、復帰、再参加の遷移ごとに、現在関係をどう変えるか、反復を許すか、取消を許すかを定義し、一つの削除操作へまとめない。
実世界で真である時刻と記録した時刻の両方を契約が求める対象では、別のカラムとして持つ。

### 根拠
現在有効な状態と所属は、いま成り立つ命題であり、出来事を畳み込んだ結果として読む必要はない。
現在関係を正本にすれば、現在の所属は一つの問い合わせで読め、業務事実を期限で消しても現在の状態は失われない。
参加と脱退を繰り返せる業務で、出来事の有無の組み合わせから所属を読むと、一回目の参加と脱退が二回目の判定を狂わせる。
現在関係はいま成り立つことに、業務事実は過去に起きたことに答えるため、同じ関係へ混ぜると更新の規則と保持の規則が衝突する。
退会、停止、消去は、現在関係への作用、復帰できるか、個人データを消す義務の有無が違う。
一つの削除操作や一回限りの出来事にまとめると、ある遷移の都合が別の遷移の保持と消去を決めてしまう。
実世界の時刻と記録した時刻を同じカラムへ混ぜると、集計が狂う。

### 完了条件
親リソースの関係が、不変の識別子と生成時の不変の属性だけを持ち、他の関係がその識別子を参照している。
現在有効な状態と所属が、現在関係の行として保持され、業務事実の関係を読まずに判定できる。
現在関係と業務事実が、別の関係に分かれている。
停止、退会、消去、復帰、再参加の各遷移について、現在関係への作用、追記する業務事実、繰り返し発生できるか、取り消せるかが、project の決定の記録の遷移表に定められている。
繰り返し発生できる出来事の業務事実の関係が、同じ対象への二回目以降の追記を受け入れる主キーを持つ。
実世界の時刻と記録した時刻が別のカラムであることの判定は、[data](../../principles/data/fact-state-time.md) の完了条件に従う。

### 禁止事項
現在有効な状態と所属の正本を業務事実の関係だけに置き、出来事の有無や最新の行から毎回導くこと。
繰り返し発生できる出来事の業務事実の関係に、対象の識別子だけの主キーや一意制約を置き、二回目の追記を拒むこと。
遷移ごとの定めを持たない一つの削除操作で、停止、退会、消去を処理すること。
隠れた業務事実を更新日時や削除フラグで覆い隠す禁止は、[data](../../principles/data/fact-state-time.md) の禁止事項に従う。
契約が両方を求める実世界の時刻と記録した時刻を、一つのカラムで兼ねること。

### 行動
対象データを [data](../../principles/data/fact-state-time.md) の分類に照らして、親リソース、現在関係、可変属性、業務事実へ見分ける。
現在有効な状態と所属を、現在関係の行として定める。
契約が保持を求める出来事だけを業務事実の関係へ切り出し、求めない変更は現在関係の更新と削除で扱う。
遷移ごとに、現在関係への作用、追記する業務事実、繰り返し発生できるか、取り消せるかを遷移表へ書き出す。
繰り返し発生できる出来事は、出来事ごとの代理キーを主キーにする。
更新日時や削除フラグを足したくなったら、隠れた出来事が契約の保持対象かを確かめ、対象なら業務事実へ切り出す。

### 例

削除フラグで退会を表すと、退会という出来事も時刻も残らず、フラグを立てても氏名が消えない。

```sql
CREATE TABLE users (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  display_name VARCHAR(100) NOT NULL,
  is_deleted BOOLEAN NOT NULL
);
```

親リソースは識別子だけを持ち、有効なアカウントを現在関係に、プロフィール、メールアドレス、認証情報を現在関係へ従属する属性に、登録と退会を業務事実に分ける。
この例では複数のメールを登録でき、プロフィールの変更、メールの追加と解除、認証情報の更新は異なる契機で起きる。
登録と退会の発生時刻の保持を契約が求め、記録時刻は求めない。
退会は同じ識別子について一度だけ起き、再登録には別の識別子を発行する。

```sql
CREATE TABLE users (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
CREATE TABLE active_users (
  user_id BIGINT PRIMARY KEY REFERENCES users (id)
);
CREATE TABLE user_profiles (
  user_id BIGINT PRIMARY KEY REFERENCES active_users (user_id) ON DELETE CASCADE,
  display_name VARCHAR(100) NOT NULL
);
CREATE TABLE user_emails (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES active_users (user_id) ON DELETE CASCADE,
  email VARCHAR(254) NOT NULL UNIQUE
);
CREATE TABLE user_credentials (
  user_id BIGINT PRIMARY KEY REFERENCES active_users (user_id) ON DELETE CASCADE,
  password_hash VARCHAR(255) NOT NULL
);
CREATE TABLE user_registrations (
  user_id BIGINT PRIMARY KEY REFERENCES users (id),
  registered_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE user_withdrawals (
  user_id BIGINT PRIMARY KEY REFERENCES users (id),
  withdrawn_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE RESTRICT
);
```

`user_withdrawals` の主キーが `user_id` だけであることは、退会が一回限りという前提の表現である。
`active_users` と `user_withdrawals` に同じ利用者が同時に存在しないことは、外部キーでは守れず、[relational-constraints](./relational-constraints.md) の「関係の意図を制約で表す」と [transaction](../transaction/single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従って守る。
`user_registrations` は、利用者の識別子と登録が起きた時刻だけを持ち、プロフィール、メールアドレス、認証情報を写さない。
登録イベントの保持は契約が求める場合に限り、親リソースの不変性を表すためだけには設けない。
登録時は親リソース、現在関係、必要な属性、登録の業務事実を一つのトランザクションで作り、現在の有効性は `active_users` の行で判定する。
属性の更新では現在値を変え、登録イベントは更新しない。
退会時は現在関係と従属する属性を消すが、保持が必要な登録と退会の事実および注文は、親リソースを参照して残る。

参加と脱退を繰り返せ、その履歴を契約が求める業務で、参加の業務事実を対象の組で一意にすると、再参加を追記できない。

```sql
CREATE TABLE membership_joins (
  user_id BIGINT NOT NULL REFERENCES users (id),
  organization_id BIGINT NOT NULL REFERENCES organizations (id),
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL,
  PRIMARY KEY (user_id, organization_id)
);
```

現在の所属は現在関係の主キーで一意にし、参加は出来事ごとの代理キーで繰り返し追記する。
脱退も同じ形の業務事実として追記する。

```sql
CREATE TABLE memberships (
  user_id BIGINT NOT NULL REFERENCES active_users (user_id) ON DELETE RESTRICT,
  organization_id BIGINT NOT NULL REFERENCES organizations (id),
  role VARCHAR(20) NOT NULL,
  PRIMARY KEY (user_id, organization_id)
);
CREATE TABLE membership_joins (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users (id),
  organization_id BIGINT NOT NULL REFERENCES organizations (id),
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL
);
```

組織の所属は組織の集約が所有するため、アカウントの退会から連鎖削除しない。
退会の workflow は各組織の書き込みパスで所属を解除し、管理者の存続などの条件を検証してから、アカウントを退会させる。
所属が残る間は外部キーが現在関係の削除を拒むため、組織の不変条件を迂回した退会は確定しない。
