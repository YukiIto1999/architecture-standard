# persistence

## 概要
persistence は、永続データの設計を全系で統べる規律である。
principles の [data](../principles/data.md) が定める事実の追記と整合性の所在を、関係と制約による永続データの設計として具象化する。
persistence は静止した関係と制約を扱い、書き込みパスの動的な確定は [transaction](./transaction.md) が扱う。
永続化と一時データの実現に用いる store は単一とし、採用は [tools/platforms](../tools/platforms.md) が定める。

## 事実・状態・時間を別の関係に落とす

### 要求
データは [data](../principles/data.md) の分類に従って関係へ落とし、現在の値だけの表に履歴や発生時刻を潰さない。
イベントは追記される関係に、リソースは不変の関係に、現在状態はイベントから導ける形に割り当てる。
実世界で真である時刻と記録した時刻は、別のカラムとして持つ。

### 根拠
分類の見分け方は [data](../principles/data.md) に従う。
イベントとリソースを別の関係に分ければ、リソースは不変に保たれ、状態の変化は行の追記だけで表せる。
実世界の時刻と記録した時刻を同じカラムへ混ぜると、集計が狂う。

### 完了条件
分類の異なるデータが、別の関係または別のカラムに分かれている。
リソースの状態の違いが、削除フラグでなく状態を表すイベントの関係で表されている。
実世界の時刻と記録した時刻の両方を持つ対象は、それぞれ別のカラムに保存されている。

### 禁止事項
リソースの更新日時や削除フラグに、状態を表す別の関係の代わりをさせること。
実世界の時刻と記録した時刻を、同じカラムへ混ぜること。

### 行動
対象データを [data](../principles/data.md) の分類に照らして見分け、分類ごとに別の関係へ落とす。
更新日時や削除フラグを足したくなったら、裏のイベントを別の関係へ切り出す。

### 例

現在状態だけを持ち、削除フラグで状態を上書きすると、退会という事実とその時刻が失われる。

```sql
users(id, name, is_deleted)
```

リソースの変わらない事実と、状態を変えた出来事を別の関係へ記録する。

```sql
users(id, name)
user_withdrawals(user_id, withdrawn_at)
```

## 事実を追記する形で残す

### 要求
状態の遷移は、状態カラムの上書きでなく、遷移を行として追記する関係で表す。
追記が続く関係では、一定の区切りで確定した値を別の関係に記録する。
現在状態は、最新の区切りの行を起点に、それ以降の事実だけで導く。
区切りより前の履歴は、削除せず別の保管へ分離してよい。
現在状態を読み取りのために実体化する場合、その関係の名前は `<対象>_current` とし、対象ごとに一つの関係にする。
`<対象>_current` は事実から導出した控えであり、区切りの確定を追記する関係とは別に扱う。
事実を追記する関係の名前は出来事を表す名詞とし、情報・データ・履歴・管理・マスタ・記録という語を避ける。

### 根拠
事実を追記で残し現在状態を事実から導く理由は [data](../principles/data.md) に従う。
状態カラムは最新の値だけを持つので、遷移を行として追記する関係にすれば、関係の形そのものが上書きを防ぐ。
区切りの確定値を元の関係と別の関係に持たせれば、現在状態を導く問い合わせは最新の区切りの行から先の事実だけを読む形に閉じる。
区切りより前の関係を別の保管へ移せば、日常の問い合わせが読む範囲を保ったまま、事実そのものは失わずに残せる。
曖昧な語は関係の中身を説明せず、名前から事実と現在状態の区別を読み取れなくする。

### 完了条件
状態の遷移が、行として追記される関係で表されている。
追記が続く関係で、現在状態の導出が最新の区切りの行から先の事実に限られている。
区切りの確定値が、元の関係と別の関係に記録されている。
区切りより前の履歴を分離した場合、削除でなく分離先の保管に残っている。
実体化した現在状態の関係の名前が `<対象>_current` であり、対象ごとに一つで、区切りの関係と分かれている。
事実を追記する関係の名前が出来事を表す名詞であり、情報・データ・履歴・管理・マスタ・記録という語を含んでいない。

