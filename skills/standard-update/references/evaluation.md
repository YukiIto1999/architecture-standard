# 検査の役割と model eval の範囲

`verify-test.sh` と `skill-package-check.sh` を実行した後、model eval の要否と範囲を決めるときに読む。

`skill-package-check.sh` は実作業へ公開する product 検査であり、frontmatter、対象 Skill の eval 定義、script 構文、conformance CLI の behavior tests を検査する。
`run-task-evals.mjs` が有効な `SKILL_EVAL_ISOLATED_SKILL` と `SKILL_EVAL_CONFIGURATION` を渡す場合は、全 Skill の採点情報と非候補の instruction が非公開であることを検査する。
`without-skill` では選択した package 全体が存在しないことを要求し、部分残存を拒否する。
standard-conformance 自身の `without-skill` で package が存在しない場合だけ、その behavior tests を実行しない。
通常構成では全 package と eval 定義を要求し、隔離 context の片方だけの指定は拒否する。
`skill-test.sh` は期待する解答と mutation を検査する外側の evaluator 回帰検査であり、評価対象 agent へ公開せず、実作業の完了条件にも使わない。

同梱の `run-task-evals.mjs` と `run-trigger-evals.mjs` は OMP CLI を使う。
正本は `skills/<id>/` に置き、通常の配備は dotfiles-wsl が所有する。
評価 runner は、一時 fixture の `skills/` を OMP の `skills.customDirectories` へ指定する。
trigger eval は、隔離した候補の name、description、path から発火先を選ばせ、OMP の `read` が対象本文を正常に読み込んだ結果を観測する。
task eval は `skills/<id>/SKILL.md` を `read` で明示的に読み、方法と task の成果を測る。
評価専用 extension は、host の常時指示を固定した評価 policy と候補の metadata に置き換え、provider へ渡す tool schema と実行時の tool を許可集合へ限定する。
file 境界と Bash command は実行前に検査する。
この隔離評価は、通常の dotfiles-wsl 配備や OMP の自然発火を実測した証拠にはしない。

起動 command は `OMP_EVAL_COMMAND`、model は `OMP_EVAL_MODEL`、時間上限は `OMP_EVAL_TIMEOUT_MS` で指定できる。
未指定の command は `omp` とし、eval 定義の `model: "default"` は host の `modelRoles.default` で解決する。
明示した model selector を OMP へ渡し、model fallback と評価中の自動切替を無効にして、実際の provider と model を event から記録する。
host の認証はそのまま利用し、資格情報を fixture へ複製せず、認証設定も変更しない。

変更の種類に応じて model eval の範囲を決める。

- script の決定的な処理だけを変更し、agent への instruction を変えない場合は、回帰検査を行う。script が生成する prompt を変える場合は instruction の変更として扱う。
- SKILL.md または reference の instruction を変更した場合は、変更した判断を実際に必要とする task を `old-skill` と `with-skill` の2条件で隔離実行する。変更された file を監査対象に含むだけの task や、同じ skill を使うだけの task は選ばない。expectation、最終応答、tool event、diff、tracked / ignored status、実行 error、時間、token を比較する。新規 skill で旧版がない場合だけ `without-skill` を比較対象にする。
- `evals/evals.json` だけを変更した場合は、変更した task を `with-skill` で実行する。現行 instruction の不足が失敗として再現した後に instruction を変更し、その段階で `old-skill` と `with-skill` を比較する。
- description または `evals/trigger-evals.json` を変更した場合は、`scripts/run-trigger-evals.mjs` で全 query を実行する。
  evaluator の候補を同時に置き、expected skill または非発火を測り、`read` の完全な入力、本文の読み込み結果、観測中の実行 error、発火先を記録する。
  一回の runner 起動は各 query を一回ずつ新しい context で実行するため、発火の反復評価では runner を三回起動し、全回の結果を残す。
  非発火の成功には正常終了と terminal event を必要とし、timeout や選択した本文の読み込み失敗を非発火成功へ置き換えない。
