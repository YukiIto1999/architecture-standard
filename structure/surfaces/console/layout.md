# console の構造

console は、CLI の surface である。
core を埋め込み、コマンドの引数を build_core が返す API の operation へ写像する。
自己ホストであり、自身でプロセスを起動する。
対話の体験は [concerns/experience](../../../concerns/experience/README.md)、keyboard 操作の可達性は [concerns/accessibility](../../../concerns/accessibility/README.md) に従う。
console は [skeleton](../../skeleton.md) の依存と命名に従う。

## フォルダ構成

```
console/
├─ commands/
│  └─ <command>     引数を core API の operation へ写像する。
└─ composition      core の埋め込み・設定の読み込み・起動。
```

`commands` は、1 command を1ファイルに置く。
`composition` は単一の組立点である。

## 依存方向

依存の向きは [concerns/dependency](../../../concerns/dependency/README.md) に従う。
composition が commands を組み立て、core を埋め込む。
commands は composition を参照しない。
起動の流れは main → composition → command の一方向であり、command は組み立て済みの core API と検証済み入力を composition から受け取って実行する。
console の外との依存は [skeleton](../../skeleton.md) に従う。
console 自身の技術的な処理は、[libs](../../libs/layout.md) の公開 API を直接使え、core の operation を仲介にしない。
依存方向の規律は [concerns/dependency](../../../concerns/dependency/README.md) に従う。

## 入口とコマンド

command は、引数を core API の operation へ写像する。
command は、業務判断を持たず、入力の解析と operation の呼び出しだけを行う。
console は wire の binding を持たないが、引数、標準入出力、終了 status は人と script に公開する契約として扱う。
console は、派生読みモデルの臨時・手動の再構築 workflow を command として起動する役割を担う。
引数の解析の機構は [languages](../../../languages/) が定める。

## 呼び出しの契約

command の契約は、利用目的、入力元、引数と option の型、必須性、既定動作、出力、失敗、状態への効果を持つ。
引数、stdin、file の入力を併用する command は、組み合わせの可否と競合時の扱いを定める。
入力の検証は [concerns/types](../../../concerns/types/parse-once-at-boundary.md) の「境界で一度だけ parse する」に従う。
起動時設定の解決順は [concerns/configuration](../../../concerns/configuration/single-config-source.md) の「定めた源からまとめて読む」に従い、command の option と実行時 flag を同じものとして扱わない。
command 名や option 名を決める前に、人が判断する結果と script が読み取る結果を区別する。
help は usage、入力条件、主要な効果、出力形式、失敗時の直し方へ辿れる入口にし、対象 operation の実行や資格情報の取得を要しない。
help、version の照会は、業務状態を変えない。
代表的な呼び出しは、正常系だけでなく、入力拒否、結果が空の場合、競合、再実行、取り消しを契約の適用条件から選ぶ。
例の件数ではなく、各呼び出しの stdout、stderr、終了 status、状態変化を検証できることで契約の充足を判定する。

## 出力と終了

stdout は結果の channel とし、診断、進行表示、確認の文言は stderr または専用の対話 channel へ分ける。
機械向けの出力形式は、項目、型、区切り、順序の保証、空結果、部分結果、互換性の扱いを契約に持つ。
人向けの表や色付きの文言を、script が解析する契約にしない。
成功は終了 status 0 とし、入力拒否、実行失敗、取り消し、部分成功の非ゼロ status とその意味を command の契約で定める。
失敗を診断へ表示しても、成功の終了 status を返さない。
出力途中で失敗する command は、consumer が完全な結果と部分結果を区別できる形にし、結果を失った後の再実行で何が起きるかを明示する。
機械向け出力に、prompt、spinner、色、cursor 制御を混ぜない。

## 対話の選択

stdin、stdout、stderr の TTY 判定は別々に行い、結果の redirect と対話入力の可否を混同しない。
非対話の指定または入力 TTY の不在では、prompt を待たず、必要な入力や確認がなければ効果を起こす前に拒否する。
stdin が業務データを受け取る場合は、確認入力として同じ channel を消費しない。
対話の装飾は、描画先の terminal capability と利用者の明示指定に従って選び、非 TTY では線形の結果と診断を返す。
一回の処理や選択して終了する操作に、継続する full-screen session を機械的に追加しない。

## 効果と再実行

破壊的な operation は、対象と効果を提示して確認し、非対話では対象を特定した明示的な承認を要求する。
確認、取り消し、回復の保証は [concerns/experience](../../../concerns/experience/error-prevention-recovery.md) の「誤りを防ぎ、起きたら回復を助け、取り返せるようにする」に従う。
preview または dry-run を提供する場合は、実行と同じ入力解決と計画を使い、変更する対象と未確定の条件を示すが、業務の書込みを行わない。
preview 後に対象が変わりうる場合は、確定時の再照合を計画に含め、preview を成功の予約として扱わない。
再実行の契約は、同じ要求の識別、二度目の結果、重複する効果の有無、途中で終了した後の再開を区別する。
取り消しが確定前か確定後かで結果が異なる場合は、確定済みの効果を消えたものとして表示しない。
取り消しの伝播と後始末は [concerns/concurrency](../../../concerns/concurrency/cooperative-cancellation.md) と [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。

## terminal の所有

raw mode、screen buffer、cursor、入力 mode を変える session は、変更前の terminal 状態を一つの所有者が保持し、取得と復元を同じ scope に置く。
資源の解放は [concerns/effect](../../../concerns/effect/cancellation-resource-safety.md) の「取り消しと資源を言語の機構に委ねる」に従い、通常終了、起動途中の失敗、実行失敗、取り消しで取得済みの状態を復元する。
描画と入力を framework が所有する場合は、その lifecycle の入口を使い、別の reader や signal handler を競合させない。
editor や shell への一時的な引き渡しは、最終終了と分け、UI の入力を止めて terminal を復元してから渡す。
引き渡しから戻る際は、所有を再取得し、外部で変わったデータを再読込して全体を再描画する。
復元できない突然死の範囲を、通常の終了経路の復元保証と区別する。
terminal の入力 loop と描画の経路では、file、network、子 process の完了を同期的に待たず、処理結果を event として戻す。
描画は入力、データ変更、resize、意図した tick で起こし、変化のない状態を無条件の loop で再描画しない。
配置、切詰め、cursor 位置は文字列の長さでなく terminal の cell 幅から求め、結合文字を途中で切らない。
日本語、結合文字、emoji、狭い terminal、resize に対する表示と keyboard の操作経路を検証する。
terminal を所有する描画先へ、非同期の log や診断を割り込ませない。
契約の検査と terminal 所有の実測は [tests/methods](../../tests/methods.md) に従い、後者を状態モデルの成功だけで代替しない。

## 配布

console は、単一の配布 channel で配布する。

## 組み立てと起動

composition は、build_core で core を埋め込み、自身でプロセスを起動する。
composition は、実行環境が渡す起動主体の資格情報を認証境界で検証し、actor を一度だけ構築する。
command は actor または資格情報を引数から受け取らず、composition が構築した actor と検証済み入力だけを core の公開 API へ渡す。
資格情報と認証方式の型を、core の公開 API へ渡さない。
終了の規律は [concerns/lifecycle](../../../concerns/lifecycle/README.md) に従う。
core の組立は [structure/core/composition](../../core/composition.md) に従う。
設定と secret の読み込みは [concerns/configuration](../../../concerns/configuration/README.md) に従う。
