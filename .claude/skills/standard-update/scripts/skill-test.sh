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

fake_apply_fixture_probe="$TEST_ROOT/claude-apply-fixture-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'test -z "$(git status --porcelain)"' \
  'git ls-files --error-unmatch target-project/app/http.rs target-project/tests/http.rs architecture-decisions/0002-worker-contract.md >/dev/null' \
  'test ! -e skills/standard-apply/evals' \
  'test ! -e .claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","usage":{}}'\''' \
  > "$fake_apply_fixture_probe"
chmod +x "$fake_apply_fixture_probe"
for eval_configuration in old-skill with-skill; do
  if apply_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_apply_fixture_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/apply-probe" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-apply --eval-id 6 2>&1) \
    && test ! -s "$TEST_ROOT/apply-probe/standard-apply/eval-6-sonnet/$eval_configuration/status.txt" \
    && test ! -s "$TEST_ROOT/apply-probe/standard-apply/eval-6-sonnet/$eval_configuration/diff.patch"; then
    pass "$eval_configuration の設計fixtureは無編集をcleanとして記録する"
  else
    fail "$eval_configuration の設計fixtureは無編集をcleanとして記録する" "$apply_probe_output"
  fi
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

printf '\n=== 7. semantic maintenance の隔離と成果物 ===\n'
semantic_probe="$TEST_ROOT/claude-semantic-probe"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'const fs = require("node:fs");' \
  'const cp = require("node:child_process");' \
  'const assert = require("node:assert/strict");' \
  'const args = process.argv.slice(2);' \
  'const result = (extra = {}) => console.log(JSON.stringify({type:"result",is_error:false,result:"harness probe",usage:{input_tokens:1,output_tokens:1},modelUsage:{"probe-model":{}},...extra}));' \
  'if (args.includes("--json-schema")) {' \
  '  const input = fs.readFileSync(0,"utf8");' \
  '  assert.equal(args[args.indexOf("--tools")+1],"");' \
  '  assert(args.includes("--disable-slash-commands"));' \
  '  assert(!fs.existsSync(".claude"));' \
  '  const expectations = JSON.parse(input.split("\n\n").find(line => line.startsWith("Expectations: ")).slice(14));' \
  '  result({structured_output:{expectations:expectations.map(text => ({text,passed:true,evidence:"after-files.json: isolated harness probe"})),feedback:"probe only"}});' \
  '} else {' \
  '  assert.equal(cp.execFileSync("git",["status","--porcelain"],{encoding:"utf8"}),"");' \
  '  for (const oracle of ["evals/evals.json","scripts/run-task-evals.mjs","scripts/skill-test.sh"]) {' \
  '    const file = ".claude/skills/standard-update/"+oracle;' \
  '    assert(!fs.existsSync(file));' \
  '    assert.throws(() => cp.execFileSync("git",["show","HEAD^:"+file],{stdio:"pipe"}));' \
  '  }' \
  '  cp.execFileSync("git",["ls-files","--error-unmatch","docs/research/maintenance-input.md"],{stdio:"pipe"});' \
  '  assert(!args[args.indexOf("-p")+1].includes("Expectations:"));' \
  '  fs.appendFileSync("concerns/configuration/config-vs-flags.md","\nprobe content\n");' \
  '  fs.writeFileSync("docs/research/ignored-probe.txt","ignored evidence");' \
  '  console.log(JSON.stringify({type:"assistant",message:{content:[{type:"tool_use",id:"probe-read",name:"Read",input:{file_path:"docs/research/maintenance-input.md"}}]}}));' \
  '  console.log(JSON.stringify({type:"user",message:{content:[{type:"tool_result",tool_use_id:"probe-read",is_error:false,content:"x".repeat(6000)}]}}));' \
  '  result();' \
  '}' > "$semantic_probe"