- release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較と full trigger eval の両方を行う。それ以外は変更面ごとの上記範囲に限定する。instruction と `evals/trigger-evals.json` の変更を組み合わせた場合は、影響 task の2条件比較と full trigger eval をそれぞれ行い、全 task や `without-skill` へ広げない。

task eval は本 task の完遂を、trigger eval は発火先だけを測る。起動成功を PASS とせず、別 context の grader が expectation ごとの成否と event または成果物の根拠を `grading.json` に残す。複数条件を比較した場合は、対象 task の集計を `benchmark.json` に残す。隔離 evaluator が実行できなければ model eval 完了とは扱わず、阻害要因を報告する。

## 隔離比較

`run-task-evals.mjs` は `--suite` で評価集合を選び、`--eval-id` に一件の ID または comma で区切った ID を渡して対象を絞れる。
`--baseline-ref` は一時repositoryの出発点となるcommit、`--standard-snapshot` はroot READMEと六領域の本文snapshot、`--skill-snapshot` は比較するskill directory、`--context-readme` はroot READMEだけの共通差替えを指定する。
本文snapshotを先に適用し、選択Skillを次に配置し、指定があれば共通READMEを最後に差し替える。
本文snapshotはrootの `README.md` と `principles/`、`concerns/`、`structure/`、`tools/`、`languages/`、`process/` を持ち、出発点の全本文fileを含めなければprovider起動前に失敗する。
symlinkを含む本文snapshotは受け付けず、`standard-files.json` に実内容とfileごとのSHA-256、`standard_sha256` に全本文のdigestを保存する。
比較の同一性にはsnapshotの一時pathではなく、この実内容のdigestを使う。
`--baseline-ref` の commit は、既存の `standard-apply`、`standard-audit`、`standard-conformance`、`standard-feedback`、`standard-update` の `skills/<id>/SKILL.md` を含む client-neutral な配置でなければならない。
`cli-design` と `property-testing` は通常の task と trigger の選択対象に含み、基線に新設 package がなくても `without-skill` と `with-skill` を実行できる。
基線に選択 Skill がなく、過去の package snapshot も渡されていない `old-skill` は、`UNAVAILABLE_HISTORICAL_SKILL` と `historical-unavailable.json` に不存在を記録し、provider と grader を起動しない。
不存在を空の旧版や現行本文で代用せず、保存済みの不存在に対する `--grade-only` も採点しない。
保存した eval 定義を再利用するときは `--skill` と `--eval-file` を指定し、両条件へ同じ file を渡す。
旧版は変更開始前の Git commit または保存した snapshot から取得し、新版は instruction の変更が揃ってから別 directory へ保存する。
両条件の実行中に snapshot を変更しない。
root README 自身を同時に改訂する場合は、両条件へ同じ README snapshot を渡し、skill instruction の差と本文 context の差を混同しない。
ケースごとの期待結果、fixture の欠陥、採点情報は評価対象へ公開する reference に置かず、一時 repository の外側で管理する。

評価対象へ渡す task は `item.prompt` だけを使い、expectation、fixture mutation、grader は渡さない。
Skill の `evals/`、外側の evaluator script、`docs/minutes/`、`docs/decisions/`、`docs/reviews/`、`docs/research/` の履歴材料を、sanitized Git の初期化前に一時 repository から除く。
standard-update の eval-4 だけは、task の監査対象となる standard-audit の本文と、評価範囲を選ぶための task ID と prompt を入力資料として残す。
この資料を発火候補へ加えず、expectation と expected output は公開しない。
複製元の client 設定と `.mcp.json` も除き、複製元の hook や常時指示を実行条件へ混ぜない。
隔離した actor 用の package 検査は、公開した Skill の本文と frontmatter、非公開 instruction と採点情報の不在、全 package の directory、および conformance 検査の依存を検査する。
通常 checkout では全 Skill の本文と eval 定義を引き続き検査する。
実作業のproduct検査と一般のreferenceは残し、taskが必要とする対象projectのAcceptedな契約や決定は隔離後にhostが置く。
product 検査を instruction の効果へ混ぜないため、standard-update と standard-conformance の package checker は全比較条件へ同じ source から配置する。
standard-update の conformance checker と回帰検査、CLI と PBT の package も同様に配置し、これらを `fixture_sha256` の対象に含める。
CLI と PBT の task は prompt 内の設計入力を使い、既存 Skill 用の worker fixture、標準本文の mutation、標準 repository の検証 command を追加しない。
共通の本文 snapshot、README、task と model、target 入力は両条件へ同じものを渡す。
`before-files.json` と `after-files.json` は評価に必要な本文と全変更 file の内容を持ち、`changed-files.json` は tracked、untracked、ignored の変更を列挙する。
`target-input.json` は対象の全 source と test、および project 外の決定の記録を hash つきで保存し、`fixture_sha256` と `target_input_sha256` に入力の同一性を反映する。
`tool-evidence.json` は tool の完全な入力と結果を保存し、未実施の読取や検証を最終応答の主張だけで補わない。

