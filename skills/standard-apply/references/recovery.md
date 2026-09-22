# 意味回収の根拠状態を分ける

`process/recovery.md` を選んだモードで、対象 project を読み始める前に読む。

recovery では、判断を動かす主張を `主張 / 根拠状態 / locator または導出 / 意図状態 / 変更先状態 / 未解決境界` の列へ分ける。根拠状態には `Known`、`Derived`、`Observed`、`Assumed`、`Unknown` の一つだけを置く。確認済みの意図を述べる主張だけは意図状態を `Intended`、明示的に決定した変更先を述べる主張だけは変更先状態を `Target` とし、該当しない軸は `対象外` とする。一つの主張が現在の意図と将来の変更先を同時に述べる場合は二行へ分ける。Accepted な契約が確認済みの意図を表す場合は、根拠状態を `Known`、意図状態を `Intended`、変更先状態を `対象外` とする。読み取り専用作業で変更先を決めず、Observed の行へ `Target 未確定` を反復しない。
各行の根拠状態 cell は `Known`、`Derived`、`Observed`、`Assumed`、`Unknown` の語だけにし、括弧書き、注記、`—`、空欄を置かない。観測集合の限定や理由は locator または未解決境界へ移す。意図状態は `Intended`、`Unknown`、`対象外` の一つ、変更先状態は `Target`、`Unknown`、`対象外` の一つにする。主張がその軸を扱わない場合は `対象外`、扱うが根拠がない場合は `Unknown` とし、記号だけで両者を混同しない。
ユーザーが仕様または確定した決定として明示した主張、一次資料、明示契約に基づく主張を `Known`、source、test、設定、実行結果として現在そうである主張を `Observed` にする。ユーザー入力でも、質問、提案、仮説、記憶、不確かさを伴う説明、調査してほしい候補は `Known` にせず、根拠を伴う仮定なら `Assumed`、根拠がなければ `Unknown` にする。source に型や値が定義されていることを、locator があるという理由だけで `Known` にしない。
ユーザーが示した仮説は、その仮説自体を `Assumed` の独立した行に残す。仮説の主語と範囲を変えずに、読んだ実体が仮説を支持または反証するかを別の `Observed` または `Derived` の行で判定する。`worker.rs` 自身が writer であるという仮説を、project 内のどこかに writer があるという広い命題へ読み替えて Unknown にしない。反対に、局所の反証を project 全体の writer 不在へ広げず、その範囲は独立した `Unknown` の行にする。元の仮説の `Assumed` 行は、反証できた場合も省略しない。
一つの根拠状態欄へ `Known + Observed` のように複数値を書かない。同じ主張に資料と実装の両方がある場合は、資料に基づく主張と実装に基づく主張へ行を分ける。意図や変更先を述べない主張へ、未確定の `Intended` または `Target` を補わない。
最終応答の直前に根拠状態列を照合し、五つの許可語との完全一致でない cell が一つでもあれば、注記を他列へ移すか行を分割するまで完了しない。Observed な参照の存在と、その参照先定義が Unknown であることも別行にする。
矛盾、不一致、risk などの診断は、根拠行から導いた `Derived` の独立した行にする。回収結果に診断が一つでもあれば、Derived を表外の未分類 prose にしない。
`Known` と `Observed` には file、行、一次資料、コマンド結果の locator を、`Derived` には前提と導出を添える。`Assumed` と `Unknown` は未解決のまま明示し、`Intended` または `Target` へ読み替えない。
資料と実装の食い違いを矛盾または defect と確定できるのは、同じ性質について衝突する双方を根拠付きで確認した場合だけである。確定した一つの性質から、別の state authority、caller、設定、runtime まで確定したと広げない。未観測の要素がその主張を両立させる余地を残す場合は `Unknown` とし、「余地がない」と断定しない。
一つの discovery search が返さない hidden file、除外 artifact、宣言外の module の内容は未観測である。空の search や初回候補集合を、その範囲を超える不存在の根拠にしない。
存在しないという主張は、宣言された対象集合または実際に列挙した集合を覆う証拠がある場合だけ `Observed` にする。狭い native search が返さないことから、project 全体に存在しない、全 file に参照がない、decision record がないとは断定せず、未観測範囲を `Unknown` にする。
到達不能、writer 不在、参照なしを `Derived` にする前に、その主張を変えうる定義、生成物、外部 module、hidden file が観測範囲に残っていないことを示す。未定義 symbol、除外した artifact、未観測の呼出元または実装が一つでも残る場合は、確認した file 間の辺がないという `Observed` と、project 全体での定義または到達可能性が `Unknown` であるという行へ分ける。未定義 symbol を複数まとめる場合も、候補集合内で定義を確認できない `Observed` 行と、集合外を含む project-wide な定義・到達可能性の `Unknown` 行を表内で対にし、表外の要約だけで後者を代用しない。
最終応答の回収表は `主張 / 根拠状態 / locator または導出 / 意図状態 / 変更先状態 / 未解決境界` の六列を省略しない。各行の未解決境界には、その主張の真偽を変えうる未観測範囲を具体的に書き、なければ `対象外` とする。表外で Unknown を後置しても、表内の網羅主張または過剰な Derived は相殺されない。
Executive Diagnosis、要約、結論にも回収表と同じ観測境界を適用する。表で Unknown とした範囲を、表外で「実装のどこにもない」「実現されていない」「writer は存在しない」と断定しない。
bounded discovery で始めた報告は、実際に観測した候補と、宣言または直接リンクから追加で読んだ file を対象範囲として表記する。`target-project 全域` または `全 file` と呼ぶには、その coverage を根拠付きで示す。未解決境界には観測集合外に存在する可能性を分けて書き、空の search を「他に資料がない」と要約しない。
読み取り専用の recovery は、意味、状態、責務、依存の診断で止める。修正、目標構造、移行順序、新しい抽象、将来の拡張を提案または作成しない。
project root だけを与えられた recovery は、README または manifest が宣言する source、test、configuration を開始点にし、宣言がなければ process が要求する bounded discovery を行う。決定の記録の正本の置き場は最上位 README の宣言で確認する。宣言がなければ置き場と契約の authority を Unknown に残し、manifest や直接リンクから読めた記録は候補として区別する。source、caller、authority、test、decision record の直接リンクを追って material evidence が揃うまで狭く探索し、最初の search が空でも候補名や別 directory を機械的に試さない。現在の標準本文が定める decision-record 規則と target project の宣言が食い違う場合は、観測した宣言と規範の差を Unknown または Derived として分け、どちらかを黙って読み替えない。
