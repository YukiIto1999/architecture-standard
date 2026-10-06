# 検査の役割と model eval の範囲

`verify-test.sh` と `skill-package-check.sh` を実行した後、model eval の要否と範囲を決めるときに読む。

`skill-package-check.sh` は実作業へ公開する product 検査であり、frontmatter、5 skill の eval 定義、script 構文、conformance CLI の behavior tests を検査する。
`run-task-evals.mjs` が `SKILL_EVAL_ISOLATED_SKILL` と `SKILL_EVAL_CONFIGURATION` の有効な組を渡した隔離評価だけは、選択中 skill の隠された `evals/` を欠落としない。
configuration が `without-skill` なら、選択中 skill directory 全体の不存在だけを許可し、directory の一部が残る状態は失敗にする。
standard-conformance 自身の `without-skill` 隔離で、その package が完全に存在しない場合だけは同梱 behavior tests も実行対象から外す。
通常構成、他の skill の隔離、package の部分残存では、この例外を使わず、test file の欠落も失敗にする。
通常実行や片方だけの指定では、skill または eval 一式がなければ失敗する。
`skill-test.sh` は期待する解答と mutation を検査する外側の evaluator 回帰検査であり、評価対象 agent へ公開せず、実作業の完了条件にも使わない。

変更の種類に応じて model eval の範囲を決める。

- script の決定的な処理だけを変更し、agent への instruction を変えない場合は、回帰検査を行う。script が生成する prompt を変える場合は instruction の変更として扱う。
- SKILL.md または reference の instruction を変更した場合は、変更した判断を実際に必要とする task を `old-skill` と `with-skill` の2条件で隔離実行する。変更された file を監査対象に含むだけの task や、同じ skill を使うだけの task は選ばない。expectation、最終応答、tool event、diff、tracked / ignored status、実行 error、時間、token を比較する。新規 skill で旧版がない場合だけ `without-skill` を比較対象にする。
- `evals/evals.json` だけを変更した場合は、変更した task を `with-skill` で実行する。現行 instruction の不足が失敗として再現した後に instruction を変更し、その段階で `old-skill` と `with-skill` を比較する。
- description または `evals/trigger-evals.json` を変更した場合は、`scripts/run-trigger-evals.mjs` で `trigger-evals.json` の全 query を実行する。5 skill を同時に置いた条件で expected skill または非発火を測り、Skill tool の完全な入力、観測中の実行 error、発火先を記録する。
- release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較と full trigger eval の両方を行う。それ以外は変更面ごとの上記範囲に限定する。instruction と `evals/trigger-evals.json` の変更を組み合わせた場合は、影響 task の2条件比較と full trigger eval をそれぞれ行い、全 task や `without-skill` へ広げない。

task eval は本 task の完遂を、trigger eval は発火先だけを測る。起動成功を PASS とせず、別 context の grader が expectation ごとの成否と event または成果物の根拠を `grading.json` に残す。複数条件を比較した場合は、対象 task の集計を `benchmark.json` に残す。隔離 evaluator が実行できなければ model eval 完了とは扱わず、阻害要因を報告する。

## 隔離比較

`run-task-evals.mjs` は `--suite` で評価集合を選び、`--eval-id` に一件の ID または comma で区切った ID を渡して対象を絞れる。
`--baseline-ref` は fixture の標準本文を固定する commit、`--skill-snapshot` は比較する skill directory、`--context-readme` は両条件へ同じ内容で渡す root README を指定する。
保存した eval 定義を再利用するときは `--skill` と `--eval-file` を指定し、両条件へ同じ file を渡す。
旧版は変更開始前の Git commit または保存した snapshot から取得し、新版は instruction の変更が揃ってから別 directory へ保存する。
両条件の実行中に snapshot を変更しない。
root README 自身を同時に改訂する場合は、両条件へ同じ README snapshot を渡し、skill instruction の差と本文 context の差を混同しない。
ケースごとの期待結果、fixture の欠陥、採点情報は評価対象へ公開する reference に置かず、一時 repository の外側で管理する。

評価対象へ渡す task は `item.prompt` だけを使い、expectation、fixture mutation、grader は渡さない。
選択中 skill の `evals/` と外側の evaluator script を一時 repository と Git 履歴から除き、実作業の product 検査と一般の reference は残す。
standard-update の product 検査が使う conformance checker とその回帰検査は、全比較条件へ同じ source から配置し、`fixture_sha256` の対象に含める。
選択した Skill の本文だけを新しくした混在版でも検査の依存が欠けないようにし、検査機構の差を instruction の効果へ混ぜない。
`before-files.json` と `after-files.json` は評価に必要な本文と全変更 file の内容を持ち、`changed-files.json` は tracked、untracked、ignored の変更を列挙する。
`tool-evidence.json` は tool の完全な入力と結果を保存し、未実施の読取や検証を最終応答の主張だけで補わない。

standard-conformance の task では、host が `node skills/standard-conformance/scripts/check-coverage.mjs inventory` と `check` の prefix だけを Bash の追加許可へ渡す。
報告は `runRoot/audit-reports/report.json` へ保存し、fixture の Git root 外にあるその専用 directory だけを `--add-dir` と prompt で書込先に指定する。
評価対象へ採点情報や期待解答を渡さず、保存した報告は外側の `audit-reports.json` として tool 結果とともに grader へ渡す。
`command_args` は host へ渡した実入力を保持し、比較用の `command_contract_args` は報告専用 directory の割当だけを正規化する。
比較時は保存済みの正規化値を信用して raw command の差を隠さず、`command_args` から同じ正規化を再計算する。
これらの argument と artifact の schema 検査は、Claude の実 command policy の適用や model の完遂を証明しない。

`--grade` は実行直後に別 context の grader を起動し、`--grade-only` は保存済みの `eval_metadata.json` にある task と expectation で成果物を採点する。
現在の eval 定義を変えても、過去の成果物へ新しい rubric を適用しない。
改訂した task、fixture、rubric の測定は、過去の成果物とは別の output root で実行する。
grader は空の一時 directory で tools と skill を無効化して起動する。
各 expectation の成否と根拠、実際の task と rubric、grader の runner、instruction、schema、command 設定、指定 model と観測した model を `grading.json` へ残す。
実際に送った grader prompt は外側の `grader-prompt.txt` へ保存する。
両条件の採点が揃った時点で `benchmark.json` を生成し、実行条件と実採点の provenance が一致しない比較から品質の改善量を算出しない。
採点 provenance または実際の model の記録がない過去の結果は、比較可能としない。
時間、費用、token、tool call、tool error は品質と別に記録する。

次の command は、repository root から保存済みの二つの skill directory と共通 README を比較する入口である。
`EVAL_SUITE` と `EVAL_IDS` は今回の変更が必要とする集合とケースにし、`EVAL_OUTPUT_ROOT` と snapshot は host が割り当てた一時 directory または依頼で指定された保存先を使う。

```bash
SKILL_EVAL_OUTPUT_ROOT="$EVAL_OUTPUT_ROOT" \
  node .claude/skills/standard-update/scripts/run-task-evals.mjs \
  --configuration old-skill --skill standard-update \
  --suite "$EVAL_SUITE" --eval-id "$EVAL_IDS" \
  --eval-file "$EVAL_FILE" \
  --baseline-ref "$BASELINE_COMMIT" --skill-snapshot "$OLD_SKILL" \
  --context-readme "$CONTEXT_README" --grade
SKILL_EVAL_OUTPUT_ROOT="$EVAL_OUTPUT_ROOT" \
  node .claude/skills/standard-update/scripts/run-task-evals.mjs \
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