standard-conformance の task では、host が `node skills/standard-conformance/scripts/check-coverage.mjs inventory` と `check` の prefix だけを Bash の追加許可へ渡す。
報告は `runRoot/audit-reports/report.json` へ保存し、fixture の Git root 外ではその file だけを extension policy と prompt で書込先として許可する。
評価対象へ採点情報や期待解答を渡さず、保存した報告は外側の `audit-reports.json` として tool 結果とともに grader へ渡す。
`command_args` は host へ渡した実入力を保持し、`command_contract_args` は一時 control、fixture、報告専用 directory の割当を正規化する。
その割当を `command_normalization` に保存し、比較時に `command_args` から同じ正規化を再計算する。
保存済みの正規化値との不一致や割当情報の欠落がある比較からは delta を生成しない。
argument と artifact の schema 検査だけでは、OMP の実行制限の適用や model の完遂を証明しない。
extension の制限は OS sandbox ではなく、許可した Bash command は host の権限と環境でコードを実行する。
fixture 外への副作用は防げないため、信頼できるローカル評価入力にだけ使う。

`--grade` は実行直後に別 context の grader を起動し、`--grade-only` は保存済みの `eval_metadata.json` にある task と expectation で成果物を採点する。
現在の eval 定義を変えても、過去の成果物へ新しい rubric を適用しない。
改訂した task、fixture、rubric の測定は、過去の成果物とは別の output root で実行する。
grader は空の一時 directory で tools と skill を無効化して起動する。
各 expectation の成否と根拠、実際の task と rubric、grader の runner、instruction、schema、command 設定、指定 model と観測した model を `grading.json` へ残す。
grader へ実際に送った user prompt は外側の `grader-prompt.txt` へ保存する。
両条件の採点が揃った時点で `benchmark.json` を生成し、本文、task定義、対象入力、runner、providerと実行設定、command契約、実model、採点provenanceが一致しない比較から品質の改善量を算出しない。
基線に新設 Skill がなく、明示的な過去の package snapshot による実行もない比較では、`comparison_configuration` を `without-skill` とし、`delta_with_minus_without` に差を残す。
この比較だけは、raw command を保持したまま、prompt 内の Skill 使用条件の一段落だけを比較用に正規化する。
それ以外の prompt、許可 tool、task、本文、target 入力、model、採点 provenance の差は従来どおり比較を不成立にする。
旧版がある比較は `old-skill` と `delta_with_minus_old` を使い、過去の測定結果を新設 Skill の評価へ読み替えない。
本文の改訂比較は、同じSkillを固定して本文条件ごとに別output rootの `with-skill` で実行し、規範改訂間の差を旧新版Skillの自動deltaへ入れない。
採点 provenance または実際の model の記録がない過去の結果は、比較可能としない。
時間、費用、token、tool call、tool error は品質と別に記録する。

次の command は、標準の作業 checkout の root から保存済みの二つの skill directory と共通 README を比較する入口である。
`EVAL_SUITE` と `EVAL_IDS` は今回の変更が必要とする集合とケースにし、`EVAL_OUTPUT_ROOT` と snapshot は host が割り当てた一時 directory または依頼で指定された保存先を使う。

