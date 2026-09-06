---
name: standard-apply
description: architecture-standard 以外の標準には使わず、「別 repository の社内コーディング標準」が明示された依頼は対象外である。この repository で「architecture-standard に従って」「標準に従って」「標準準拠」「標準を適用」「structure の標準に合わせて」「準拠 commit を基準に」と指定された対象 project または repository の作業では、対象 path や symbol が未特定でも、調査や編集に着手する前に、この skill を必ず使う。特に「標準に従ってこの worker の設計」「project ADR に残す判断を分ける」のように対象確認が必要な設計依頼や、「architecture-standard を使って staged diff をレビュー」のような読取依頼でも、対象を探す前にこの skill を呼び出す。この skill は対象確認後の参考資料ではなく、未特定事項を含む作業の最初の入口である。新規構築、意味回収、監査、移行、設計、実装、refactoring、構造改善、review、staged diff review、バイブコーディング由来システムの構造再生が該当する。architecture-standard 自体の変更には standard-update、自己監査には standard-audit を使う。
---

# standard-apply

標準を project へ適用する入口である。
手順と判定基準の正本は標準本文に置き、この skill へ転写しない。

## 開始ゲート

対象 project へ最初の tool call を行う前に、次の入口を一つだけ選ぶ。

| 入力の入口 | 最初の対象 project 操作 | この作業で使わない探索 |
|---|---|---|
| exact file path がある | その file を Read で直接読む | 対象 project への Glob、fd、directory 一覧、`git ls-files` |
| symbol だけがある | その exact symbol の Grep で一つの定義候補へ絞り、一致 file を読む | 対象 project への Glob、directory 一覧 |
| project root だけで system-wide recovery または audit | 後述の条件を満たす場合だけ `<target-project-root>/**/*` を一回 Glob する | 二回目の Glob、別の列挙手段 |

選択直後の最初の対象 project 読取または探索は、表の操作でなければならない。標準本文は手元の `<standard-root>` にある最新の規範文書を根拠とし、対象 project の入口を再発見する `README.md` や `target-project/*` の Glob、`pwd`、directory 一覧は使わない。
exact file path を与えられた作業では、準拠 ADR、caller、state、test の確認にも Glob を使わない。path 未指定の Glob は標準と対象 project の双方へ一致しうるため、標準側だけの探索としても使わない。先に Glob してから exact path へ戻っても、この開始ゲートを満たしたことにならず、調査または設計を完了と報告しない。
project root だけを与えられた system-wide recovery または audit では、最初の対象 project 探索を文字どおり `<target-project-root>/**/*` の一回にする。`README.md` や `<target-project-root>/*` を先に試してはならない。二回目を実行した場合は後の結果を正当化に使わず、調査を完了と報告しない。

### 閉じた対象調査経路

exact source path を与えられ、受入条件に completion、state、success または failure がある設計は、次の対象 project 操作だけを記載順に行う。

1. exact source file を読む。
2. target project root の `README.md` を exact path で読み、source root と test root の記載を確認する。存在しない場合は別名の manifest を探さず、source root は exact source の親 directory、test root は Unknown とする。
3. `standard_commit:` の一回の Grep を `docs/decisions/` に限定し、一致した準拠 ADR を読む。
4. 対象 source の公開 symbol を source root で exact token の一回の Grep にかけ、一段上の公開 caller を読む。内部で呼ぶ未定義 symbol は、一つを選んだ exact token の Grep 一回だけで定義を探す。同じ token を別の root で再検索しない。
5. 対象 source の公開 symbol と同じ exact token を `docs/decisions/` で一回 Grep し、一致した Accepted ADR を読む。`Job`、`State`、`Status`、`completion` のような一般候補を順に試さない。ADR が authority 型を名指しする場合だけ、その exact 型名を source root で一回 Grep し、一致した authority source を読む。
6. 手順2で test root を確認できた場合だけ、公開 caller の exact symbol をその root で一回 Grep し、一致 test を読む。確認できなければ test 契約を Unknown にする。