### 禁止事項
状態の遷移を、状態カラムの上書きで表すこと。
追記が続く関係で、毎回すべての履歴を読んで現在状態を導くこと。
区切りより前の事実を、削除して失うこと。
現在状態を導く関係や事実を追記する関係の名前に、意味を伝えない語を使うこと。

### 行動
状態カラムを見たら、その遷移を行として追記する関係へ切り出すか判断する。
追記が続く関係を見たら、現在状態の導出が全履歴の読み出しになっていないか確かめる。
なっていれば、区切りの確定値を別の関係に記録し、最新の区切りの行を起点に導出を限る。
日常の問い合わせから古い期間の事実を分ける必要がある場合は、削除せず別の保管へ分離する。
現在状態を導く関係と事実を追記する関係の名前を、この規律に沿って付け直す。

### 例

状態を上書きすると、過去にその状態へ遷移した事実が失われる。

```sql
orders(id, status)
```

状態の変化を事実として追記し、現在状態は最新の事実から導く。

```sql
orders(id)
order_status_events(order_id, status, occurred_at)
```

残高を毎回すべての履歴から導くと、履歴が伸びるほど読み出しが重くなる。

```sql
point_events(user_id, delta, occurred_at)
```

区切りごとの確定残高を事実として追記し、最新の区切りより後だけを導出対象にする。現在状態を実体化する場合は、正本ではない導出値として別の関係へ置く。古い期間のイベントは削除せず、別の保管へ分離する。

```sql
point_closings(user_id, balance, closed_at)
point_balance_current(user_id, balance, version)
```

## 正規化して一つの事実を一箇所に置く

### 要求
関係を正規化し、一つの事実に一つの正本を持たせる。
独立に問い合わせまたは更新する複数の属性は、意味ごとに別の列へ置く。
単一の不可分な value または document として同じ lifecycle で一体に検証し、一体に読み書きする値は、JSON の一列に置いてよい。
他の列や他の表から導出できる値を、別の列として重ねて持たない。
導出値を独立に保存してよいのは、失っても事実が残る技術的な控えだけである。

### 根拠
正規化の理由は [data](../principles/data.md) に従う。
同じ事実に複数の正本を持たせると、参照する経路によって異なる値を読む危険が生まれる。
独立に問い合わせまたは更新する属性を一つの不透明な列へ押し込むと、属性ごとの型と制約をデータ層で表せない。
単一の不可分な value または document は、属性を独立に扱わないため、一列に置いても更新単位と lifecycle がずれない。
導出できる値を独立した列として持たせると、元の値との整合を保つ処理を書き手が担うことになる。

### 完了条件
一つの事実の正本が、一箇所だけに存在する。
独立に問い合わせまたは更新する複数の属性が、意味ごとに別の列へ置かれている。
JSON の一列に置く値が、単一の不可分な value または document として一体に検証され、一体に読み書きされている。
技術的な控えでない導出値が、独立した列として保存されていない。

### 禁止事項
参照先の表が持つ値を、参照元の表へ複製して持つこと。
独立に問い合わせまたは更新する複数の属性を、不透明な一列へ押し込むこと。
異なる lifecycle を持つ属性を、一つの JSON document として扱うこと。
技術的な控えでない導出値を、独立した列として保存すること。

### 行動
各事実の正本を特定し、複数の正本があれば一箇所へ統合する。
一つの不透明な列にある属性が、独立に問い合わせまたは更新されるかを確認する。
独立に扱う属性は意味ごとの列へ分ける。
一体に検証し一体に読み書きする不可分な value または document は、JSON の一列に保ってよい。
表の列を洗い出し、他の表や他の列から導出できるものを特定する。
導出できる列を削り、参照または計算に置き換える。

### 例

顧客名を注文へ複製し、金額と通貨を一つの列へ入れると、一つの事実が複数箇所に存在し、異なる意味の値が混ざる。

```sql
orders(id, customer_id, customer_name, total_text)
```

顧客名の正本を一箇所に置き、金額と通貨を意味ごとの列へ分ける。

```sql
customers(id, name)
orders(id, customer_id REFERENCES customers(id), amount, currency)
```

