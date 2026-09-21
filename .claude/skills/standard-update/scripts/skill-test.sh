#!/usr/bin/env bash
set -uo pipefail

required_commands=(bash git rg node mktemp mkdir ln timeout sed rm chmod sleep)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'FAIL: missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'FAIL: git repository で実行すること\n' >&2
  exit 1
}
cd "$REPO_ROOT" || exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0
PASSED=0

pass() {
  printf 'PASS: %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" | sed 's/^/  /'
  fi
  FAILED=$((FAILED + 1))
}

expect_text() {
  local label="$1"
  local pattern="$2"
  shift 2
  if rg -q "$pattern" "$@"; then pass "$label"; else fail "$label" "pattern: $pattern"; fi
}

expect_no_text() {
  local label="$1"
  local pattern="$2"
  shift 2
  if rg -q "$pattern" "$@"; then fail "$label" "unexpected pattern: $pattern"; else pass "$label"; fi
}

expect_line() {
  local label="$1"
  local line="$2"
  shift 2
  if rg -qF -x -- "$line" "$@"; then pass "$label"; else fail "$label" "line: $line"; fi
}

expect_eval_prompt_no_text() {
  local label="$1"
  local eval_id="$2"
  local pattern="$3"
  local eval_file="$4"
  if node -e '
    const fs = require("node:fs");
    const [file, id, pattern] = process.argv.slice(1);
    const item = JSON.parse(fs.readFileSync(file, "utf8")).evals.find((entry) => String(entry.id) === id);
    if (!item) process.exit(2);
    process.exit(new RegExp(pattern).test(item.prompt) ? 1 : 0);
  ' "$eval_file" "$eval_id" "$pattern"; then
    pass "$label"
  else
    fail "$label" "eval $eval_id prompt に含めない: $pattern"
  fi
}

expect_eval_prompt_text() {
  local label="$1"
  local eval_id="$2"
  local pattern="$3"
  local eval_file="$4"
  if node -e '
    const fs = require("node:fs");
    const [file, id, pattern] = process.argv.slice(1);
    const item = JSON.parse(fs.readFileSync(file, "utf8")).evals.find((entry) => String(entry.id) === id);
    if (!item) process.exit(2);
    process.exit(new RegExp(pattern).test(item.prompt) ? 0 : 1);
  ' "$eval_file" "$eval_id" "$pattern"; then
    pass "$label"
  else
    fail "$label" "eval $eval_id prompt に含める: $pattern"
  fi
}

printf '=== 1. skill の指示整合 ===\n'
expect_text \
  "recovery eval はGlob回数とpatternを採点する" \
  'Glob は target-project/\*\*/\* の一回だけ' \
  skills/standard-apply/evals/evals.json
expect_text \
  "recovery eval は決定の記録をGlob由来の読取候補にしない" \
  'docs/decisions.*Glob 由来の読取候補から除く' \
  skills/standard-apply/evals/evals.json
expect_text \
  "methods は一致した適用集合と双方向含意で同じ性質を判定する" \
  '同じ規範命題へ割り当てられ、そこから導いた非空の適用対象・入力集合が一致し、その集合の全要素で一方の合格が他方の合格を含意し、かつ逆方向も成り立つ' \
  structure/tests/methods.md
expect_text \
  "methods は自己申告の空集合を同じ性質にしない" \
  '各検証の自己申告から採らず、割り当て先である標準の要求と禁止事項が要求する全範囲から導く.*非空の集合を標準本文から定められなければ、同じ性質とは判定しない' \
  structure/tests/methods.md
expect_text \
  "methods は比較不能な検証を別の性質として残す" \
  '適用対象・入力集合が一致しない、一方が適用不能になる.*別の性質として両方を残す' \
  structure/tests/methods.md
expect_text \
  "methods は反例未発見だけで同じ性質にしない" \
  '反例をまだ見つけていないことだけを、同じ性質の根拠にしない' \
  structure/tests/methods.md
expect_text \
  "typescript は別metricを重複として無効化しない" \
  'cyclomatic complexity は cognitive complexity と別の性質であり、重複検証ではない.*必須の検証へ割り当てていないため' \
  tools/typescript/inspection.md
expect_eval_prompt_no_text \
  "無変更evalは不要な一次資料調査を指示しない" \
  3 \
  '一次資料' \
  .claude/skills/standard-update/evals/evals.json
expect_eval_prompt_no_text \
  "意味拡張evalは裁定名をpromptで与えない" \
  8 \
  '意味の拡張|意味を拡張|充足済みとせず' \
  .claude/skills/standard-update/evals/evals.json
expect_text \
  "文章refactor evalは同一性条件の自己充足を問う" \
  '二つの判定を同じ性質とみなす条件を標準本文だけから一意に導けるか' \
  .claude/skills/standard-update/evals/evals.json
expect_text \
  "Ponytail の一次資料を出典記録へ残す" \
  'Source: https://github\.com/DietrichGebert/ponytail/blob/main/skills/ponytail/SKILL\.md' \
  skills/standard-apply/references/provenance.md