chmod +x "$semantic_probe" || fail "semantic harness probe を構築" "chmod failed"
for eval_configuration in old-skill with-skill; do
  if semantic_probe_output=$(CLAUDE_EVAL_COMMAND="$semantic_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/semantic-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-update --suite semantic-maintenance --grade 2>&1); then
    pass "$eval_configuration の全semantic fixtureと別context graderを隔離"
  else
    fail "$eval_configuration の全semantic fixtureと別context graderを隔離" "$semantic_probe_output"
  fi
done
if node - "$TEST_ROOT/semantic-evals" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const root = process.argv[2];
const load = file => JSON.parse(fs.readFileSync(file, "utf8"));
for (let id = 10; id <= 16; id += 1) {
  const evalRoot = path.join(root, "standard-update", `eval-${id}-sonnet`);
  assert.equal(load(path.join(evalRoot, "benchmark.json")).comparable, true);
  for (const configuration of ["old-skill", "with-skill"]) {
    const run = path.join(evalRoot, configuration);
    assert.equal(load(path.join(run, "tool-evidence.json"))[0].result.length, 6000);
    assert.equal(load(path.join(run, "tool-evidence.json"))[0].status, "succeeded");
    assert(load(path.join(run, "changed-files.json")).includes("docs/research/ignored-probe.txt"));
    assert.equal(load(path.join(run, "after-files.json"))["docs/research/ignored-probe.txt"], "ignored evidence");
    assert.equal(load(path.join(run, "before-files.json"))["docs/research/ignored-probe.txt"], null);
    assert(load(path.join(run, "grading.json")).summary.overall_pass);
  }
}
const multiple = path.join(root, "standard-update", "eval-13-sonnet", "with-skill");
const before = load(path.join(multiple, "before-files.json"));
const coordination = before["languages/typescript/coordination.md"];
const inspection = before["languages/typescript/inspection.md"];
assert.equal(typeof coordination, "string");
assert.equal(typeof inspection, "string");
const headings = [...coordination.matchAll(/^## (.+)$/gm)].map(match => match[1]);
const correspondence = [...inspection.matchAll(/^\| coordination \| ([^|]+) \|/gm)].map(match => match[1].trim());
for (const heading of headings.filter(heading => !["概要", "参照"].includes(heading))) {
  assert(correspondence.includes(heading), `missing inspection correspondence: ${heading}`);
}
NODE
then
  pass "全fixtureの同一context比較と未追跡・ignored成果物と完全なtool結果を記録"
else
  fail "全fixtureの同一context比較と未追跡・ignored成果物と完全なtool結果を記録" "artifact assertion failed"
fi

printf '\n=== 8. 保存済み採点のprovenanceと起動時runner ===\n'
if node - "$TEST_ROOT" "$SCRIPT_DIR/run-task-evals.mjs" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const cp = require("node:child_process");
const assert = require("node:assert/strict");
const { createHash } = require("node:crypto");
const [root, runner] = process.argv.slice(2);
const digest = value => createHash("sha256").update(value).digest("hex");
const load = file => JSON.parse(fs.readFileSync(file, "utf8"));
const save = (file, value) => fs.writeFileSync(file, JSON.stringify(value));
const output = path.join(root, "provenance-evals");
const evalRoot = path.join(output, "standard-update", "eval-10-sonnet");
fs.cpSync(path.join(root, "semantic-evals", "standard-update", "eval-10-sonnet"), evalRoot, { recursive: true });
const probe = path.join(root, "claude-provenance-probe");
fs.writeFileSync(probe, `#!/usr/bin/env node
const fs = require("node:fs");
const assert = require("node:assert/strict");
const args = process.argv.slice(2);
const result = {type:"result",is_error:Boolean(process.env.PROBE_MODEL_ERROR),result:"provenance probe",usage:{},modelUsage:{[process.env.PROBE_MODEL || "probe-model"]:{}}};
if (args.includes("--json-schema")) {
  const prompt = fs.readFileSync(0,"utf8");
  const sections = prompt.split("\\n\\n");
  assert.equal(sections.find(line => line.startsWith("Task: ")).slice(6), process.env.PROBE_TASK);
  const expectations = JSON.parse(sections.find(line => line.startsWith("Expectations: ")).slice(14));
  assert.deepEqual(expectations, JSON.parse(process.env.PROBE_EXPECTATIONS));
  result.structured_output = {expectations:expectations.map(text => ({text:process.env.PROBE_INVALID_RUBRIC ? "wrong rubric" : text,passed:true,evidence:"provenance probe only"})),feedback:"not a semantic quality measurement"};
} else {
  assert(!process.env.PROBE_GRADE_ONLY, "grade-only unexpectedly executed task");
  if (process.env.PROBE_MUTATE_RUNNER) fs.appendFileSync(process.env.PROBE_MUTATE_RUNNER,"\\n");
}
console.log(JSON.stringify(result));
`, { mode: 0o755 });
const savedPrompt = "historical saved task";
const savedExpectations = ["historical saved expectation"];
for (const configuration of ["old-skill", "with-skill"]) {
  const file = path.join(evalRoot, configuration, "eval_metadata.json");
  const metadata = load(file);
  metadata.prompt = savedPrompt;
  metadata.expectations = savedExpectations;
  save(file, metadata);
}
const grade = (configuration, extraEnv = {}, executable = runner, expectedStatus = 0) => {
  const result = cp.spawnSync(process.execPath, [executable, "--configuration", configuration,
    "--skill", "standard-update", "--eval-id", "10", "--grade-only"], {
    env: { ...process.env, CLAUDE_EVAL_COMMAND: probe, SKILL_EVAL_OUTPUT_ROOT: output,
      PROBE_GRADE_ONLY: "1", PROBE_TASK: savedPrompt,
      PROBE_EXPECTATIONS: JSON.stringify(savedExpectations), ...extraEnv },
    encoding: "utf8",
  });
  assert.equal(result.status, expectedStatus, result.stdout + result.stderr);
};
const benchmark = () => load(path.join(evalRoot, "benchmark.json"));
const assertNotComparable = () => {
  assert.equal(benchmark().comparable, false);
  assert.equal(benchmark().delta_with_minus_old, null);
};
grade("old-skill");
grade("with-skill");
assert.equal(benchmark().comparable, true);
for (const configuration of ["old-skill", "with-skill"]) {
  const run = path.join(evalRoot, configuration);
  const grading = load(path.join(run, "grading.json"));
  assert.deepEqual(grading.expectations.map(entry => entry.text), savedExpectations);
  assert.equal(grading.provenance.task_prompt, savedPrompt);
  assert.deepEqual(grading.provenance.expectations, savedExpectations);
  const actualPrompt = fs.readFileSync(path.join(run, "grader-prompt.txt"), "utf8");
  assert.equal(grading.provenance.grader_instructions_sha256, digest(actualPrompt.split("\n\n")[0]));
  const command = grading.provenance.command_args;
  assert.equal(grading.provenance.schema_sha256, digest(command[command.indexOf("--json-schema") + 1]));
  assert.deepEqual(grading.provenance.actual_models, ["probe-model"]);
}
const rerunBackup = path.join(root, "graded-rerun-backup");
fs.cpSync(evalRoot, rerunBackup, { recursive: true });
for (const modelError of ["", "1"]) {
  const rerun = cp.spawnSync(process.execPath, [runner, "--configuration", "with-skill",
    "--skill", "standard-update", "--eval-id", "10"], {
    env: { ...process.env, CLAUDE_EVAL_COMMAND: probe, SKILL_EVAL_OUTPUT_ROOT: output,
      PROBE_GRADE_ONLY: "", PROBE_MODEL_ERROR: modelError },
    encoding: "utf8",
  });
  assert.equal(rerun.status, modelError ? 1 : 0, rerun.stdout + rerun.stderr);
  assert.equal(fs.existsSync(path.join(evalRoot, "with-skill", "grading.json")), false);
  assert.equal(fs.existsSync(path.join(evalRoot, "benchmark.json")), false);
  fs.rmSync(evalRoot, { recursive: true, force: true });
  fs.cpSync(rerunBackup, evalRoot, { recursive: true });
}
const savedMetadata = fs.readFileSync(path.join(evalRoot, "with-skill", "eval_metadata.json"), "utf8");
grade("with-skill", { PROBE_MODEL: "different-grader-model" });
assertNotComparable();
assert.equal(fs.readFileSync(path.join(evalRoot, "with-skill", "eval_metadata.json"), "utf8"), savedMetadata);
grade("with-skill");
const alternateRunner = path.join(root, "alternate-runner.mjs");
fs.writeFileSync(alternateRunner, fs.readFileSync(runner, "utf8") + "\n");
grade("with-skill", {}, alternateRunner);
assertNotComparable();
grade("with-skill");
const oldGradingFile = path.join(evalRoot, "old-skill", "grading.json");
const oldGrading = load(oldGradingFile);
const legacy = structuredClone(oldGrading);
delete legacy.provenance;
save(oldGradingFile, legacy);
grade("with-skill");
assertNotComparable();
save(oldGradingFile, oldGrading);
grade("with-skill", { PROBE_INVALID_RUBRIC: "1" }, runner, 1);
const failed = load(path.join(evalRoot, "with-skill", "grading.json"));
assert.equal(failed.summary.overall_pass, false);
assert.deepEqual(failed.provenance.expectations, savedExpectations);
assert(failed.error);
assert.equal(benchmark().delta_with_minus_old, null);
grade("with-skill");
const newMetadataFile = path.join(evalRoot, "with-skill", "eval_metadata.json");
const revised = load(newMetadataFile);
revised.expectations = ["corrected suite expectation"];
revised.fixture_sha256 = digest("corrected suite fixture");
save(newMetadataFile, revised);
grade("with-skill", { PROBE_EXPECTATIONS: JSON.stringify(revised.expectations) });
assertNotComparable();
const liveRunner = path.join(root, "live-runner.mjs");
fs.copyFileSync(runner, liveRunner);
const startupHash = digest(fs.readFileSync(liveRunner));
const liveOutput = path.join(root, "live-runner-evals");
const savedEvalFile = path.join(root, "saved-evals.json");
const liveDefinitions = load(path.join(path.dirname(runner), "..", "evals", "evals.json"));
const savedEval = structuredClone(liveDefinitions.evals.find(item => item.id === 10));
savedEval.prompt = savedPrompt;
savedEval.expectations = savedExpectations;
save(savedEvalFile, { skill_name: "standard-update", evals: [savedEval] });
const liveResult = cp.spawnSync(process.execPath, [liveRunner, "--configuration", "with-skill",
  "--skill", "standard-update", "--eval-id", "10", "--eval-file", savedEvalFile], {
  env: { ...process.env, CLAUDE_EVAL_COMMAND: probe, SKILL_EVAL_OUTPUT_ROOT: liveOutput,
    PROBE_MUTATE_RUNNER: liveRunner, PROBE_GRADE_ONLY: "" },
  encoding: "utf8",
});
assert.equal(liveResult.status, 0, liveResult.stdout + liveResult.stderr);
assert.notEqual(digest(fs.readFileSync(liveRunner)), startupHash);
const liveMetadata = load(path.join(liveOutput, "standard-update", "eval-10-sonnet", "with-skill", "eval_metadata.json"));
assert.equal(liveMetadata.runner_sha256, startupHash);
assert.equal(liveMetadata.prompt, savedPrompt);
assert.deepEqual(liveMetadata.expectations, savedExpectations);
NODE
then
  pass "保存済みrubricで再採点しgrader差・旧artifact・改訂fixtureを比較から除外する"
else
  fail "保存済み採点のprovenanceと起動時runnerを保持する" "behavior regression failed"
fi

printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -eq 0 ]; then
  exit 0
fi
exit 1