この経路で対象 project に使える探索は、各手順に明記した単一 token の限定 Grep だけである。`|` を含む OR pattern、project root 全域の Grep、Glob、別名 manifest の試行を使わない。外部 cancellation、deadline、writer、依存、設定の明示的な起点が読んだ経路になければ、不在と検索せず Unknown にする。手順外の探索で得た結果は設計根拠にせず、経路を完了と報告しない。
対象 project の手順を閉じた後、標準本文は skill file の所在から固定した `<standard-root>` を起点として直接読む。skill path が `skills/standard-apply/SKILL.md` なら `<standard-root>` はその二段上の親 directory（`../../`）であり、配備先（Nix store またはチェックアウト）の最新標準本文（`README.md`、`principles/`、`concerns/`、`process/`、`structure/`、`tools/` 等）を直接参照する。標準は継続的に更新されるため、過去の特定コミットの Git オブジェクト探索は行わず、手元に配備された最新の規範文書を照合の根拠とする。
設計の最終応答は、変更不要から選んだ実現段まで、または必須条件が Unknown なら最初に成立しうる暫定段までの判定だけを列挙する。それより後の候補、抽象、依存、新規実装には、未検討・不要・不採用という言及もしない。「新しい依存は不要」「独自実装は不要」「後続の段は検討しない」のような否定文も、後段への言及なので書かない。暫定段を「選択」「成立」「十分」「この段で止める」と表現せず、確定に必要な未確認契約だけを示す。依頼が設計だけなら、将来の ADR、file 作成、cleanup、別変更の指示も削除する。必須参照の途中で変更契約外の配置違反や別件を見つけても、最終応答へ付記せず、この設計の候補、risk、今後の作業へ広げない。

project root だけを与えられた recovery は、最初の一回の Glob 後に、返った非 hidden の source、test、configuration だけを候補集合として読む。`standard_commit:` の準拠 ADR 探索もこの Glob より後に行う。ユーザー仮説と回収語の検証は候補集合の読取と `docs/decisions/` に限定した一語の Grep で行い、候補集合外を探す二回目の Glob、root 全域の Grep、別 pattern の再試行へ広げない。

## 前提

- この skill がある repository を標準、依頼で示された repository を対象 project とする。
- この skill の所在（`skills/standard-apply/SKILL.md`）から二段上の親 directory を `<standard-root>` として固定する。対象 project を current directory にした Git 操作や特定マシンのローカル絶対パスと混ぜない。
- 標準本文は常に `<standard-root>` にある最新の規範文書を参照する。対象 project の ADR に記録された `standard_commit` は歴史的経緯の記録として扱い、新しい設計や変更の判断基準には手元の `<standard-root>` 配下の最新の標準本文（`principles/`、`concerns/`、`process/`、`structure/`、`tools/`）を直接適用する。
- 標準本文は編集しない。標準側の不備は file と該当箇所を報告し、修正は standard-update へ渡す。

## 参照経路

