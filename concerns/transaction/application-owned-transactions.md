## トランザクションの制御を application に置く

### 要求
application の use-case は、同時に確定する変更と事実の範囲、判断に必要な読み、確定条件を所有し、transaction の開始、必要な読み、domain の純粋な判断、書き込み、確定または中止を、遅延した効果の記述として組む。
確定の範囲は、業務動作の同時の確定の要求から use-case が決め、一つの domain モデル、一つの table、一つのコンテキストの単位に機械的に合わせない。
use-case が複数の domain モデルの判断を要するときは、各モデルの純粋な関数を呼んで結果を組み、必要な書き込みを同じ確定に含める。
他のコンテキストの状態変更を同じ確定に含める use-case は、その状態変更を、他のコンテキストが公開する参加操作として自分の port を通して組み、開始・確定・中止を自分が制御する。
参加操作は、確定を所有する use-case と同じ確定の抽象を要求する依存として受け取り、判断と書き込みの効果を遅延した記述として組むだけで、transaction の開始・確定・中止も実行も持たない。
参加操作は単独の確定を持たず、独立して確定する別の use-case を外側から包んで同時の確定に見せない。
参加を含む確定の競合制御は [single-write-path](./single-write-path.md) の「整合性を一つの書き込みパスに閉じる」に従い、参加操作の拒否・競合・失敗では、確定を始めずに全体を中止する。
use-case は、application が宣言した transaction の scope の抽象を通して、開始・読み・書き込み・確定・中止の効果を組み、DB を直接実行しない。
use-case は、driver の transaction 型を受け取らず、名指しもしない。
domain は、不変条件・遷移・拒否の判断だけを持つ通常の純粋な値と関数に保ち、transaction を受け取らない。
判断の結果に基づいて確定するか中止するかの制御は、domain でなく use-case が持つ。
infrastructure は、scope の抽象を実装し、driver の具体的な開始・確定・中止と型変換を原始効果として実装の内側に閉じる。
store は、scope の中で読み書きし、独立して transaction を開始も確定もしない。
composition は、scope の抽象に実装を結ぶ配線だけを持ち、transaction を開始も確定もしない。
効果の記述の構築と実行の分離は [effect](../effect/deferred-effect-descriptions.md) の「効果を遅延した記述にして端で実行する」に従い、transaction の開始・読み・書き込み・確定を構築では実行せず、runtime が境界で実行する。
効果の記述を実行する runtime は、記述を駆動するだけで、記述に含まれる transaction の制御を所有しない。
確定するか中止するかの条件と確定の結果の分類は use-case が持ち、use-case の外の機構の既定の動作(成功なら確定する、失敗なら中止するなど)へ移さない。
scope の取得と解放を束ねる効果の合成は、確定を行わず、確定していない scope の中止と解放だけを担う。
一度の確定に含める内容は、[state-event-atomicity](./state-event-atomicity.md) の「状態とイベントを同一パスで記録する」、[scoped-idempotency-keys](./scoped-idempotency-keys.md) の「冪等にして再実行できるようにする」、[workflow](../workflow/resumable-progress.md) の「進行の状態を持ち、停止から再開する」に従い、use-case が必要なものを同じ transaction へ書いてから確定する。
scope の操作の失敗は、use-case が分岐に使う分類の閉じた型で表し、driver のエラーの値と文字列を業務の失敗に載せない。
driver の生の診断情報は、infrastructure が [observability](../observability/README.md) の境界の殻で扱う。
確定を始める前に、拒否、競合、失敗、欠陥、取り消しで終わるときは、確定を始めずに scope を中止する。
取り消された後も、scope の中止は取り消されない後始末として完了まで行う。
中止が失敗しても、元の終わりを保ち、中止の失敗を別に観測できるようにする。
中止の失敗の扱いは、[effect](../effect/cancellation-resource-safety.md) の「取り消しと資源を言語の機構に委ねる」に従う。
確定の結果は、成功の応答で確かめた確定、実装が確定していないと確認できた未確定、それ以外の結果不明に分ける。
確定していないと確認できない失敗は、エラーの種類だけで未確定とせず、結果不明として返す。
確定の呼び出しを始めた後に結果が分からなくなる場合は、原因が取り消しでも、取り消しでなく結果不明として返す。
確定を確認した後の後始末の失敗は、確定済みの結果を変えず、後始末の失敗として別に観測できるようにする。
結果不明は、[invisible-partial-commits](./invisible-partial-commits.md) の「部分確定を不可視にする」に従い、再実行か調査で判定できるようにする。