```bash
SKILL_EVAL_OUTPUT_ROOT="$EVAL_OUTPUT_ROOT" \
  node skills/standard-update/scripts/run-task-evals.mjs \
  --configuration old-skill --skill standard-update \
  --suite "$EVAL_SUITE" --eval-id "$EVAL_IDS" \
  --eval-file "$EVAL_FILE" \
  --baseline-ref "$BASELINE_COMMIT" --skill-snapshot "$OLD_SKILL" \
  --context-readme "$CONTEXT_README" --grade
SKILL_EVAL_OUTPUT_ROOT="$EVAL_OUTPUT_ROOT" \
  node skills/standard-update/scripts/run-task-evals.mjs \
  --configuration with-skill --skill standard-update \
  --suite "$EVAL_SUITE" --eval-id "$EVAL_IDS" \
  --eval-file "$EVAL_FILE" \
  --baseline-ref "$BASELINE_COMMIT" --skill-snapshot "$NEW_SKILL" \
  --context-readme "$CONTEXT_README" --grade
```

reference や影響追跡の寄与を分けて測る場合は、新版から対象の file とその invocation を除いた独立 snapshot を作り、同じ fixture と grader で比較する。
この比較は本比較とは別の output root に置き、ablation を新版の成功結果へ混ぜない。
reference を消しただけで未解決 link や読取義務を残す状態は、寄与の比較として扱わない。
モデル、認証、tool 実行または必要な binary が利用できなければ、実行 error と不足する前提を報告する。
mock の harness 回帰検査を model eval の代替や改善の証拠にしない。

## 境界判断の評価

`standard-apply` のeval-7は関連本文のpathを明示して八例を読む条件、eval-8は対象の公開入口から必要な本文を自力で探す条件である。
どちらもA1からA4とB1からB4に、順応の記録だけで未検証wire入力を通す反例を加える。
期待値は `split-by-change-reason.md`、`context-relationships.md`、`information-hiding.md` と境界検証の直接参照先から導き、六領域の分類名の一致を採点しない。
本文pathを渡した条件の成功を探索能力の証拠にせず、読み取り、対象条件、意味判断、実検証を分ける。
既存のeval-6は、実caller、決定、authority、testへ進む探索の回帰として別に残す。

```bash
SKILL_EVAL_OUTPUT_ROOT="$BOUNDARY_OUTPUT" \
  node skills/standard-update/scripts/run-task-evals.mjs \
  --configuration with-skill --skill standard-apply \
  --suite semantic-boundaries --eval-id 7,8 \
  --baseline-ref "$BASELINE_COMMIT" --standard-snapshot "$STANDARD_SNAPSHOT" \
  --skill-snapshot "$SKILL_SNAPSHOT" --grade
```

本文効果を比較する場合は、上のcommandのSkill、task、model、runnerを固定し、`STANDARD_SNAPSHOT` と `BOUNDARY_OUTPUT` だけを本文条件に合わせる。
Skill効果を比較する場合は本文snapshotと対象入力を固定し、既存の `old-skill` と `with-skill` を使う。
同じ入力を独立した三回のsessionへ渡す場合は各pairに別output rootを割り当て、旧新版の順序を交互にし、個別の失敗や未完了も残す。
三回の反復は統計的な保証でも全判断の理解の証明でもない。

## 実行可能な格納fixture

eval-9とeval-10は明示的な `fixture.kind: line-store` を選び、それぞれ `stage: hide` と `stage: map` を使う。
kindを持たない従来taskは既存fixtureのまま実行でき、fixtureへ任意のpath、shell command、oracleを渡す設定はprovider起動前に拒否する。
正本は `skills/standard-apply/evals/fixtures/line-store/project/` であり、runnerは選択Skillのeval資材を隠した後、このprojectだけを `target-project/` に配置する。
`host/` の独立oracleは対象repositoryとそのGit履歴へコピーせず、外側のgraderだけへsourceと実出力を渡す。
このfixture固有のsource境界検査はproject全体の適合性検査ではない。