対象 project の調査を閉じた後、`<standard-root>/README.md` と選んだ process を最初の標準本文として読む。対象 project の exact file は開始ゲートに従って先に読んでよい。
準拠 ADR に `standard_commit:` があれば、現行標準との差分確認用の文脈として一度 Grep で確認してよいが、適用する標準本文は手元の最新規律を用いる。標準の directory link はその `README.md` を直接読む。これらの発見に Glob を使わない。
それ以外の本文を読む前に、その file が答える次の判断または照合項目を内部チェックリストへ一つ記録する。
その判断を変えうる直接の参照先だけを読み、答えを得た参照経路はそこで止める。
網羅した安心を得るための directory 列挙、同階層の一括読取、使わない規律の先回り読取は行わない。
選んだ process または依頼が全域照合を要求する場合は、その要求自体を各参照経路の根拠にする。
process が現在のモードの順序または確認点として無条件に `従う` と定める link は、変更契約の必須条件として読む。`変更が触れる`、`採用する` など適用条件がある link は、条件に当たる対象と違反しうる結果を示せる場合だけ読む。
読んだ concern から別 concern への link も無条件に再帰しない。queue、過負荷、retry、deadline、lifecycle など link 先が所有する対象が変更契約に含まれる場合だけ読む。並行上限と子処理完了だけの設計では、それらが観測されない限り resilience へ広げない。
process の全 step を消し込むことと、条件付き link を全て読むことを混同しない。変更契約から不適用と判断できる条件付き step は、process 本文と観測した対象を根拠に見送り、参照先を読んで見送りを補強しない。
directory への link は同階層の列挙を許可しない。具体的な file の特定が必要なら、その directory の `README.md` を台帳として一度だけ読み、一つに絞る。台帳から絞れなければ推測で探索せず未確認事項にする。
ここまでの参照制限は標準本文に適用する。対象 project は、選んだ process の判断に必要な実行経路、caller、consumer、state、設定、テスト、実測結果を根拠が揃うまで読み、一つの file や検索結果で全体を代表させない。
依頼が対象 project root だけを示し、exact file path、symbol、manifest のいずれからも開始点を固定できず、選んだ process が system-wide な recovery または audit を要求する場合に限り、開始点の発見に Glob を一回だけ許す。pattern は `<target-project-root>/**/*` の一つに固定し、既知名の存在確認、top-level確認、source用とtest用の分割によって複数回実行しない。結果から `.git`、build output、generated artifact、vendor、`docs/decisions/` を Glob 由来の読取候補から除き、必要な source、test、configuration の開始点を固定する。project ADR が system purpose、語彙、state authority または契約を持つ場合は、Glob の結果で発見したことにせず、回収した語を固定した Grep を `docs/decisions/` に限定して別に行い、一致した file だけを読む。二回目の Glob、find、fd、`git ls-files` へ進まず、一回の結果で特定できない関係は未確認にする。Glob 自体が失敗した場合も別の列挙手段へ切り替えない。
対象 project で exact path が分かる入口は直接読む。そこから一度に広域探索せず、現在の主張を確定する caller、consumer、state authority、effect、test の関係を一つ選び、その関係を順方向または逆方向へ一段ずつ追う。変更契約または意味回収の判断を変えない directory、script、隣接 module は列挙しない。
依頼が exact source path を示す場合、対象 project 全体への Glob は使わない。source を直接読み、必要な関係は確認する symbol または参照先を固定した Grep で一つずつ探す。特定できない関係は探索範囲を広げて推測せず未確認にする。準拠 ADR の探索も上で定めた限定 Grep だけを使い、find、Glob、directory 一覧を代替にしない。
exact source path がある条件で Glob を使った場合は参照規律を満たしていないため、その結果で調査または設計を完了せず、exact path からやり直す。

## 作業境界

設計案または編集を作る前に、次を一つの変更契約として固定する。

- 依頼が求める外から観測できる結果と、明示された適用外。
- 選んだ process と標準本文が、その結果へ課す必須条件。
- 対象 project の既存契約、検証入口、安全、互換性を保つために必要な条件。

