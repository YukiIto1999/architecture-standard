## 別 datastore の移行を同じ時点で検証して切り替える

### 要求
別 datastore への backfill は、開始前に source の high-water mark と各 record の version を記録し、その時点の consistent snapshot から行う。
旧い正本が backfill の間も更新を受ける場合、destination は version 付きの conditional upsert を使い、新しい live update を古い backfill で上書きしない。
旧い正本が backfill の間も更新を受ける場合、high-water mark より後の変更は、[transaction](../transaction/README.md) が定める migration event の outbox から追随する。
旧い正本への write を backfill の前から止められる場合は、止めている間に backfill、照合、切替を終え、live update の追随を要求しない。
logical canonical representation は、項目名・型・構造のような保存形式だけの差を除き、key の順序と値の normalization を固定し、業務の値と意味を丸めや欠落なしに比べられる形にする。
cutover の completeness gate は、同じ watermark の source と destination について、件数、不変条件、logical canonical representation の checksum を照合する。
移送する保存済みの事実の意味と値の保持は [persistence](../persistence/fact-preserving-migrations.md) の「保存済みの事実を意味と値を保って移行する」に従い、completeness gate の照合をその基準に使う。
cutover barrier は、旧い正本への write を fence して処理中の write を確定し、追随している場合は source の final watermark まで destination を追随させる。
barrier 中の新しい request は、再試行可能な失敗として拒否するか durable queue に保持する。
final completeness gate の通過後に、read と write の routing を原子的な一つの cutover で新しい正本へ切り替える。
final completeness gate または cutover に失敗した場合は read と write の routing を旧い正本へ rollback し、保持した request を旧い正本へ適用してから受付を再開する。
final completeness gate と cutover に成功した場合は保持した request を新しい正本へ適用してから受付を再開する。
無停止を要件としない場合は、barrier を全ての読み書きの停止で実現してよく、routing layer の無停止の実証を要求しない。
無停止を要件とする場合は、routing layer が同等の atomic fence と durable forwarding を実証する。

### 根拠
high-water mark と version がなければ、旧い正本が更新を受ける間の backfill と live update の前後関係を判定できない。
同じ watermark の canonical representation を照合すれば、保存形式の物理差を除いた意味と値の一致を判定できる。
write を fence して final watermark まで追随させれば、検証後に旧い正本へだけ確定する write を残さない。
旧い正本への write を止めて移送すれば、live update がなく、追随と conditional upsert を要さずに、止めた時点の内容を一度に照合できる。
read と write を一つの cutover で切り替えれば、新旧を別々の正本として使う期間を作らない。

### 完了条件
backfill が、記録済みの high-water mark の consistent snapshot と record version を使っている。
旧い正本が backfill の間も更新を受ける場合に、destination の conditional upsert が、古い version による上書きを拒否している。
logical canonical representation に、除外する保存形式の差、key の順序、値の normalization が定められ、業務の値と意味を丸めや欠落なしに比べている。
件数、不変条件、checksum が、同じ watermark の source と destination で一致している。
別 datastore の cutover では、write fence、追随する場合の final watermark までの追随、final completeness gate、read と write の原子的な切替の順が守られている。
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
旧い正本が backfill の間も更新を受ける場合は、destination へ version 付き conditional upsert で書き、outbox を high-water mark より後へ追随させる。
旧い正本の write を止めて backfill する場合は、止めている間に backfill と照合を終える。
保存形式の差を除いた logical canonical representation を定め、key 順序と値の normalization を固定する。
cutover 時は旧い write を fence し、処理中の write の確定後に final watermark を記録して、追随している場合は outbox をそこまで drain する。
同じ final watermark で件数、不変条件、checksum を照合し、通過後に read と write の routing を原子的に切り替える。
final completeness gate または cutover の失敗時は旧い routing へ rollback し、両方の成功時は新しい routing を維持して、それぞれ保持した request の適用後に受付を再開する。
新しい正本への昇格を観測してから、旧い write と経路を削除する。
