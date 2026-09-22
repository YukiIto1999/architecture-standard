# http-client-js

用途は、契約から TypeScript の client と型を生成し、drift・conformance の検査に使う道具である。
採用は、TypeScript は `@typespec/http-client-js` である。
判断基準は、契約から contracts/generated の client と型を生成でき、判別付き直和が判別子つきの union になり、生成した client が transport の実装を引数で受け取り、同じ入力と同じ版から同じ出力を得て drift をリポジトリの検証入口の gate にできることである。生成物が製品が採用する TypeScript の型検査を通ることと、生成器が製品の型検査 toolchain へ版の制約を広げないことを含む。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、transport の注入点の廃止、生成物が製品が採用する TypeScript の型検査を通らなくなること、安定版の到達を再評価のトリガーとする。

## 生成した契約を使い、drift を検査の gate にする

### 要求
contracts/generated の TypeScript の client と型は、契約から `@typespec/http-client-js` で生成する。
生成物を、手で編集しない。
生成した client は、host が実装する transport を引数で受け取る。
client の既定の transport と既定の再試行・redirect・logging の設定に、依存しない。
生成した client を使うのは ui port の実装であり、viewer は生成物の型だけを型として import する。
生成器は、製品の型検査 toolchain と別の package で動かす。
生成物は、製品が採用する TypeScript の型検査へ通す。

### 根拠
契約を手で書き写すと、契約と実装がずれる。
契約から client と型を生成すれば、path・method・status と body の対応が契約から導かれ、host ごとに書き写さずに済む。
transport を引数で受け取れば、TLS・proxy・timeout・再試行のような host ごとに変わる判断を、契約から生成した成果物の外に置ける。
既定の transport に依存すると、host が変わるたびに契約から生成した成果物の中の設定を変えることになる。
viewer は ui port を通して通信するため、生成した client を viewer が import する理由がない。
生成器は契約の compiler の上で動き、製品の TypeScript を要求しないので、型検査の toolchain と版の制約が分かれる。

### 完了条件
client と型が、契約から `@typespec/http-client-js` で生成され、contracts/generated に commit されている。
再生成した出力が commit した出力と一致し、一致しないことがビルドの失敗になっている。
判別付き直和が、判別子つきの union として生成され、網羅の検査が型で成立している。
生成した client が、host の実装した transport を引数で受け取っている。
生成した client を import しているのが、ui port の実装だけである。
viewer が、生成物の型だけを型として import している。
生成物が、製品が採用する TypeScript の型検査を通っている。

### 禁止事項
生成物を手で編集すること。
生成物を、client・型と drift・conformance の検査以外に使うこと。
生成した client の既定の transport を、そのまま製品の経路に使うこと。
viewer から、生成した client を import すること。
生成器が要求する版の制約を、製品の型検査 toolchain の依存解決へ広げること。

### 行動
契約から `@typespec/http-client-js` で client と型を生成し、contracts/generated へ書き出して commit する。
検証入口で再生成し、差分が出たら失敗させる。
host の transport を client の引数へ渡し、TLS・proxy・timeout・再試行の判断を host 側に置く。
ui port の実装から生成 client を呼び、viewer には型だけを渡す。