設計要素、変更 file、追加する型・抽象・設定・依存・fallback は、変更契約のいずれかの条件へ直接結びつくものだけを含める。
新しい要素を加える前に、変更不要、不要な既存要素の削除、標準に適合する既存要素の再利用または修正、標準が明示する機構、言語または実行環境の標準機構、導入済みで標準が許す依存、必要最小限の新規実装の順に判定する。
各段は変更契約の全条件を満たすかで判定し、満たした最初の段で止める。必須条件の一つでも Unknown なら、その段を満たすと判定しない。最も早く成立しうる段として暫定記録し、未確認契約が閉じるまで段の選択を保留する。後の候補を比較、設計、実装しない。閉じた探索で既存要素を確認できない場合は、その段で条件充足を立証できないと記録し、「既存要素がない」「再利用不能」と不存在を断定しない。
選んだ段、または選択を保留した暫定段と、それより前の各段では満たせない変更契約の条件を記録してから設計または編集へ進む。後の段を候補、代替案、将来案として挙げない。「この段で止め、後続の段は検討しない」のように、後段へ触れる文も最終応答へ書かない。
どの条件のためかを示せない要素は追加しない。
ここでいう最小は行数の最小化ではない。受入条件、標準の必須規律、安全、互換性、必要な検証を削らず、それらを満たす追加だけに閉じることである。
提示された source に型、呼出元、戻り値、失敗契約がなければ、標準の必須規律が要求する結果を先に固定する。観測した契約ではその結果を満たせない場合、具体的な独自型や失敗値を発明せず、必要な契約変更と確認対象を未確定の必須条件として残す。受入条件にないことを理由に標準の安全条件を削ったり、既存契約を維持できると仮定したりしない。
受入条件に completion、success、failure、state など意味と authority を要する語があれば、依頼文や対象 source の局所的な読みだけで意味を固定しない。同じ語または型を固定した Grep で、対象 project の Accepted な契約、state authority、writer、caller、既存 test を一段ずつ追い、変更契約と検証へ反映する。caller を一つ読んだだけで追跡を止めず、authority または既存 test を確認できなければ、その語の意味と検証条件を未確認にする。future または task の終了と、domain の terminal state または永続化された authority の更新を同じ completion とみなさない。`join` または task 回収という語は、対象の `JoinHandle`、`JoinSet` その他の task handle を await する経路を観測した場合だけ使う。親の future が返ることや固定の success 文字列を、spawned task の join と説明しない。両者の一致を担う writer と失敗契約が観測できなければ、task の join が保証できるのは task の終了を回収してから親が返ることだけであり、「全 job の完了後に返る」「completion の受入条件を満たす」と書かない。Accepted な契約が persisted state を authority とする場合、全 record の terminal state を確認できて初めて domain completion と判定する。
標準の言語実現が、permit 待ちを job task 内で cancellation と deadline に競わせると定める場合、親が permit を取得してから task を spawn する構造へ変えない。`JoinSet` に束ねた job task 内で取消優先の permit 待ちを行うことを必須構造とし、CancellationToken、Deadline、失敗値の具体的な入力契約だけを Unknown に残す。未確認の project 契約を理由に標準が定めた permit の所有場所を反転させず、反対に token や error 型を発明しない。
project ADR の契約は、観測した authority 型または受入語のうち最も固有な一語を選び、その exact token の一回の Grep を `docs/decisions/` に限定して探す。一致した file だけを読み、同じ file に `Status: Accepted` と候補命題の対象語がある場合だけ明示契約として使う。`Status: Accepted|<受入語>|<authority型>` の OR 検索で全 Accepted ADR を候補にしない。directory の `README.md` を推測して読まない。
既存 test は内部実装名でなく、対象 source を呼ぶ一段上の公開 caller の exact symbol を一回だけ、manifest または明示契約から確認した test root で Grepし、一致した file を直接読む。test root を確認できなければ慣例から推測せず Unknown にする。読んだ test 内で caller が返す値または状態、authority の型を検査しているかを確かめる。caller、状態、型の OR 検索や対象 project root 全域の Grep で無関係な test を候補にしない。変更対象の内部関数名だけを検索語にして公開 caller の test を不在と判定しない。これらの OR 検索または全域 Grep を使った場合、その結果で test 追跡を完了と報告しない。
設計本文を書く前に、受入条件の意味を持つ project ADR と既存 test の追跡を gate として閉じる。上の限定 Grep が一致した file は全て読み、Grep 結果の存在だけで契約または検証を確認済みにしない。Grep が一致しない場合も Glob、別語の Grep、directory 列挙へ切り替えず、その契約または検証を Unknown として設計を続ける。
並行処理の cancellation は、子の失敗時に sibling を取り消して drain する契約と、caller からの cancellation または deadline を子へ伝播する契約を別々の必須条件にする。後者の起点または現行契約を確認できなければ、外部 cancellation と deadline の伝播を未確定の必須条件として残す。
未観測の関数または module に、state authority の更新、失敗翻訳、cleanup などの責務を割り当てない。「既存の未変更の責務」と書けるのは、その責務を担う実装または明示契約を直接確認した場合だけである。確認できなければ、必要な責務と owner を別々に Unknown とし、その責務を前提に受入条件を満たすとは報告しない。
失敗または cancellation を caller へ伝える契約が未確定なら、それらを成功と同じ戻り値へ畳む疑似コードを書かない。実装形の疑似コードは省き、必要な契約変更、確認する caller、伝播の受入条件だけを残す。
未確定の必須失敗契約が一つでも残る設計では、戻り値型、`join` loop、error branch を含む code fence を最終応答へ置かない。契約が確定するまで、制御構造は prose と遷移だけで示す。
設計だけの依頼では、変更契約を満たす構造、既存機構の使い方、観測する検証までを応答で決める。ADR、設計書、報告 file への記録を依頼されていなければ file を作らず、実装も編集しない。未観測の契約に依存する分岐や、隣接する migration の設計へ広げない。
検証は対象入力または setup、観測する値、合格となる期待結果を指定する。task の終了数や実行中 counter は並行度と task 回収だけを検証し、persisted state が authority なら domain completion の検証には使わない。並行度の case と、`run` が返った時点で対象となる全 record の authority が terminal state であることを観測する case を分ける。Accepted な契約が authority と terminal state を定めていれば、後者の三要素は `識別可能な複数 job を既存の公開 caller へ渡す / run の return 時に同じ ID の persisted authority を読む / 全 record が契約上の terminal state である` まで固定する。writer、reader、persistence の具体的な呼出し方を現行 project から確定できなければ、その実現だけを未確定とし、三要素自体を不明として省略しない。架空の seam、helper、型は補わず、検証可能または完了と書かない。
persisted state を completion authority とする Accepted な契約を読んだ設計では、最終応答の検証一覧に `並行度 / task 回収 / domain authority` の三 case を必ず別々に置く。domain authority の case を未確定条件の prose だけへ移したり、writer が Unknown であることを理由に検証一覧から省いたりしない。三要素と、具体的な writer・reader 呼出しだけが未確定であることを同じ item に書く。この item がなければ設計を完了と報告しない。
尺度と閾値の列挙だけを検証設計と扱わない。受入条件ごとに少なくとも一つの具体的な case を上の三要素で閉じられなければ、設計を完了としない。
作業中に見つけた隣接課題は、変更契約の成立、安全、互換性を左右する場合だけ未確定条件へ含める。それ以外は、監査または別件報告を依頼されていなければ最終応答へ追加しない。
現在のモードで変更契約に対して実測できる条件を確かめ、未実装・未実行の条件を分けて報告した時点で止める。
最終応答の各節、設計要素、参照 file を一つずつ除いたとき、変更契約の条件または未確認事項の根拠が失われるか確かめる。失われないものは応答から除く。