expect_text \
  "Ponytail のlicenseを出典記録へ残す" \
  'License: MIT \(https://raw\.githubusercontent\.com/DietrichGebert/ponytail/main/LICENSE\)' \
  skills/standard-apply/references/provenance.md
expect_text \
  "Ponytail 由来の採用を出典記録へ残す" \
  '^\- Adopted:' \
  skills/standard-apply/references/provenance.md
expect_text \
  "Ponytail 由来の不採用を出典記録へ残す" \
  '^\- Rejected:' \
  skills/standard-apply/references/provenance.md

TEMP_BASE="${TMPDIR:-/tmp}"
TEMP_BASE="$(cd "$TEMP_BASE" 2>/dev/null && pwd -P)" || {
  fail "skill-test の一時ディレクトリを作成" "TMPDIR is unavailable"
  printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
  exit 1
}
TEST_ROOT=$(mktemp -d "$TEMP_BASE/architecture-standard-skill-test.XXXXXX") || {
  fail "skill-test の一時ディレクトリを作成" "mktemp -d failed"
  printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
  exit 1
}
case "$TEST_ROOT" in
  "$TEMP_BASE"/architecture-standard-skill-test.*) ;;
  *)
    fail "skill-test の一時ディレクトリを作成" "unsafe temporary directory: $TEST_ROOT"
    exit 1
    ;;
esac
cleanup() {
  case "$TEST_ROOT" in
    "$TEMP_BASE"/architecture-standard-skill-test.*)
      [ ! -e "$TEST_ROOT" ] || rm -rf -- "$TEST_ROOT"
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

printf '\n=== 2. task eval と trigger eval の schema ===\n'
eval_output=$(bash "$SCRIPT_DIR/skill-package-check.sh" 2>&1)
if [ "$?" -eq 0 ]; then
  printf '%s\n' "$eval_output"
  pass "5 skill の package 構造と eval schema が有効"
else
  fail "5 skill の package 構造または eval schema が無効" "$eval_output"