### 根拠
transaction は、一つの業務動作をどこまで一度に確定するかの決定であり、その単位は use-case が持つ。
確定の範囲は業務動作の同時の確定の要求が決めるので、domain モデルや table やコンテキストの数とは一致するとは限らず、複数のモデルを一度に確定する use-case もある。
複数のモデルの判断を application が組んで一度に確定すれば、責務の異なるモデルを一つへ統合せず、別の確定のイベントにも分けずに、同時に確定する要件を満たせる。
コンテキストは語彙と意味の境界であり確定の範囲とは別なので、同時に確定すべき業務動作が複数のコンテキストの状態を変えるときも、コンテキストを統合せず、非同期にも分けずに、参加操作を同じ確定へ含めれば満たせる。
参加する側が自分で確定すると確定点が割れ、途中で止まったときに一部だけが残る。
独立して確定する別の use-case を外側から包むと、各 use-case が確定条件を持つので、確定が割れるか二重になる。
use-case が開始から確定または中止までを効果の記述として組めば、読み、domain の判断、書き込み、確定か中止かの分岐が、一つの手順として読める。
効果の記述は構築では何も実行しない値なので、合成し、差し替え、構築だけを検査でき、実行と資源の解放の位置が runtime の境界に集まる。
domain が transaction の読み書きや確定を呼ぶと、判断に外部効果が混ざるため、状態と入力から判断を返す純粋な関数でなくなる。
infrastructure は外部依存の接続を管理する層であり、業務動作の確定の単位を知らない。
store が独立に確定すると、一つの use-case の書き込みが複数の確定点に割れ、途中で止まったときに一部だけが残る。
composition が配線だけを持てば、業務の手順を知らずに済む。
確定するかの既定の動作を use-case の外の機構へ移すと、判断の結果に応じた中止や競合の扱いと確定の結果の分類を use-case が書けず、確定しない終わり方が use-case から見えなくなる。
scope の取得と解放を束ねる効果の合成は、確定の条件を決めずに資源の寿命だけを閉じるので、確定条件の所有を application から動かさない。
関数を受け取る形かどうかではなく、確定条件の所有と実行の位置で判断する。
効果の記述を runtime が駆動することは記述を進めることであり、記述の中でいつ確定するかを決めることではない。
scope を抽象にすれば、application と domain が driver の型に依存しない。
driver のエラーを業務の失敗へ文字列化すると、分類に必要な型情報が失われ、接続情報などの機微な値が漏れる恐れがある。
業務の失敗は、use-case の分岐に必要な意味だけを持てば足りる。
確定を始める前に終わった scope を残すと、開いた transaction と接続と鍵が残るので、取り消された後も中止を完了させる。
中止の失敗で元の終わりを上書きすると、拒否や競合の理由が呼び出し側から消える。
成功の応答は確定を示すが、失敗のエラーの種類だけでは確定していないとは限らない。
確定したとみなせば、確定していない書き込みを成功として公開し、未確定とみなして書き直せば、確定済みの書き込みを重ねる恐れがある。
取り消しとして返せば、呼び出し側は何も書かれていないと誤る。
結果不明のまま返せば、再実行か調査で判定できる。
確定を確認した後の後始末の失敗を未確定へ写せば、確定済みの書き込みを書かれていないものとして扱う。