## 手順

1. 標準の `README.md` を読み、依頼をモードへ写像する。新規構築=`process/bootstrap.md`、既存システムの意味回収=`process/recovery.md`、監査=`process/audit.md`、移行=`process/migration.md`、設計=`process/design.md`、実装=`process/implementation.md`、構造改善=`process/refactoring.md`、レビュー=`process/review.md`、release と配備=`process/release.md` である。検証の実行は、どのモードからも `process/verification.md` に従う。構造再生の複合依頼は recovery を読み取り専用で先に完了し、確定した意味だけを後続モードへ渡す。
2. 選んだ process 本文を読み、参照経路の規則に従って、対象範囲の判定に必要な本文だけを読む。記憶、見出し、一般的なベストプラクティスで補完しない。
   設計では `process/design.md` の順序1から8と確認点を省略しない。番号付き step または確認点が `従う` と定める直接参照は、対象が小さくても読んで照合する。directory 参照はその `README.md` から一つに絞る。
   並行処理を設計する場合は、子処理の失敗伝播と cancellation を、依頼の受入条件に列挙がなくても標準の必須条件として変更契約へ残す。現行契約が不明なら具体的な継続・停止・戻り値を決めず、未確定の必須条件にする。受入条件外の別件として落とさない。
3. process の順序と確認点を内部チェックリストとして管理し、変更契約を固定する。応答へ全文を転写せず、依頼に関係する進捗、見送り、未確認事項だけを報告する。
4. 標準が決めている事項と project 固有の決定を分ける。標準が沈黙する事項や逸脱は、一般則で埋めず、採用理由、撤回条件、単一採用、置き換える規律、技術的制約の実証を project ADR に残す。
5. 変更契約が許可する作業と focused check を実行する。読み取り専用の監査やレビューでは、報告を応答で返し、依頼されていない報告 file を作らない。判定や変更ごとに、根拠とした標準の file と該当規律を記録する。標準内の矛盾は root README の裁定規則に従い、黙って読み替えない。
6. 実装または構造改善では、完了前に変更の経緯を持たない独立した reviewer context で照合する。subagent が利用できなければ新しい独立 session を使う。どちらも利用できない場合は自己照合を行うが、独立レビュー済みとは主張せず、その制約を報告する。

### 意味回収