公開入口は `renderSelected(lines: readonly string[], positions: readonly number[])` であり、各要求の成功を `ts-results-es` の `Result<string, "position-out-of-range">` として返す。
整数位置を前提とし、追加順と重複を保持し、空状態、負の位置、行数以上の位置ではErrを返して状態を変えない。
eval-9ではLineStoreの内部配列を隠すcutoverのconsumer変更を認めるが、eval-10のtask1後の条件では `src/line-store.ts` 以外の全production sourceを入力と同一に保つ。
是正前のcanonical sourceでeval-10を実行する条件では、必要なconsumerのcutoverを認め、後続入力の条件と混ぜない。
いずれも格納の所有者とexported LineStore classを固定し、Mapを新たな公開契約へ漏らさない。

格納fixtureはmanifestとlockfileが定めるNode.js `>=24.21.0 <25` を必要とし、固定した依存の要求を満たすhostで実行する。
hostはprovider起動前に `npm --prefix target-project ci --ignore-scripts --no-audit --no-fund` を実行し、modelへ依存導入を要求しない。
actorのBash追加許可はrepository rootからの次の三つに限定し、任意のnpm、Node、Bashを許可しない。

```bash
npm --prefix target-project run check
npm --prefix target-project run verify
npm --prefix target-project run verify:push
```

hostの実検証は、actorのtestやmanifestやnode_modulesを使わず、正本projectを別の新規directoryへ置いて実sourceだけを復元する。
そこで次のcommandを使い、全commandのstdout、stderr、exit status、signal、error、時間を `host-before.json` と `host-after.json` に残す。
`HOST_PROJECT` はhostだけが割り当てるdirectoryであり、`HOST_BASE` は入力sourceを固定したそのrepositoryのcommitである。

```bash
npm --prefix "$HOST_PROJECT" ci --ignore-scripts --no-audit --no-fund
npm --prefix "$HOST_PROJECT" run verify
node skills/standard-apply/evals/fixtures/line-store/host/check.mjs "$HOST_PROJECT" --boundary hidden
npm --prefix "$HOST_PROJECT" run verify:push -- --base "$HOST_BASE"
```

変更前は最後のmutation検証を実行せず、canonical入力は振る舞いだけを、task1入力はhidden境界も検査する。
変更後のMap taskではoracleの `--boundary` を `map` にする。
T0のcheckは10秒、T1のverifyは2分、T2のverify:pushは15分を上限とし、依存導入とevaluatorとgraderの時間はprojectの各段の実測と区別する。
hostでは `verify` がT0も実行するため、同じsourceの `check` を直前に重ねない。
各commandが失敗したら後続の検証を実行せず、未実施を成功へ数えない。
変更と影響範囲の選択不能、生成0件、未検出mutant、test未実行、判定未完了、型・静的検査・固定test・独立oracleの失敗は合格にしない。
固定testなどの変更も不合格であり、actorが弱めたtestの成功でhostの検証を代替しない。
hostの棄却や実行不成立がある結果は、graderが全項目を合格としても `summary.passed` と `pass_rate` を0、`overall_pass` をfalseにする。
grader単体の判定件数は `grader_passed` に残し、実行と固定host検証の成立は `execution_valid` で区別する。
どちらかの実行が成立しない比較では、`delta_with_minus_old` を算出しない。

`canonical-project.json` はprojectとhost oracleの固定資材、`project-before.json` と `project-after.json` は対象の全source、固定test、manifest、lockfile、契約、検証入口の実内容とSHA-256を持つ。
`host-before-reports.json` と `host-after-reports.json` に検証reportとmutation reportを保存し、gateと `mutation/scope.json` の対象選択情報は `host-after.json` からgraderにも渡す。
`consumer-diff.patch` は追加されたuntracked sourceを含む境界外production sourceの実差分であり、変更file名だけで局所性を推定しない。
`node_modules/`、`.git/`、`.stryker-tmp/`、`reports/`、`coverage/` はsource snapshotに含めない。
変更入力があれば未変更consumerを含む全production sourceを生成対象にし、production以外の入力や削除、rename、untrackedな入力の影響も省略しない。
固定gateは実行不能な `CompileError` の除外を検出と分け、実行証拠の無い結果や根拠の無いtimeoutを不合格にする。
比較条件間でこの固定gate、test、sourceの同一性を保ち、actorによる固定資材の変更を対象範囲の拡張で正当化しない。