### 完了条件
transaction の開始、読み、domain の判断、書き込み、確定または中止の順が、application の use-case の効果の記述に書かれている。
use-case が、同時に確定する範囲を業務動作の要求から決め、複数の domain モデルの判断を要するときも、各モデルの純粋な関数の結果を組んで一度の確定に含めている。
他のコンテキストの状態変更を含む use-case が、参加操作を自分の port を通して使い、その書き込みを自分の一度の確定に含めている。
参加操作が、transaction の開始・確定・中止も実行もせず、同じ確定の抽象だけを通して書いている。
参加操作の拒否・競合・失敗を注入すると、確定を所有する use-case の書き込みを含む全ての書き込みが確定していない。
use-case が、scope の抽象だけを通して transaction を制御し、driver の transaction 型を受け取っても名指ししてもいない。
domain が、transaction と scope を受け取らず、判断が純粋な関数のままである。
効果の記述を構築しただけでは、transaction の開始も読みも書き込みも起きず、runtime が実行したときだけ始まる。
driver の具体的な開始・確定・中止が、infrastructure の scope の実装の内側にだけある。
store が、transaction を開始も確定も中止もしていない。
composition が、transaction を開始も確定も中止もしていない。
確定するか中止するかの条件と確定の結果の分類が use-case にあり、use-case の外に、成否から確定か中止かを既定の動作で決める機構が、どの層にもない。
scope の取得と解放を束ねる合成が、確定を行わず、確定していない scope の中止と解放だけを担っている。
一度の確定が、use-case に必要な現在情報、業務事実、outbox、冪等の記録、step の完了記録を同じ transaction に含んでいる。
scope の操作の失敗が、分類の閉じた型で返り、driver のエラーの値と文字列を含んでいない。
確定を始める前に終わる拒否、競合、失敗、欠陥、取り消しの各終わりで、確定した書き込みが一つもない。
取り消された use-case が、開いた transaction を残していない。
中止に失敗を注入すると、元の終わりが保たれ、中止の失敗が別に観測されている。
確定が、成功の応答を得たときだけ確定として返り、未確定を確認できない失敗が結果不明になっている。
確定の応答を失う失敗を注入すると、結果不明として返り、確定にも未確定にも取り消しにも写っていない。
確定を確認した後の後始末に失敗を注入すると、確定済みの結果が保たれ、後始末の失敗が別に観測されている。

### 禁止事項
domain に、transaction の受け取りと、確定や中止の制御を持ち込むこと。
application が、driver の transaction 型を受け取ること、または名指しすること。
application が、scope の抽象を通さずに DB を直接実行すること。
store や adapter が、独立して transaction を開始または確定すること。
composition が、transaction を開始または確定すること。
効果の記述の構築の時点で、transaction の開始、読み、書き込み、確定を実行すること。
use-case の外の機構に、use-case の終わりの成否から確定か中止かを既定の動作で決めさせ、確定の条件と確定の結果の分類を use-case から外すこと。
scope の取得と解放を束ねる合成に、確定を行わせること。
参加操作に、transaction の開始・確定・中止を持たせること。
参加操作を、確定を所有する use-case の外から単独の確定として実行すること。
独立して確定する別の use-case や workflow を外側から包んで、複数のコンテキストの変更を同時の確定に見せること。
driver のエラーの値や文字列を、業務の失敗に載せること。
確定を始める前に終わった scope を、開いたまま残すこと。
取り消しを理由に、scope の中止を打ち切ること。
中止の失敗で、元の終わりを失わせること。
エラーの種類だけを根拠に、確定していないと判断すること。
結果が分からない確定を、確定、未確定、取り消しのいずれかとして返すこと。
確定を確認した後の後始末の失敗や取り消しを、確定済みの結果を打ち消す失敗として返すこと。