recovery では、判断を動かす主張を `主張 / 根拠状態 / locator または導出 / 意図状態 / 変更先状態 / 未解決境界` の列へ分ける。根拠状態には `Known`、`Derived`、`Observed`、`Assumed`、`Unknown` の一つだけを置く。確認済みの意図を述べる主張だけは意図状態を `Intended`、明示的に決定した変更先を述べる主張だけは変更先状態を `Target` とし、該当しない軸は `対象外` とする。一つの主張が現在の意図と将来の変更先を同時に述べる場合は二行へ分ける。Accepted な契約が確認済みの意図を表す場合は、根拠状態を `Known`、意図状態を `Intended`、変更先状態を `対象外` とする。読み取り専用作業で変更先を決めず、Observed の行へ `Target 未確定` を反復しない。
各行の根拠状態 cell は `Known`、`Derived`、`Observed`、`Assumed`、`Unknown` の語だけにし、括弧書き、注記、`—`、空欄を置かない。観測集合の限定や理由は locator または未解決境界へ移す。意図状態は `Intended`、`Unknown`、`対象外` の一つ、変更先状態は `Target`、`Unknown`、`対象外` の一つにする。主張がその軸を扱わない場合は `対象外`、扱うが根拠がない場合は `Unknown` とし、記号だけで両者を混同しない。
ユーザーが仕様または確定した決定として明示した主張、一次資料、明示契約に基づく主張を `Known`、source、test、設定、実行結果として現在そうである主張を `Observed` にする。ユーザー入力でも、質問、提案、仮説、記憶、不確かさを伴う説明、調査してほしい候補は `Known` にせず、根拠を伴う仮定なら `Assumed`、根拠がなければ `Unknown` にする。source に型や値が定義されていることを、locator があるという理由だけで `Known` にしない。
ユーザーが示した仮説は、その仮説自体を `Assumed` の独立した行に残す。仮説の主語と範囲を変えずに、読んだ実体が仮説を支持または反証するかを別の `Observed` または `Derived` の行で判定する。`worker.rs` 自身が writer であるという仮説を、project 内のどこかに writer があるという広い命題へ読み替えて Unknown にしない。反対に、局所の反証を project 全体の writer 不在へ広げず、その範囲は独立した `Unknown` の行にする。元の仮説の `Assumed` 行は、反証できた場合も省略しない。
一つの根拠状態欄へ `Known + Observed` のように複数値を書かない。同じ主張に資料と実装の両方がある場合は、資料に基づく主張と実装に基づく主張へ行を分ける。意図や変更先を述べない主張へ、未確定の `Intended` または `Target` を補わない。
最終応答の直前に根拠状態列を照合し、五つの許可語との完全一致でない cell が一つでもあれば、注記を他列へ移すか行を分割するまで完了しない。Observed な参照の存在と、その参照先定義が Unknown であることも別行にする。
矛盾、不一致、risk などの診断は、根拠行から導いた `Derived` の独立した行にする。回収結果に診断が一つでもあれば、Derived を表外の未分類 prose にしない。
`Known` と `Observed` には file、行、一次資料、コマンド結果の locator を、`Derived` には前提と導出を添える。`Assumed` と `Unknown` は未解決のまま明示し、`Intended` または `Target` へ読み替えない。
資料と実装の食い違いを矛盾または defect と確定できるのは、同じ性質について衝突する双方を根拠付きで確認した場合だけである。確定した一つの性質から、別の state authority、caller、設定、runtime まで確定したと広げない。未観測の要素がその主張を両立させる余地を残す場合は `Unknown` とし、「余地がない」と断定しない。
一回の Glob が返さない hidden file と、読取候補から除いた artifact の内容は未観測である。「他に資料がない」「全 file を確認した」のような網羅主張を Derived または Observed にせず、判断へ影響する可能性があれば `Unknown` とする。
存在しないという主張は、列挙手段が対象集合を覆う場合だけ `Observed` にする。`<target-project-root>/**/*` の結果から述べられるのは、その Glob が返した非 hidden の候補内で未発見だったことまでであり、「project 全体に存在しない」「全 file に参照がない」へ広げない。網羅できない範囲を含む否定命題は `Unknown` にする。
到達不能、writer 不在、参照なしを `Derived` にする前に、その主張を変えうる定義、生成物、外部 module、hidden file が観測範囲に残っていないことを示す。未定義の symbol、除外した artifact、未観測の呼出元または実装が一つでも残る場合は、確認した file 間の辺がないという `Observed` と、project 全体での定義または到達可能性が `Unknown` であるという行へ分ける。未定義 symbol を複数まとめる場合も、候補集合内で定義を確認できない `Observed` 行と、集合外を含む project-wide な定義・到達可能性の `Unknown` 行を表内で対にし、表外の要約だけで後者を代用しない。
最終応答の回収表は `主張 / 根拠状態 / locator または導出 / 意図状態 / 変更先状態 / 未解決境界` の六列を省略しない。各行の未解決境界には、その主張の真偽を変えうる未観測範囲を具体的に書き、なければ `対象外` とする。表外で Unknown を後置しても、表内の網羅主張または過剰な Derived は相殺されない。
Executive Diagnosis、要約、結論にも回収表と同じ観測境界を適用する。表で Unknown とした範囲を、表外で「実装のどこにもない」「実現されていない」「writer は存在しない」と断定しない。
一回の Glob で始めた報告は、対象範囲を `target-project 全域` または `全 file` と表記せず、`Glob が返した非 hidden の候補と、限定 Grep で読んだ ADR` のように観測集合を列挙する。未解決境界にも「他に資料がない」と書かず、観測集合内で未発見であることと、集合外に存在する可能性を分ける。
読み取り専用の recovery は、意味、状態、責務、依存の診断で止める。修正、目標構造、移行順序、新しい抽象、将来の拡張を提案または作成しない。

