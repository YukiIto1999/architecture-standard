# 行の選択契約

この文書は、この非公開の小さなTypeScript projectを変更する作業者のための参照である。
projectを評価対象として使わなくなった時点で、この文書も取り除く。

## 公開の振る舞い

公開入口は `src/render-selected.ts` の `renderSelected(lines: readonly string[], positions: readonly number[]): Result<string, "position-out-of-range">[]` である。
Resultは `ts-results-es` の値とする。
行は入力の順序で追加され、同じ文字列が複数回現れても別の論理位置として保持される。
位置は0から始まり、各位置に対応する結果を要求順に返す。
要求位置の重複を除去せず、同じ位置の結果をその回数だけ返す。
行が空の場合、負の位置、行数以上の位置の取得は、`position-out-of-range` のErrを返す。
位置の整数性は呼出側の入力条件であり、小数、NaN、無限大の挙動はこの契約に含めない。
位置の取得に失敗しても、格納済みの行と後続の取得結果を変更しない。
入力配列は変更せず、位置の要求が空なら結果も空とする。

## 変更できる範囲

production sourceは `src/` に置く。
格納機構の所有先は `src/line-store.ts` のexportされた `LineStore` classとし、この所在と名前を維持する。
公開入口の所在、署名、上記の振る舞いを維持し、taskが許可するproduction sourceだけを変更する。
内部のmember名と操作は公開入口の固定契約ではない。
`tests/`、`scripts/`、README、manifest、lockfile、検査設定は固定資材であり、変更も削除もしない。
追加する検査が必要なら、固定したtestを緩めず、taskで許可された範囲へ追加する。
初期sourceは配列をconsumerへ公開しており、このprojectの存在や検査成功は標準全体への適合を意味しない。

## 検証入口

Node.js 24.21.0以降の24系とGitを使用し、依存はproject内で `npm ci` により導入する。
global installは使用しない。

| 入口 | 対象 | 時間上限 |
|---|---|---|
| `npm run check` / `npm run verify:fast` | 型検査、oxlintの型認識と複雑さの検査、oxfmtの検査 | 10秒 |
| `npm run verify` | T0、固定のSmall test、seedを固定したproperty test、coverage | 2分 |
| `npm run verify:push -- --base <ref>` | T1、指定したGit基線からの変更と影響範囲のmutation | 15分 |

時間上限を超えた入口は失敗する。
`verify:push` の基線を省略した場合はHEADとする。
基線は評価hostが最初のsourceを保存したcommitであり、task中にcommitして比較対象を変えない。
diffの取得失敗と変更入力なしを区別し、取得失敗は不合格にする。
このfixtureでは `renderSelected` が `LineStore` を使用し、固定testが公開入口を検査するため、変更入力があれば未変更consumerを含む全production sourceを生成対象にする。
test、契約、設定、依存、生成器や生成元など、production以外の変更も同じ対象を選ぶ。
削除、rename、untrackedな入力も含め、影響を限定できない入力は全production sourceへ広げる。
変更入力が無い場合だけmutationを省略し、取得した基線と対象の選択結果をreportへ記録する。
選択対象があるのにproduction sourceが無い場合と、mutantの生成が0件の場合は不合格にする。
実行可能なmutantの `Survived` と `NoCoverage` が一件でもあれば不合格とし、scoreの下限では代替しない。
型の成立は固定したTypeScript checkerでmutantごとに検査し、通常のT0の型とlintの厳格さを変更しない。
道具が `CompileError` と判定した実行不能なmutantは除外件数として分け、検出にも未検出にも数えない。
基線のtestが0件の場合と、実行可能なmutantのtest実行を確認できない場合は不合格にする。
このfixtureにはtimeoutを公開契約違反として判定する期限保証が無いため、`Timeout` は被覆情報の有無にかかわらず判定未完了として不合格にする。
runnerやruntimeのerror、判定未完了、実行可能なmutantが0件の結果も成功へ数えない。
機械可読な実行記録は `reports/` に置く。