署名済み文書を常に一体として検証し、読み書きする場合は、不可分な document として一列に置いてよい。

```sql
signed_documents(id, body_json)
```

## 関係の意図を制約で表す

### 要求
整合性はアプリケーションの規約でなくデータ層の制約で守り、外部キー・一意・NOT NULL・検査で関係の意図を表す。
任意の項目は本体の nullable でなく、値があるときだけ行が存在する別の関係に切り出す。

### 根拠
データ層の制約で守る理由は [data](../principles/data.md) に従う。
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

## 物理の最適化は計測した根拠で行う

### 要求
索引・分割・非正規化・属性値の縦持ちと、独立した属性をまとめる JSON 列は物理の最適化であり、計測した根拠があるときだけ行う。
最適化として JSON 列を置く場合は、schema と version を持たせる。
頻繁に独立して検索、更新、制約するデータを、JSON 列や属性値の縦持ちで表さない。
派生した JSON 列は、正本から再構築できるようにする。
検索や分析のための二次の読みモデルも採用済み datastore の projection とし、正本から再構築できる派生として置いて正本にしない。

### 根拠
物理の最適化は論理設計を歪め、非正規化や独立した属性をまとめる JSON 列は更新時の異常と検索の不能を招く。
計測した根拠なしに入れると、得るものなく整合性と検索性を失う。
JSON 内部の属性には、関係の列へ置く型・NOT NULL・外部キー・通常の列索引をそのまま適用できず、属性ごとの検査式と式索引が別途必要になる。
頻繁に独立して検索、更新、制約するデータを JSON 列や縦持ちにすると、論理上の属性と関係スキーマの制約単位がずれる。
JSON の schema と version がなければ、保存した document の解釈と移行方法を判定できない。
派生した JSON 列を再構築できなければ、派生が壊れたときに正本から回復できない。

### 完了条件
索引、非正規化、縦持ちと、最適化として置いた JSON 列が、計測した根拠に基づいている。
最適化として置いた JSON 列が、schema と version を持っている。
頻繁に独立して検索、更新、制約するデータが、JSON 列や縦持ちでなく正規化された関係で表されている。
派生した JSON 列が、正本から再構築できる。
二次の読みモデルが、正本から再構築でき、正本になっていない。

### 禁止事項
計測した根拠なく、非正規化や最適化目的の JSON 列を入れること。
最適化として置く JSON 列に、schema または version を持たせないこと。
頻繁に独立して検索、更新、制約するデータを、JSON 列や属性値の縦持ちで表すこと。
派生した JSON 列を、正本から再構築できない形にすること。
二次の読みモデルを正本として扱い、正本から作り直せない形にすること。

### 行動
JSON 列が単一の不可分な value または document か、独立した属性をまとめる最適化かを判定する。
独立した属性をまとめる JSON 列は、検索、更新、制約の要否を確認し、必要なら正規化する。
最適化は、計測の後にだけ行う。
最適化として残す JSON 列には schema と version を持たせる。
派生した JSON 列は、正本から再構築する手順を検証する。
二次の読みモデルは採用済み datastore の projection に置き、失っても正本から作り直せる形に保つ。

## 稼働中のスキーマを拡張・移行・収縮の段で進化させる

### 要求
稼働中の関係に互換を保てない変更を加えるときは、新しい構造を加える段、新旧の構造へ両方とも反映して既存データを移す段、旧い構造を落とす段の三段に分ける。
読み出しを新しい構造へ切り替える段より前は、いつでも旧い構造へ戻せる状態を保つ。
拡張の段で加える列や表は、移行が終わるまでの一時的なものであり、任意項目として恒久的に残さない。

### 根拠
段階に分ける理由と拡張・移行・収縮という一般の形は [evolution](../principles/evolution.md) に従い、ここでは関係の変更として具象化する。
稼働中の関係を一度で置き換えると、新しい構造しか読めない実行中のコードと、旧い構造しか書かない実行中のコードが同時に存在する間、どちらかが失敗する。
新しい構造を先に加えて両方へ反映すれば、新旧のコードが並行して動き続けられる。
読み出しを新しい構造へ切り替えた後は、旧い構造だけに残る更新が届いても現在状態に反映されなくなるため、そこから先は戻れない。
参照が消えたことを確かめてから旧い構造を落とせば、両立の期間を必要最小限に閉じられる。
拡張で加えた列を任意項目のまま恒久的に残すと、移行が終わったのかを判別できず、収縮の段が永遠に来ない。