### 監査とレビュー

監査とレビューでは、手元の `<standard-root>` にある最新の標準本文を根拠とし、次の前処理を完了するまで対象 source の意味監査を始めない。

1. `<standard-root>/README.md` と `<standard-root>/process/<mode>.md` で root README と選択した process を直接読み、根拠にした file、見出しを内部台帳へ記録する。
2. root `README.md` の判定の枠にある severity 対応を一字一句そのまま内部台帳へ写し、その対応だけを使う。記憶や過去の判定例で severity を補足または引き上げない。
3. 選択した process の全 step を evidence ledger へ列挙し、状態を pending にする。各 step は実施済み、理由を添えた見送り、実行不能のいずれかへ更新し、根拠 file と確認結果を添える。tool output または直接の読取証拠がない step を実施済みにしない。

前処理後は、観測した実装だけを違反の根拠にする。コメントに書かれた意図だけで未実装の挙動を認定しない。依存方向表の「依存してよい先」は許可された辺であり、その依存先がないこと自体は方向違反ではない。
監査の早い step で違反を見つけても、後続の照合を打ち切らない。依頼で定めた範囲の全 step を実施済み、理由を添えた見送り、実行不能のいずれかへ消し込むまで監査を終えない。
最終応答の前に「確認予定」「後で確認」「未処理」を探す。残る項目はその場で実施するか、理由を示した見送りまたは実行不能へ変え、pending のまま完了と書かない。
必須の folder が欠けていても、現存する source の意味監査を止める理由にはしない。たとえば worker の配置が不正でも、その source を concerns の並行処理規律と tools の言語 ecosystem の実現規律へ照合する。対象 artifact 自体が存在しない確認だけを実行不能にし、folder 欠落を理由に領域全体を見送らない。
同じ source が複数の完了条件または禁止事項に当たる場合は、最初の違反だけで照合を止めず、該当する規律を全て確認する。指摘数を報告する場合は、重複排除後の列挙を数え、内訳と合計を一致させる。

## 報告

- 結論を先に置き、実施したモード、対象範囲、根拠にした root `README.md`、選択した process file、参照した規律、実測した検証、未確認事項を示す。
- 監査とレビューの指摘は、severity、対象 file と該当箇所、対応する標準の規律を添える。
- 監査の severity は `process/audit.md` の対応をそのまま使い、自己判断で引き上げない。
- 標準本文の引用は判定に必要な短い箇所だけにする。読了の証明として長文を複製しない。
- 実行できない検証は合格とせず、理由と実施した次善の確認を分けて書く。

## 関連

- `standard-update` — 標準本文の更新。
- `standard-audit` — 標準そのものの読み取り専用監査。
- `references/provenance.md` — 外部知見の出典記録。実行時には読まない。
