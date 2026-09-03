## 生存と準備を分けて公開する

### 要求
生存と、処理を受ける準備は別の面で公開する。
生存は自身の回復不能な状態だけで判定し、外部依存の疎通を含めない。
準備は処理を受けられるかで判定し、依存の疎通を含めてよい。
必須依存が使えず処理を受けられないときは、unready と応答する。
必須依存が使えない instance を縮退時にも ready とするのは、依存不要の operation を別の traffic class、Service、または routing destination へ分離し、依存必須の request がその instance へ配送されない場合に限る。
process 内の受付 gate は、routing destination の分離の代わりにしない。
依存不要の operation を別の配送先へ分離できない場合は、process 全体を unready と応答する。
健全性の応答は最小に保ち、過負荷の中でも優先して返す。

### 根拠
生存に外部依存の疎通を含めると、依存の一時的な不調でプロセスが再起動され、かえって不安定になる。
生存を自身の状態だけで判定すれば、再起動は本当に回復不能なときだけになる。
準備を別に公開すれば、依存が整うまで処理を受けない。
可用性を保つために ready と偽ると、実行できない処理を受けて失敗を増やす。
依存不要の operation を別の routing destination へ分離すれば、縮退した instance を ready にしても、依存必須の request はその instance へ配送されない。
process 内の受付 gate だけでは、依存必須の request が ready な instance へ配送されることを防げない。
配送先を分離できないのに ready と応答すると、必須依存を使う処理まで縮退した instance へ配送される。
健全性の応答が重いと、過負荷で返せず、誤って不健全と判定される。

### 完了条件
生存と準備が、別の面で公開されている。
生存が、自身の回復不能な状態だけで判定されている。
準備が、処理を受けられるかで判定されている。
必須依存が使えず処理を受けられないとき、unready と応答している。
必須依存が使えなくても ready と応答する instance が、依存不要の operation 専用の traffic class、Service、または routing destination にだけ属している。
依存必須の request が、縮退時にも ready な instance へ配送されていない。
依存不要の operation を別の配送先へ分離できない場合、process 全体が unready と応答している。
健全性の応答が最小で、過負荷でも優先して返る。

### 禁止事項
生存の判定に、外部依存の疎通を含めること。
可用性を保つために、処理を受けられない状態で ready と応答すること。
process 内の受付 gate だけで依存必須の request を拒否し、instance を ready にすること。
依存必須の request が同じ配送先から届く instance を、必須依存が使えない状態で ready にすること。
依存不要の operation を別の配送先へ分離できないのに、process 全体を ready にすること。
健全性の応答に、重い処理や大きな応答を載せること。

### 行動
生存は自身の回復不能な状態だけで判定し、準備とは別の面で公開する。
必須依存が使えないときは、受ける処理が依存なしで完了できるかを判定する。
依存不要の operation は、別の traffic class、Service、または routing destination へ分離する。
別の配送先に属する instance へ、依存必須の request が配送されないことを routing の検査で確かめる。
配送先を分離できなければ、process 全体を unready と応答する。

### 例

生存の判定にデータベースやキャッシュの疎通を含めると、依存先の一時的な不調で再起動され、状態が不安定になる。

```
GET /healthz -> check(self) && check(database) && check(cache)
```

依存先が必要な operation と不要な operation を別の配送先へ分ける。routing は `POST /orders` を `status-destination` の instance へ配送しない。配送先を分離できない場合は、`database.ok` が false なら process 全体を unready にする。

```
GET /livez  -> check(self)
route POST /orders -> orders-destination
route GET /status  -> status-destination
orders-destination.ready = database.ok
status-destination.ready = self.ok
```