### 完了条件
互換を保てない変更が、追加・移行・除去の三段の順で進められている。
読み出しの切り替えより前の各段で、旧い構造への後戻りができる。
旧い構造の除去が、読み出しの切り替えと参照の消滅を確かめた後に行われている。
拡張の段で加えた列や表が、移行の完了後に除去されているか、恒久の構造として制約を備え直されている。

### 禁止事項
稼働中の関係の構造を、三段を経ずに一度で置き換えること。
旧い構造を、参照が残っている間に落とすこと。
拡張の段の列を、任意項目として恒久的に残すこと。

### 行動
互換を保てない変更を見つけたら、新しい構造を一時的な nullable として加え、旧い構造と併存させる。
新旧どちらの書き込みも新しい構造に反映されることを確かめてから、読み出しを新しい構造へ切り替える。
参照が消えたことを確認し、旧い構造を落とす。
適用の手段と配備から分離した順序は [process/migration](../process/migration.md) が定める。

### 例

稼働中に列の型を一度で変えると、変換できない既存値が失われるか、旧版のコードによる書き込みが失敗する。

```sql
ALTER TABLE payments ALTER COLUMN amount TYPE integer;
```

拡張では、新しい型の列を一時的に nullable として加え、古い列と併存させる。

```sql
ALTER TABLE payments ADD COLUMN amount_minor_unit integer;
```

移行では新旧両方の列へ書き込み、既存行を変換する。

```sql
UPDATE payments SET amount_minor_unit = round(amount * 100) WHERE amount_minor_unit IS NULL;
```

読み出しを新しい列へ切り替えた後、収縮で古い列を削除する。

```sql
ALTER TABLE payments DROP COLUMN amount;
```

## 別 datastore の移行を同じ時点で検証して切り替える

### 要求
別 datastore への backfill は、開始前に source の high-water mark と各 record の version を記録し、その時点の consistent snapshot から行う。
destination は version 付きの conditional upsert を使い、新しい live update を古い backfill で上書きしない。
high-water mark より後の変更は、[transaction](./transaction.md) が定める migration event の outbox から追随する。
logical canonical representation は、schema だけの差を除き、key の順序と値の normalization を固定する。
cutover の completeness gate は、同じ watermark の source と destination について、件数、不変条件、logical canonical representation の checksum を照合する。
cutover barrier は、旧い正本への write を fence して処理中の write を確定し、source の final watermark まで destination を追随させる。
barrier 中の新しい request は、再試行可能な失敗として拒否するか durable queue に保持する。
final completeness gate の通過後に、read と write の routing を原子的な一つの cutover で新しい正本へ切り替える。
final completeness gate または cutover に失敗した場合は read と write の routing を旧い正本へ rollback し、保持した request を旧い正本へ適用してから受付を再開する。
final completeness gate と cutover に成功した場合は保持した request を新しい正本へ適用してから受付を再開する。
無停止を要件とする場合は、routing layer が同等の atomic fence と durable forwarding を実証する。

### 根拠
high-water mark と version がなければ、backfill と live update の前後関係を判定できない。
同じ watermark の canonical representation を照合すれば、schema の物理差を除いた内容の一致を判定できる。
write を fence して final watermark まで追随させれば、検証後に旧い正本へだけ確定する write を残さない。
read と write を一つの cutover で切り替えれば、新旧を別々の正本として使う期間を作らない。

### 完了条件
backfill が、記録済みの high-water mark の consistent snapshot と record version を使っている。
destination の conditional upsert が、古い version による上書きを拒否している。
logical canonical representation に、除外する schema 差、key の順序、値の normalization が定められている。
件数、不変条件、checksum が、同じ watermark の source と destination で一致している。
別 datastore の cutover では、write fence、final watermark までの追随、final completeness gate、read と write の原子的な切替の順が守られている。
final completeness gate と cutover の成否に応じて、保持した request が一方の正本だけへ適用された後に受付が再開されている。
新しい正本への昇格後にだけ、旧い正本への write と旧い経路が削除されている。
無停止の移行では、routing layer の atomic fence と durable forwarding が同じ性質を満たすことが実証されている。

