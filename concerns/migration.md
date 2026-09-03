# migration

## 概要
migration は、稼働中の系を別の形へ移す過程を全系で統べる規律である。
principles の [evolution](../principles/evolution.md) が定める段階的で可逆な段と収縮までの波及を、稼働中のデータと正本を移す作業として具象化する。
migration は移行の段と切替の判定を扱い、静止した関係と制約は [persistence](./persistence.md)、書き込みパスの確定点は [transaction](./transaction.md) が扱う。

## 稼働中のスキーマを拡張・移行・収縮の段で進化させる

### 要求
稼働中の関係に互換を保てない変更を加えるときは、新しい構造を加える段、新旧の構造へ両方とも反映して既存データを移す段、旧い構造を落とす段の三段に分ける。
読み出しを新しい構造へ切り替える段より前は、いつでも旧い構造へ戻せる状態を保つ。
拡張の段で加える列や表は、移行が終わるまでの一時的なものであり、任意項目として恒久的に残さない。
schema migration は forward-only の artifact とし、戻す場合も既存 artifact を逆実行せず、新しい forward migration で戻す。
三段の適用対象は、上書きで現在状態を表す稼働中の関係である。
追記した事実の関係の版の進化は [persistence](./persistence.md) に従い、保存済みの行を移行の対象にしない。

### 根拠
段階に分ける理由と拡張・移行・収縮という一般の形は [evolution](../principles/evolution.md) に従い、ここでは関係の変更として具象化する。
稼働中の関係を一度で置き換えると、新しい構造しか読めない実行中のコードと、旧い構造しか書かない実行中のコードが同時に存在する間、どちらかが失敗する。
新しい構造を先に加えて両方へ反映すれば、新旧のコードが並行して動き続けられる。
読み出しを新しい構造へ切り替えた後は、旧い構造だけに残る更新が届いても現在状態に反映されなくなるため、そこから先は戻れない。
参照が消えたことを確かめてから旧い構造を落とせば、両立の期間を必要最小限に閉じられる。
拡張で加えた列を任意項目のまま恒久的に残すと、移行が終わったのかを判別できず、収縮の段が永遠に来ない。

### 完了条件
互換を保てない変更が拡張・移行・収縮の段で進み、収縮まで到達していることの判定は、[evolution](../principles/evolution.md) の完了条件に従う。
読み出しの切り替えより前の各段で、旧い構造への後戻りができる。
旧い構造を落とす収縮の段が、読み出しの切り替えと参照の消滅を確かめた後に行われている。
拡張の段で加えた列や表が、収縮の段で落とされているか、恒久の構造として制約を備え直されている。

### 禁止事項
稼働中の関係の構造を三段を経ずに一度で置き換える禁止は、[evolution](../principles/evolution.md) の禁止事項に従う。
旧い構造を、参照が残っている間に落とすこと。
拡張の段の列を、任意項目として恒久的に残すこと。
追記した事実の関係の保存済みの行を、三段の移行の対象にすること。

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

## 参照
段階的で可逆な変更は [evolution](../principles/evolution.md)、関係と制約の設計は [persistence](./persistence.md)、migration event の確定点は [transaction](./transaction.md) に従う。
移行の順序と確認点は [process/migration](../process/migration.md) が定める。