### 行動
use-case ごとに、必要な操作と確定と中止を持つ scope の抽象と、scope を開始する抽象を application に宣言し、複数のモデルの書き込みを同じ確定に含めるなら、その操作を同じ scope に宣言する。
他のコンテキストの状態変更を同じ確定に含める use-case は、参加の能力を自分の port として宣言し、参加操作の拒否・競合・失敗では確定せずに終える。
use-case で、scope の取得と使用と解放を一つの効果に閉じ、使用の中で必要な値を読み、domain の純粋な関数へ渡し、判断の結果を書き込んで確定を明示する。
判断が拒否したときと競合のときは、確定せずに終え、scope の中止を元の終わりに添えて返す。
infrastructure で、scope の抽象を driver の transaction を内側に持つ型で実装し、store には scope の transaction を渡して書かせる。
scope の操作の失敗を、use-case が分岐に使う分類へ写し、driver のエラーは業務の失敗に載せずに観測の殻へ渡す。
composition で、scope の抽象に実装を結ぶ。
取り消しを受けたら新しい書き込みを始めず、scope の中止を取り消されない領域で完了まで行う。
確定の呼び出しの結果を、確定、未確定、結果不明に分け、実装が確定していないと確認できる場合だけ未確定にする。
確定を確認した後の後始末の失敗は、確定済みの結果と別に返す。
store・composition・domain が開始と確定を呼んでいないことと、use-case の外の機構が確定か中止かを既定の動作で決めていないことを、構造検査とレビューで確かめる。
効果の記述を構築しただけでは transaction が始まらないことを、構築の無実行テストで確かめる。
中止の失敗と、確定の応答を失う失敗と、確定後の後始末の失敗を注入し、元の終わりと確定の結果が他の終わりへ写らないことを確かめる。

### 例

domain が transaction の読み書きや確定を呼ぶと、業務の判断に外部効果が混ざる。

```text
Order.place(customer, transaction):
  order = build(customer)
  transaction.insert(order)
  transaction.commit()
  return order
```

use-case の外の関数が transaction を開始し、成否だけから確定か中止かを決めると、use-case は driver の transaction を受け取り、確定の条件と結果の分類が use-case から外れ、呼んだ時点で DB が実行される。

```text
atomic(useCase, command):
  transaction = driver.begin()
  result = useCase(transaction, command)
  if result is success: transaction.commit() else transaction.abort()
  return result
```

domain は判断だけを返し、use-case が scope の抽象を通して開始から確定または中止までを効果の記述として組む。
次の断片は、販売の `Order` と倉庫の `Inventory` を別のモデルのまま、一度の確定に含める。
各行は効果を順に合成する記述であり、構築では何も実行せず、runtime が実行したときだけ始まる。
infrastructure の実装だけが driver の開始・確定・中止を呼ぶ。
拒否や失敗で確定しないまま終わると、解放が scope を中止し、元の終わりを保ったまま解放の失敗を別に観測できる。
確定の応答を受け取れなかったときは `outcomeUnknown` を返す。
読みと書き込みの失敗も、同じ形で元の終わりを保って返すが、この断片は省く。

```text
domain:
  Order.place(customer, lines) -> refused(reason) | accepted(order)
  Inventory.reserve(stock, lines) -> refused(reason) | accepted(reservation)

application:
  port PlaceOrderScopes:
    begin() -> Effect<PlaceOrderScope>

  port PlaceOrderScope:
    findCustomer(customerId) -> Effect<Customer>
    lockStock(skuIds) -> Effect<unit>
    findStock(skuIds) -> Effect<Stock>
    insertOrder(order) -> Effect<unit>
    insertReservation(reservation) -> Effect<unit>
    commit() -> Effect<committed | notCommitted | outcomeUnknown>
    release() -> Effect<released | releaseFailed>

  placeOrder(scopes, command) -> Effect<placed | rejected | failed | outcomeUnknown>:
    scope = acquire scopes.begin() release scope.release()
    customer = scope.findCustomer(command.customerId)
    scope.lockStock(command.skuIds)
    stock = scope.findStock(command.skuIds)
    order = Order.place(customer, command.lines)
    reservation = Inventory.reserve(stock, command.lines)
    if order or reservation is refused: end rejected(reasons)
    scope.insertOrder(order)
    scope.insertReservation(reservation)
    match scope.commit():
      committed: end placed(order.id)
      notCommitted: end failed
      outcomeUnknown: end outcomeUnknown
```