fi
package_fixture="$TEST_ROOT/package-missing-evals"
mkdir -p "$package_fixture" || fail "package checker fixture を構築" "mkdir failed"
cp -a .claude skills "$package_fixture/" || fail "package checker fixture を構築" "copy failed"
git -C "$package_fixture" init --quiet || fail "package checker fixture を構築" "git init failed"
rm -rf -- "$package_fixture/skills/standard-apply/evals"
if package_missing_output=$(cd "$package_fixture" && bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "通常実行ではskillのeval一式欠落を拒否する" "$package_missing_output"
elif ! printf '%s\n' "$package_missing_output" | rg -qF 'standard-apply: evals directory がない'; then
  fail "eval一式欠落を具体的に診断する" "$package_missing_output"
else
  pass "通常実行ではskillのeval一式欠落を拒否する"
fi
if package_isolated_output=$(cd "$package_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=with-skill bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  pass "隔離評価では選択skillの隠したevalだけを許可する"
else
  fail "隔離評価では選択skillの隠したevalだけを許可する" "$package_isolated_output"
fi
if package_partial_context=$(cd "$package_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "不完全な隔離contextでeval欠落を許可しない" "$package_partial_context"
else
  pass "不完全な隔離contextでeval欠落を許可しない"
fi
package_without_fixture="$TEST_ROOT/package-without-skill"
mkdir -p "$package_without_fixture" || fail "without-skill package fixture を構築" "mkdir failed"
cp -a .claude skills "$package_without_fixture/" || fail "without-skill package fixture を構築" "copy failed"
git -C "$package_without_fixture" init --quiet || fail "without-skill package fixture を構築" "git init failed"
rm -rf -- "$package_without_fixture/skills/standard-apply"
if package_without_output=$(cd "$package_without_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=without-skill bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  pass "without-skill隔離評価では選択packageだけの不存在を許可する"
else
  fail "without-skill隔離評価では選択packageだけの不存在を許可する" "$package_without_output"
fi
package_partial_fixture="$TEST_ROOT/package-partial-without-skill"
mkdir -p "$package_partial_fixture" || fail "partial without-skill package fixture を構築" "mkdir failed"
cp -a .claude skills "$package_partial_fixture/" || fail "partial without-skill package fixture を構築" "copy failed"
git -C "$package_partial_fixture" init --quiet || fail "partial without-skill package fixture を構築" "git init failed"
rm -f -- "$package_partial_fixture/skills/standard-apply/SKILL.md"
if package_partial_output=$(cd "$package_partial_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=without-skill bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "without-skill隔離評価では選択packageの部分残存を拒否する" "$package_partial_output"
else
  pass "without-skill隔離評価では選択packageの部分残存を拒否する"
fi
unexpected_fixture_typo='情報の'"概観"
expect_no_text \
  "task fixture の誤字を evaluator 自身へ露出しない" \
  "$unexpected_fixture_typo" \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator は全 task へ full verifier を強制しない" \
  '^      "検証は repository root から' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は変更と skill 契約が要求する場合だけ検証入口を示す" \
  'task が file を変更し.*skill が検証を要求する場合' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator はexact path routingをoracleとして注入しない" \
  'task または使用する skill が exact file path を固定した場合は Read で直接読み' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator はsnapshotのexact diff解法をoracleとして注入しない" \
  '根拠に使う exact file path だけを git diff の引数にし' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はrouting判断をtaskと対象skillへ委ねる" \
  'どれを使うかは task と、with-skill または old-skill では対象 skill の指示から判断' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はskillの最初の対象project操作を共通promptで上書きしない" \
  '対象 skill が最初の対象 project 操作または閉じた参照経路を定める場合は、他の対象 project 操作より優先' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は固定patternの試行錯誤を許さない" \
  'exact path、exact token、Glob pattern、回数を固定した場合は、その値を変えた試行や候補探索を前後に追加しない' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は一時的な ENOTEMPTY を再試行してfixtureを回収する" \
  'rmSync\(fixtureRoot, \{ recursive: true, force: true, maxRetries: [1-9][0-9]*, retryDelay: [1-9][0-9]* \}\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はsubagentなしの自己監査fallbackを明示する" \
  'skill が独立 reviewer を明示的に要求する場合だけ.*scoped self-audit' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はfallbackで閉じた経路を広げない" \
  '閉じた経路が tool または file を制限する場合は fallback でもその範囲を広げない' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は実行中のskillから評価oracleを隠す" \
  'hideCurrentSkillEvaluationOracles\(fixtureRoot, skillName\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はfixtureからskill assertion oracleを隠す" \
  '"standard-update", "scripts", "skill-test.sh"' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator はagentへskill-test実行を許可しない" \
  'Bash\(bash \.claude/skills/standard-update/scripts/skill-test\.sh\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はagentへproduct検査の実行を許可する" \
  'Bash\(bash \.claude/skills/standard-update/scripts/skill-package-check\.sh\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はproduct検査へ選択skillを明示する" \
  'env\.SKILL_EVAL_ISOLATED_SKILL = skillName' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はproduct検査へ比較条件を明示する" \
  'env\.SKILL_EVAL_CONFIGURATION = configuration' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_line \
  "task evaluator は全skillのfixtureからmutation sourceを除く" \
  '    scrubFixtureMutationSource(fixtureRoot);' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "recovery eval はcallerをfixtureへ持つ" \
  'writeFileSync\(path.join\(targetRoot, "app", "api.rs"\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "recovery eval はstateをfixtureへ持つ" \
  'writeFileSync\(path.join\(targetRoot, "app", "state.rs"\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "recovery fixture はtest rootをmanifestで明示する" \
  'source root は `app/`、test root は `tests/`' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_eval_prompt_text \
  "recovery eval はユーザー仮説をKnownから分離して測る" \
  5 \
  'worker\.rs.*JobStatus.*writer.*仮説.*確認済みの仕様ではありません' \
  skills/standard-apply/evals/evals.json
expect_text \
  "recovery eval はユーザー仮説をAssumedとして採点する" \
  '根拠付き仮説を Assumed とし、Known、Observed、Intended のいずれにも読み替えない' \
  skills/standard-apply/evals/evals.json
expect_text \
  "task evaluator は履歴をsanitizeしてからfixtureを作る" \
  'initializeSanitizedRepository\(fixtureRoot\);' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はclone元のGit objectを破棄する" \
  'rmSync\(path.join\(fixtureRoot, "\.git"\).*maxRetries:' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task fixture の決定の記録は現在の標準本文を基準にする" \
  '準拠の基準は、常に現在の標準本文である。' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task fixture は標準の commit を記録しない" \
  'standard_commit' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_line \
  "task evaluator はAgent toolを明示的に禁止する" \
  '      "Agent",' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs

printf '\n=== 3. verifier は依存不足で fail closed ===\n'
make_limited_path() {
  local omitted="$1"
  local target="$2"
  local command_name
  local command_path
  local commands=(bash git rg fd awk sed find wc tr head tail sort diff dirname paste basename cut node)

  mkdir -p "$target" || return 1
  for command_name in "${commands[@]}"; do
    [ "$command_name" = "$omitted" ] && continue
    command_path=$(command -v "$command_name") || return 1
    ln -s "$command_path" "$target/$command_name" || return 1
  done
}

BASH_PATH=$(command -v bash)

for missing_command in node fd; do
  limited_path="$TEST_ROOT/path-without-$missing_command"
  if ! make_limited_path "$missing_command" "$limited_path"; then
    fail "$missing_command 欠落fixtureを構築" "limited PATH setup failed"
    continue
  fi
  if dependency_output=$(PATH="$limited_path" "$BASH_PATH" "$SCRIPT_DIR/verify.sh" 2>&1); then
    fail "$missing_command がない場合は verifier が失敗する" "verify.sh がPASSした\n$dependency_output"
  elif ! printf '%s\n' "$dependency_output" | rg -qF "missing required command: $missing_command"; then
    fail "$missing_command 欠落を具体的に診断する" "$dependency_output"
  else
    pass "$missing_command 欠落で fail closed"
  fi
done

printf '\n=== 4. verify-test は mktemp 失敗時に何も作らない ===\n'
mktemp_probe=$(timeout 10 "$BASH_PATH" -c '
  mktemp() { return 1; }
  mkdir() { return 91; }
  cp() { return 92; }
  sed() { return 93; }
  rm() { return 94; }
  export -f mktemp mkdir cp sed rm
  bash "$1"
' probe "$SCRIPT_DIR/verify-test.sh" 2>&1)
mktemp_status=$?
if [ "$mktemp_status" -eq 0 ]; then
  fail "mktemp 失敗時は verify-test が失敗する" "$mktemp_probe"
elif ! printf '%s\n' "$mktemp_probe" | rg -qF "一時ディレクトリを作成できない"; then
  fail "mktemp 失敗を具体的に診断する" "$mktemp_probe"
else
  pass "mktemp 失敗で即時終了"
fi

expect_text \
  "trigger evaluator はtaskを実行せずroutingだけを測る" \
  'これは Skill の発火先だけを測る隔離評価です。依頼そのものは実行しないでください' \
  .claude/skills/standard-update/scripts/run-trigger-evals.mjs

printf '\n=== 5. trigger evaluator は発火とtask完遂を分離する ===\n'
for failure_mode in nonzero malformed result-error; do
  fake_claude="$TEST_ROOT/claude-$failure_mode"
  case "$failure_mode" in
    nonzero)
      printf '%s\n' '#!/usr/bin/env bash' 'exit 7' > "$fake_claude"
      expected_error='exit=7'
      timeout_ms=1000
      ;;
    malformed)
      printf '%s\n' '#!/usr/bin/env bash' 'printf '\''not-json\\n'\''' > "$fake_claude"
      expected_error='malformed stream-json event'
      timeout_ms=1000
      ;;
    result-error)
      printf '%s\n' '#!/usr/bin/env bash' 'printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"injected error"}'\''' > "$fake_claude"
      expected_error='result error: injected error'
      timeout_ms=1000
      ;;
  esac
  chmod +x "$fake_claude" || {
    fail "$failure_mode fixture を構築" "chmod failed"
    continue
  }
  if trigger_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_claude" CLAUDE_EVAL_TIMEOUT_MS="$timeout_ms" node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
    fail "$failure_mode を発火評価の非発火 PASS にしない" "$trigger_output"
  elif ! printf '%s\n' "$trigger_output" | rg -qF "$expected_error"; then
    fail "$failure_mode を具体的に診断する" "$trigger_output"
  else
    pass "$failure_mode は発火評価 error"
  fi
done

fake_malformed_hang="$TEST_ROOT/claude-malformed-hang"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{not-json}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_malformed_hang"
chmod +x "$fake_malformed_hang" || fail "malformed-hang fixture を構築" "chmod failed"
if malformed_hang_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_malformed_hang" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  fail "壊れた stream-json を非発火成功にしない" "$malformed_hang_output"
elif ! printf '%s\n' "$malformed_hang_output" | rg -qF 'malformed stream-json event'; then
  fail "壊れた stream-json を具体的に診断する" "$malformed_hang_output"
else
  pass "壊れた stream-json は観測窓終了後も評価 error"
fi

fake_truncated_hang="$TEST_ROOT/claude-truncated-hang"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s'\'' '\''{"type":"assistant"'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_truncated_hang"
chmod +x "$fake_truncated_hang" || fail "truncated-hang fixture を構築" "chmod failed"
if truncated_hang_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_truncated_hang" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  fail "改行なしの壊れた stream-json を非発火成功にしない" "$truncated_hang_output"
elif ! printf '%s\n' "$truncated_hang_output" | rg -qF 'malformed stream-json event'; then
  fail "改行なしの壊れた stream-json を具体的に診断する" "$truncated_hang_output"
else
  pass "改行なしの壊れた stream-json は評価 error"
fi

fake_observation_window="$TEST_ROOT/claude-observation-window"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_observation_window"
chmod +x "$fake_observation_window" || fail "observation-window fixture を構築" "chmod failed"
if observation_negative_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_observation_window" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  pass "観測窓内に Skill がなければ非発火期待を完遂待ちなしで記録"
else
  fail "観測窓内に Skill がなければ非発火期待を完遂待ちなしで記録" "$observation_negative_output"
fi
if observation_positive_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_observation_window" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "観測窓内に Skill がなければ発火期待を失敗にする" "$observation_positive_output"
elif printf '%s\n' "$observation_positive_output" | rg -qF 'error=timeout'; then
  fail "発火先不一致とtask timeoutを混同しない" "$observation_positive_output"
else
  pass "観測窓内に Skill がなければ発火先不一致"
fi

fake_skill_after_observation="$TEST_ROOT/claude-skill-after-observation"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'process.on("SIGTERM", () => {' \
  '  console.log(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "skill-1", name: "Skill", input: { skill: "standard-apply" } }] } }));' \
  '  setTimeout(() => process.exit(143), 20);' \
  '});' \
  'setInterval(() => {}, 1000);' > "$fake_skill_after_observation"
chmod +x "$fake_skill_after_observation" || fail "skill-after-observation fixture を構築" "chmod failed"
if skill_after_observation_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_skill_after_observation" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "観測窓終了後の Skill を発火成功にしない" "$skill_after_observation_output"
elif printf '%s\n' "$skill_after_observation_output" | rg -q 'selected=standard-apply|"selected_skill": "standard-apply"'; then
  fail "観測窓終了後の Skill を選択結果へ混入しない" "$skill_after_observation_output"
else
  pass "観測窓終了後の Skill は発火結果へ混入しない"
fi

fake_direct_read="$TEST_ROOT/claude-direct-read"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"/tmp/fixture/skills/standard-apply/SKILL.md"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_direct_read"
chmod +x "$fake_direct_read" || fail "direct Read fixture を構築" "chmod failed"
if direct_read_output=$(CLAUDE_EVAL_COMMAND="$fake_direct_read" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 13 2>&1); then
  pass "対象 SKILL.md の直接 Read を skill 選択として扱わない"
else
  fail "対象 SKILL.md の直接 Read を skill 選択として扱わない" "$direct_read_output"
fi

fake_competing_read="$TEST_ROOT/claude-competing-read"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"README.md"}}]}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_competing_read"
chmod +x "$fake_competing_read" || fail "competing Read fixture を構築" "chmod failed"
if competing_read_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_competing_read" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "発火期待で先に調査toolを選んだ場合は失敗にする" "$competing_read_output"
elif [ "$?" -eq 124 ] || printf '%s\n' "$competing_read_output" | rg -qF 'error=timeout'; then
  fail "先行した調査toolを観測窓終了まで待たない" "$competing_read_output"
else
  pass "発火期待で先行した調査toolを発火先不一致にする"
fi

fake_late_skill="$TEST_ROOT/claude-late-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"README.md"}},{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_late_skill"
chmod +x "$fake_late_skill" || fail "late Skill fixture を構築" "chmod failed"
if late_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_late_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "調査toolの後からSkillを選んでも発火順序を満たさない" "$late_skill_output"
elif ! printf '%s\n' "$late_skill_output" | rg -qF 'Skill selected after competing tool: Read'; then
  fail "遅延したSkill選択を具体的に診断する" "$late_skill_output"
else
  pass "調査toolより後のSkill選択は発火順序違反"
fi

fake_other_skill="$TEST_ROOT/claude-other-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"ja-writing"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_other_skill"
chmod +x "$fake_other_skill" || fail "other Skill fixture を構築" "chmod failed"
if other_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_other_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 13 2>&1); then
  pass "対象外のskillは5 skillの誤発火に数えない"
else
  fail "対象外のskillは5 skillの誤発火に数えない" "$other_skill_output"
fi

fake_exact_skill="$TEST_ROOT/claude-exact-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_exact_skill"
chmod +x "$fake_exact_skill" || fail "exact Skill fixture を構築" "chmod failed"
if exact_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_exact_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "正確な Skill 選択と正常終了を発火として記録"
else
  fail "正確な Skill 選択と正常終了を発火として記録" "$exact_skill_output"
fi

fake_skill_clean_exit="$TEST_ROOT/claude-skill-clean-exit"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' > "$fake_skill_clean_exit"
chmod +x "$fake_skill_clean_exit" || fail "skill clean-exit fixture を構築" "chmod failed"
if skill_clean_exit_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_clean_exit" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 入力の観測とprocess回収成否を分離"
else
  fail "Skill 入力の観測とprocess回収成否を分離" "$skill_clean_exit_output"
fi

fake_skill_permission="$TEST_ROOT/claude-skill-permission"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'skill_allowed=false' \
  'previous=' \
  'for arg in "$@"; do' \
  '  [ "$previous" = "--allowedTools" ] && [ "$arg" = "Skill" ] && skill_allowed=true' \
  '  previous="$arg"' \
  'done' \
  '$skill_allowed || {' \
  '  printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true}'\''' \
  '  exit 1' \
  '}' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_skill_permission"
chmod +x "$fake_skill_permission" || fail "Skill permission fixture を構築" "chmod failed"
if skill_permission_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_permission" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "headless plan mode でも Skill tool を明示許可"
else
  fail "headless plan mode でも Skill tool を明示許可" "$skill_permission_output"
fi

fake_skill_selection_only="$TEST_ROOT/claude-skill-selection-only"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'exit 0' > "$fake_skill_selection_only"
chmod +x "$fake_skill_selection_only" || fail "selection-only fixture を構築" "chmod failed"
if skill_selection_only_output=$(timeout 8 env CLAUDE_EVAL_COMMAND="$fake_skill_selection_only" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択確定後は task 完了を待たず process group を回収"
else
  fail "Skill 選択確定後は task 完了を待たず process group を回収" "$skill_selection_only_output"
fi

fake_skill_then_result_error="$TEST_ROOT/claude-skill-then-result-error"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'sleep 0.1' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"injected after selection"}'\''' > "$fake_skill_then_result_error"
chmod +x "$fake_skill_then_result_error" || fail "selection result-error fixture を構築" "chmod failed"
if skill_then_result_error_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_then_result_error" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後のtask errorを発火評価へ混ぜない"
else
  fail "Skill 選択時点で発火結果を確定する" "$skill_then_result_error_output"
fi

fake_skill_runner_termination_result="$TEST_ROOT/claude-skill-runner-termination-result"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'process.on("SIGTERM", () => {' \
  '  console.log(JSON.stringify({ type: "result", is_error: true }));' \
  '  setTimeout(() => process.exit(143), 100);' \
  '});' \
  'console.log(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "skill-1", name: "Skill", input: { skill: "standard-apply" } }] } }));' \
  'setInterval(() => {}, 1000);' > "$fake_skill_runner_termination_result"
chmod +x "$fake_skill_runner_termination_result" || fail "runner termination result fixture を構築" "chmod failed"
if skill_runner_termination_result_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_skill_runner_termination_result" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後に runner 自身が生じさせた result error は発火失敗にしない"
else
  fail "Skill 選択後に runner 自身が生じさせた result error は発火失敗にしない" "$skill_runner_termination_result_output"
fi

fake_skill_runner_malformed="$TEST_ROOT/claude-skill-runner-malformed"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'process.on("SIGTERM", () => {' \
  '  console.log("not-json");' \
  '  setTimeout(() => process.exit(143), 100);' \
  '});' \
  'console.log(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "skill-1", name: "Skill", input: { skill: "standard-apply" } }] } }));' \
  'setInterval(() => {}, 1000);' > "$fake_skill_runner_malformed"
chmod +x "$fake_skill_runner_malformed" || fail "runner malformed fixture を構築" "chmod failed"
if skill_runner_malformed_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_skill_runner_malformed" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後の壊れた出力は確定済み発火を変えない"
else
  fail "Skill 選択後の壊れた出力は確定済み発火を変えない" "$skill_runner_malformed_output"
fi

fake_partial_skill="$TEST_ROOT/claude-partial-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply-extra"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_partial_skill"
chmod +x "$fake_partial_skill" || fail "partial Skill fixture を構築" "chmod failed"
if partial_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_partial_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "部分一致の skill 名を発火として扱わない" "$partial_skill_output"
elif ! printf '%s\n' "$partial_skill_output" | rg -qF 'Skill tool called with an unrecognized standard skill: standard-apply-extra'; then
  fail "部分一致の skill 名を具体的に診断する" "$partial_skill_output"
else
  pass "部分一致の skill 名は発火評価 error"
fi

fake_skill_exit_error="$TEST_ROOT/claude-skill-exit-error"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'sleep 0.1' \
  'exit 7' > "$fake_skill_exit_error"
chmod +x "$fake_skill_exit_error" || fail "skill abnormal-exit fixture を構築" "chmod failed"
if skill_exit_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_exit_error" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後のtask終了を発火評価へ混ぜない"
else
  fail "Skill 選択時点で異常終了との観測境界を閉じる" "$skill_exit_output"
fi

fake_skill_exit_143="$TEST_ROOT/claude-skill-exit-143"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 143'\'' TERM' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' \
  'sleep 0.3' > "$fake_skill_exit_143"
chmod +x "$fake_skill_exit_143" || fail "skill exit 143 fixture を構築" "chmod failed"
if skill_exit_143_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_exit_143" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "runner の SIGTERM による exit 143 を発火成功として扱う"
else
  fail "runner の SIGTERM による exit 143 を発火成功として扱う" "$skill_exit_143_output"
fi

printf '\n=== 6. task evaluator は terminal result 後の hook hang を回収する ===\n'
fake_task_harness_probe="$TEST_ROOT/claude-task-harness-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'trigger_runner=.claude/skills/standard-update/scripts/run-trigger-evals.mjs' \
  'skill_oracle=.claude/skills/standard-update/scripts/skill-test.sh' \
  'product_check=.claude/skills/standard-update/scripts/skill-package-check.sh' \
  'if [ "$SKILL_EVAL_ISOLATED_SKILL" = standard-apply ]; then skill_root=skills/standard-apply; else skill_root=.claude/skills/$SKILL_EVAL_ISOLATED_SKILL; fi' \
  'eval_root=$skill_root/evals' \
  'task_oracle=$eval_root/evals.json' \
  'trigger_oracle=$eval_root/trigger-evals.json' \
  'unexpected='\''情報の'\''"概観"' \
  'leaks=$(rg -lF "$unexpected" . | rg -v '\''^(\./)?principles/README\.md$'\'' || true)' \
  'if git show HEAD^:"$task_oracle" >/dev/null 2>&1 || git show HEAD^:"$trigger_oracle" >/dev/null 2>&1 || git show HEAD^:"$runner" >/dev/null 2>&1 || git show HEAD^:"$trigger_runner" >/dev/null 2>&1 || git show HEAD^:"$skill_oracle" >/dev/null 2>&1; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation oracle or mutation is reachable from history"}'\''' \
  'elif [ "$SKILL_EVAL_CONFIGURATION" = without-skill ] && [ -e "$skill_root" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"selected skill package remains in without-skill fixture"}'\''' \
  'elif [ -e "$eval_root" ] || [ -e "$runner" ] || [ -e "$trigger_runner" ] || [ -e "$skill_oracle" ] || [ -n "$leaks" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation harness leaked into fixture"}'\''' \
  'elif [ -e "$product_check" ] && ! bash "$product_check" >/dev/null; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"product checker rejected isolated fixture"}'\''' \
  'elif [ "$SKILL_EVAL_ISOLATED_SKILL" = standard-update ] && [ "$SKILL_EVAL_CONFIGURATION" = with-skill ] && [ ! -e "$product_check" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"with-skill fixture lacks product checker"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_task_harness_probe"
chmod +x "$fake_task_harness_probe" || fail "task harness probe fixture を構築" "chmod failed"
for probe_skill in standard-apply standard-audit standard-conformance standard-feedback standard-update; do
  for eval_configuration in with-skill old-skill without-skill; do
    if task_harness_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_task_harness_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-harness-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill "$probe_skill" --eval-id 1 2>&1) \
      && ! rg -q '"is_error": true' "$TEST_ROOT/task-harness-probe-evals/$probe_skill/eval-1-haiku/$eval_configuration/result.json"; then
      pass "$probe_skill/$eval_configuration のtask fixtureからmutationを隔離"
    else
      fail "$probe_skill/$eval_configuration のtask fixtureからmutationを隔離" "$task_harness_probe_output"
    fi
  done
done

fake_audit_mutation_probe="$TEST_ROOT/claude-audit-mutation-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'expected='\''要求された機能範囲、受入条件、必須規律、安全性、互換性、必要な検証は妥協なく作り切ります。'\''' \
  'injected='\''要求された範囲は、必要な品質を適切に満たします。'\''' \
  'diff_files=$(git diff --name-only)' \
  'eval_status=$(git status --short --untracked-files=all -- .claude/skills/standard-audit/evals)' \
  'if [ "$diff_files" != "principles/README.md" ] || ! rg -qF "$injected" principles/README.md; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"audit mutation missing or escaped its target"}'\''' \
  'elif [ -e "$runner" ] || [ -n "$eval_status" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"audit mutation or oracle leaked into fixture"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_audit_mutation_probe"
chmod +x "$fake_audit_mutation_probe" || fail "audit mutation probe fixture を構築" "chmod failed"
for eval_configuration in with-skill old-skill without-skill; do
  if audit_mutation_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_audit_mutation_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/audit-mutation-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-audit --eval-id 4 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/audit-mutation-probe-evals/standard-audit/eval-4-sonnet/$eval_configuration/result.json"; then
    pass "$eval_configuration のaudit fixtureからmutationとoracleを隔離"
  else
    fail "$eval_configuration のaudit fixtureからmutationとoracleを隔離" "$audit_mutation_probe_output"
  fi
done

fake_eval_scope_probe="$TEST_ROOT/claude-eval-scope-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'scope_diff=$(git diff -- .claude/skills/standard-audit/SKILL.md)' \
  'diff_files=$(git diff --name-only)' \
  'eval_status=$(git status --short --untracked-files=all -- .claude/skills/standard-update/evals)' \
  'eval_ignored_status=$(git status --short --ignored=matching -- .claude/skills/standard-update/evals)' \
  'if [ "$diff_files" != ".claude/skills/standard-audit/SKILL.md" ] || ! rg -qF '\''+- **A 思想の足場**: root `README.md`'\'' <<< "$scope_diff"; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"instruction-only fixture diff missing"}'\''' \
  'elif [ -e "$runner" ] || [ -n "$eval_status" ] || [ -n "$eval_ignored_status" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation scope fixture leaked into runner"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_eval_scope_probe"
chmod +x "$fake_eval_scope_probe" || fail "evaluation scope fixture を構築" "chmod failed"
for eval_configuration in old-skill with-skill; do
  if eval_scope_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_eval_scope_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/eval-scope-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-update --eval-id 4 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/eval-scope-probe-evals/standard-update/eval-4-haiku/$eval_configuration/result.json"; then
    pass "$eval_configuration の評価範囲fixtureをdiffだけで提示"
  else
    eval_scope_result="$TEST_ROOT/eval-scope-probe-evals/standard-update/eval-4-haiku/$eval_configuration/result.json"
    fail "$eval_configuration の評価範囲fixtureをdiffだけで提示" "$eval_scope_probe_output
$(sed -n '1,80p' "$eval_scope_result" 2>/dev/null)"
  fi
done

fake_example_mutation_probe="$TEST_ROOT/claude-example-mutation-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'diff_files=$(git diff --name-only)' \
  'if [ "$diff_files" = "concerns/transaction/invisible-partial-commits.md" ] && rg -qF "// 二つ目の失敗を無視して成功を返す" concerns/transaction/invisible-partial-commits.md; then' \
  '  : ' \
  'elif [ "$diff_files" = "principles/comment/declaration-contracts.md" ] && [ "$(rg -cF "/** 素数かどうかを判定する。 */" principles/comment/declaration-contracts.md)" -eq 2 ] && ! rg -qF "@param candidate" principles/comment/declaration-contracts.md; then' \
  '  : ' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"example mutation missing or escaped its target"}'\''' \
  '  exit 0' \
  'fi' \
  'if [ -e "$runner" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"example mutation source leaked into fixture"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_example_mutation_probe"
chmod +x "$fake_example_mutation_probe" || fail "example mutation probe fixture を構築" "chmod failed"
for eval_id in 5 6; do
  if example_mutation_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_example_mutation_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/example-mutation-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-update --eval-id "$eval_id" 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/example-mutation-probe-evals/standard-update/eval-$eval_id-sonnet/with-skill/result.json"; then
    pass "eval-$eval_id は対象1ファイルへ欠陥を注入して mutation source を隔離"
  else
    example_mutation_result="$TEST_ROOT/example-mutation-probe-evals/standard-update/eval-$eval_id-sonnet/with-skill/result.json"
    fail "eval-$eval_id の欠陥注入と mutation source 隔離を検査" "$example_mutation_probe_output
$(sed -n '1,80p' "$example_mutation_result" 2>/dev/null)"
  fi
done

fake_task_claude="$TEST_ROOT/claude-task-result"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_task_claude"
if ! chmod +x "$fake_task_claude"; then
  fail "task evaluator fixture を構築" "chmod failed"
elif task_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_task_claude" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  task_timing="$TEST_ROOT/task-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ ! -f "$task_timing" ]; then
    fail "task evaluator が timing artifact を保存する" "$task_output"
  elif ! node -e 'const value=JSON.parse(require("node:fs").readFileSync(process.argv[1],"utf8")); process.exit(value.terminal_result_received === true && value.terminated_after_result === true ? 0 : 1)' "$task_timing"; then
    fail "terminal result 後の process を回収する" "$(sed -n '1,120p' "$task_timing")"
  else
    pass "terminal result 後の hook hang を成功として回収"
  fi
else
  task_timing="$TEST_ROOT/task-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_timing" ]; then
    task_output="$task_output
$(sed -n '1,120p' "$task_timing")"
  fi
  fail "terminal result 後の hook hang を成功として回収" "$task_output"
fi

fake_task_error="$TEST_ROOT/claude-task-error"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'exit 7' > "$fake_task_error"
chmod +x "$fake_task_error" || fail "task abnormal-exit fixture を構築" "chmod failed"
if task_error_output=$(CLAUDE_EVAL_COMMAND="$fake_task_error" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-error-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  fail "terminal result 直後の異常終了を成功にしない" "$task_error_output"
elif ! printf '%s\n' "$task_error_output" | rg -qF 'unexpected exit after terminal result: status=7'; then
  task_error_timing="$TEST_ROOT/task-error-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_error_timing" ]; then
    task_error_output="$task_error_output
$(sed -n '1,120p' "$task_error_timing")"
  fi
  fail "terminal result 直後の異常終了を診断する" "$task_error_output"
else
  pass "terminal result 直後の異常終了は task eval error"
fi

fake_task_exit_after_timer="$TEST_ROOT/claude-task-exit-after-timer"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 7'\'' TERM' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'sleep 0.3' > "$fake_task_exit_after_timer"
chmod +x "$fake_task_exit_after_timer" || fail "task delayed abnormal-exit fixture を構築" "chmod failed"
if task_exit_after_timer_output=$(CLAUDE_EVAL_COMMAND="$fake_task_exit_after_timer" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-exit-after-timer-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  fail "回収要求と競合した task 異常終了を成功にしない" "$task_exit_after_timer_output"
elif ! printf '%s\n' "$task_exit_after_timer_output" | rg -qF 'unexpected exit after terminal result: status=7'; then
  task_exit_after_timer_timing="$TEST_ROOT/task-exit-after-timer-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_exit_after_timer_timing" ]; then
    task_exit_after_timer_output="$task_exit_after_timer_output
$(sed -n '1,120p' "$task_exit_after_timer_timing")"
  fi
  fail "回収要求と競合した task 異常終了を具体的に診断する" "$task_exit_after_timer_output"
else
  pass "回収要求と競合した task 異常終了は eval error"
fi

fake_task_exit_143="$TEST_ROOT/claude-task-exit-143"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 143'\'' TERM' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'sleep 0.3' > "$fake_task_exit_143"
chmod +x "$fake_task_exit_143" || fail "task exit 143 fixture を構築" "chmod failed"
if task_exit_143_output=$(CLAUDE_EVAL_COMMAND="$fake_task_exit_143" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-exit-143-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  pass "runner の SIGTERM による task exit 143 を成功として扱う"
else
  task_exit_143_timing="$TEST_ROOT/task-exit-143-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_exit_143_timing" ]; then
    task_exit_143_output="$task_exit_143_output
$(sed -n '1,120p' "$task_exit_143_timing")"
  fi
  fail "runner の SIGTERM による task exit 143 を成功として扱う" "$task_exit_143_output"
fi

fake_task_exited_leader="$TEST_ROOT/claude-task-exited-leader"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'exit 0' > "$fake_task_exited_leader"
chmod +x "$fake_task_exited_leader" || fail "task exited-leader fixture を構築" "chmod failed"
if task_exited_leader_output=$(timeout 8 env CLAUDE_EVAL_COMMAND="$fake_task_exited_leader" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-exited-leader-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  pass "terminal result 後に leader が終了しても子孫を回収"
else
  fail "terminal result 後に leader が終了しても子孫を回収" "$task_exited_leader_output"
fi

printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -eq 0 ]; then
  exit 0
fi
exit 1