### 禁止事項
record version を持たずに、live update と backfill を同じ destination へ書くこと。
異なる watermark の source と destination を、completeness gate で比較すること。
logical canonical representation の key 順序または値の normalization を、実装ごとの暗黙の挙動へ委ねること。
旧い正本への write を fence せずに、final completeness gate と cutover を行うこと。
read と write の routing を、別々の cutover で切り替えること。
final completeness gate または cutover の失敗後に、旧い routing への rollback が終わる前に write 受付を再開すること。
新しい正本への昇格前に、旧い正本への write または旧い経路を削除すること。

### 行動
source の high-water mark と record version を記録し、consistent snapshot から backfill する。
destination へ version 付き conditional upsert で書き、outbox を high-water mark より後へ追随させる。
schema 差を除いた logical canonical representation を定め、key 順序と値の normalization を固定する。
cutover 時は旧い write を fence し、処理中の write の確定後に final watermark を記録して、outbox をそこまで drain する。
同じ final watermark で件数、不変条件、checksum を照合し、通過後に read と write の routing を原子的に切り替える。
final completeness gate または cutover の失敗時は旧い routing へ rollback し、両方の成功時は新しい routing を維持して、それぞれ保持した request の適用後に受付を再開する。
新しい正本への昇格を観測してから、旧い write と経路を削除する。

## store を単一に採用する

### 要求
永続化する事実の正本の datastore は、単一とする。
キャッシュと一時データの store は、単一とし、一時データの store を採用の外に増やさない。
datastore と一時データの store の採用は、[tools/platforms](../tools/platforms.md) が定める。
cache は正本の代わりにせず、cache-aside で読み書きし、各項目を期限で失効させて対象を特定して無効化する。
HTTP の CDN と edge cache は応答の配送だけに使い、アプリケーションの状態または一時データの store にしない。

### 根拠
datastore と一時データの store を project ごとに選び直すと、選定と運用の知識が分散し、置き換えの決定が単一の場所で完結しなくなる。
単一の datastore と単一の一時 store の採用を tools に固定すれば、採用を変える決定は一箇所の編集で済む。
一時データの store を増やすと、失効・整合・運用の手順がストアの数だけ増える。
cache-aside と期限と対象別の無効化を固定すれば、cache の欠落を正本の欠落にせず、古い値の残存範囲を閉じられる。
HTTP の配送 cache とアプリケーションの状態を分ければ、配信経路を正本や共有状態と誤認しない。

### 完了条件
事実の正本の datastore が、単一であり、tools の採用と一致している。
キャッシュと一時データの store が、単一であり、tools の採用と一致している。
一時データの store が、採用の外に増えていない。
cache の項目が期限で失効し、対象別に無効化され、cache の欠落時に正本から取得されている。
CDN と edge cache が HTTP 応答の配送だけに使われ、アプリケーションの状態を保持していない。

### 禁止事項
事実の正本の datastore を、project ごとに異なる製品へ置き換えること。
一時データの store を、採用の外に増やすこと。
cache を正本として扱うこと、期限または対象別の無効化を持たないこと。
CDN または edge cache を、アプリケーションの状態または一時データの store として使うこと。

### 行動
永続化と一時データの置き場を洗い出し、事実の正本と一時データを tools の採用へ統一する。
新たな一時 store の追加を提案されたら、既存の採用で満たせないかを先に確かめる。
cache は cache-aside で配置し、項目の期限と対象別の無効化を定める。
CDN と edge cache は HTTP 応答の配送だけに限定する。

## 参照
データの原則は [data](../principles/data.md)、論理設計と物理設計の分離は [modeling](../principles/modeling.md)、書き込みパスの一貫性は [transaction](./transaction.md) に従う。
永続化の置き場は [structure/core/infrastructure](../structure/core/infrastructure.md)、言語別の実現は [languages](../languages/) が定める。
