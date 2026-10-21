# NixOS

用途は、server と worker を載せる OS として、service の起動・監視・再起動、資源制限、固定の時刻と間隔による起動を、宣言から再現する基盤である。
採用は、NixOS と systemd である。
判断基準は、OS の宣言から配備先を再現でき、service の起動・監視・再起動、資源制限、時刻による起動を OS が既に持つため、container で包み直さず、言語内へ同じ仕事を再実装せずに済むことである。
desktop・mobile・利用者の端末の OS を、NixOS に限定しないことを含む。
撤回条件は、判断基準を満たさなくなることであり、NixOS と systemd のライセンスとリリースポリシーの変化、server と worker の配備先を OS の宣言で再現できなくなることを再評価のトリガーとする。

## service の運用

### 要求
server と worker の service は、NixOS の宣言の中の systemd の unit として起動する。
再起動の方針は `Restart=`、停止の期限は `TimeoutStopSec=`、資源の上限は `MemoryMax=`・`CPUQuota=`・`TasksMax=` で unit に宣言する。
プログラムは、起動の監視、再起動の loop、資源の上限の強制を、内部に再実装しない。
プログラムは、停止の合図を受けた後の受付の停止と期限内の終了を、[graceful-shutdown](../../concerns/lifecycle/graceful-shutdown.md) の「合図を受けたら受付をやめ、期限内で終える」に従って自身で担う。
server と worker の実行系を container で包み直さず、OS の宣言が直接起動する。

### 根拠
systemd は、unit の宣言から service を起動し、`Restart=` で終了・kill・timeout の後の再起動を、`TimeoutStopSec=` で停止の期限を、resource control の設定で cgroup の資源の上限を扱う。
OS が同じ仕事を持つのにプログラムも持つと、再起動や上限の判断が二か所に分かれ、どちらが働いたかを追えない。
NixOS は unit を宣言として持つので、同じ宣言から同じ配備先を再現できる。
container で包み直すと、OS が持つ起動・監視・資源制限の上に同じ層を重ねるだけになる。
停止の合図を送るのは OS だが、受付を止めて進行中の仕事を終えるのは、仕事を知るプログラムだけが担える。

### 完了条件
server と worker の service が、NixOS の宣言の中の systemd の unit として起動されている。
再起動の方針、停止の期限、資源の上限が、unit に宣言されている。
プログラムの内部に、起動の監視、再起動の loop、資源の上限の強制がない。
停止の合図の後、プログラムが受付をやめ、`TimeoutStopSec=` の期限の中で終えている。
server と worker の実行系が、container で包み直されず OS の宣言から起動されている。

### 禁止事項
OS が持つ起動・監視・再起動・資源制限を、プログラムの内部で再実装すること。
手で配備先の unit を変えること。
server と worker の実行系を container で包み直し、OS の宣言と二重に管理すること。

### 行動
unit に `Restart=`、`TimeoutStopSec=`、`MemoryMax=`・`CPUQuota=`・`TasksMax=` を宣言する。
プログラムには、停止の合図で受付をやめて期限内に終える処理だけを持たせる。
実行系は container を作らず、OS の宣言から直接起動する。

## 定時起動

### 要求
固定の時刻と間隔による起動は、NixOS の宣言の中の systemd の timer で宣言し、起動される service は oneshot にする。
timer は、worker の定時起動の入口だけを起動する。
停止中の起動を補う timer は、`OnCalendar=` と `Persistent=true` を使い、補われるのは過ぎた期間に対する一回の起動だけと扱う。
起動される service が動いている間に timer が満ちても、新しい instance は起動されないと扱う。
timer の起動を、複数の機の中で一つだけが起動すること、停止中に過ぎた全ての時刻の起動の保存、業務の予約が一度だけ起きることの根拠にしない。
これらが要る処理は、[worker](../../structure/surfaces/worker/layout.md) の「定時起動」に従い、入口の冪等と durable な記録で満たす。

### 根拠
`Persistent=` は、timer が止まっていた間に一回以上起動すべき時刻があったとき、service をその場で起動する設定であり、`OnCalendar=` の timer にだけ効く。
過ぎた時刻が複数あっても、起動は一回である。
suspend の間に過ぎた calendar の timer も、何度満ちても一回の起動にまとまる。
起動される unit が既に動いているとき、timer はそれを再起動せず、そのまま動かし続ける。
最後に起動した時刻は、その機の disk に保存されるので、timer が持つ記録は機をまたがない。
だから timer の起動は、その機の上での起動の合図であり、cluster の一意性、全ての起動の再現、業務の予約の exactly-once を担わない。
NixOS は `systemd.timers` で timer を、`systemd.services.<name>.startAt` で `OnCalendar=` の簡易な宣言を持つので、timer を手で作る必要がない。

### 完了条件
固定の時刻と間隔の起動が、NixOS の宣言の中の timer で定義され、配備先に手で作った timer がない。
timer が起動する service が oneshot であり、起動する入口が worker の定時起動の入口だけである。
取りこぼしを補う timer が、`OnCalendar=` と `Persistent=true` を持っている。
timer の起動が重複しても、欠けても、同じ予定時刻の要求が一度分になることが、worker の検証で確かめられている。

### 禁止事項
timer を、複数の機の中で一つだけを起動する根拠にすること。
`Persistent=true` を、過ぎた全ての起動の保存として扱うこと。
timer の起動を、業務の予約が一度だけ起きる根拠にすること。
timer と同じ固定の時刻の scheduler を、プログラムの内部に再実装すること。
手で配備先へ timer を作ること。

### 行動
固定の時刻と間隔の起動を、`systemd.timers` か `startAt` で NixOS の宣言へ書く。
`OnCalendar=` の式は、`systemd-analyze calendar` で次の起動の時刻を確かめる。
起動を取りこぼせない処理は、timer の補完に頼らず、worker の定時起動の入口が永続化した処理済みの予定時刻から未処理の分を数え上げて要求する。