## 後続sourceの復元

eval-9の `project-snapshot.json` をeval-10の `--project-snapshot` に渡すと、新規contextへ実candidateの全production sourceを復元する。
snapshotはversion 1のline-store hide入力であり、全fileの内容とSHA-256、固定projectとhost oracleのdigest、payload全体のdigestを持つ。
全固定資材の一致と全sourceの存在を確認し、symlink、path traversal、内容とhashの不一致、契約やtestやmanifestやlockfileの改変、不完全なsnapshotをprovider起動前に拒否する。
task1の成功を最終応答から推定せず、復元後の入力にも実host検証を行い、不合格ならproviderを起動しない。
snapshotに含まれるtestや設定は復元せず、正本の固定資材を保持する。

```bash
SKILL_EVAL_OUTPUT_ROOT="$HIDE_OUTPUT" \
  node skills/standard-update/scripts/run-task-evals.mjs \
  --configuration with-skill --skill standard-apply --eval-id 9 \
  --baseline-ref "$BASELINE_COMMIT" --standard-snapshot "$STANDARD_SNAPSHOT" \
  --skill-snapshot "$SKILL_SNAPSHOT" --grade
SKILL_EVAL_OUTPUT_ROOT="$MAP_BEFORE_OUTPUT" \
  node skills/standard-update/scripts/run-task-evals.mjs \
  --configuration with-skill --skill standard-apply --eval-id 10 \
  --baseline-ref "$BASELINE_COMMIT" --standard-snapshot "$STANDARD_SNAPSHOT" \
  --skill-snapshot "$SKILL_SNAPSHOT" --grade
SKILL_EVAL_OUTPUT_ROOT="$MAP_AFTER_OUTPUT" \
  node skills/standard-update/scripts/run-task-evals.mjs \
  --configuration with-skill --skill standard-apply --eval-id 10 \
  --baseline-ref "$BASELINE_COMMIT" --standard-snapshot "$STANDARD_SNAPSHOT" \
  --skill-snapshot "$SKILL_SNAPSHOT" \
  --project-snapshot "$HIDE_OUTPUT/standard-apply/eval-9-default/with-skill/project-snapshot.json" --grade
```

是正前と是正後のMap taskは入力が異なるため、結果とconsumer変更理由を比較する観測であり、同じ入力によるSkill改善量ではない。
本文条件やtask1 candidateや実行設定が違う比較を、自動benchmarkの改善量へ混ぜない。
成功しても、この小さいfixtureの契約と変更影響に限る観測であり、実projectの品質向上や全般的な理解を主張しない。

## 回帰と実modelの入口

focused harnessは次の入口を使い、順序、重複、範囲、状態不変、公開collection漏出、source復元、consumer変更、固定test改変、unsafe入力を実oracleで検査する。
scripted providerは候補sourceを置く回帰用の入力であり、modelの理解や完遂の証拠にはしない。

```bash
bash skills/standard-update/scripts/skill-test.sh --line-store-only
node --test skills/standard-apply/evals/fixtures/line-store/host/mutation-gate.test.mjs
bash skills/standard-update/scripts/skill-test.sh
bash skills/standard-update/scripts/skill-package-check.sh
```

実 model smoke は上の eval-7、eval-8 と eval-9、eval-10 の command を OMP で実行し、task と grader の両 artifact を確認する。
model、認証、依存取得、実command policy、時間上限のどれかが成立しなければ、その失敗を残して未実行または不合格とし、回帰検査や説明で成功に置き換えない。
