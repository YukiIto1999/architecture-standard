#!/usr/bin/env bash
set -uo pipefail

required_commands=(bash dirname git rg node npm mktemp mkdir ln timeout sed rm cp)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'FAIL: missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/../../.." rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'FAIL: git repository で実行すること\n' >&2
  exit 1
}
cd "$REPO_ROOT" || exit 1

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

if [ "${1:-}" != --line-store-only ]; then
printf '\n=== 2. task eval と trigger eval の schema ===\n'
eval_output=$(bash "$SCRIPT_DIR/skill-package-check.sh" 2>&1)
if [ "$?" -eq 0 ]; then
  printf '%s\n' "$eval_output"
  pass "skill の package 構造と eval schema が有効"
else
  fail "skill の package 構造または eval schema が無効" "$eval_output"
fi
package_fixture="$TEST_ROOT/package-missing-evals"
mkdir -p "$package_fixture" || fail "package checker fixture を構築" "mkdir failed"
cp -a skills "$package_fixture/" || fail "package checker fixture を構築" "copy failed"
git -C "$package_fixture" init --quiet || fail "package checker fixture を構築" "git init failed"
rm -rf -- "$package_fixture/skills/standard-apply/evals"
if package_missing_output=$(cd "$package_fixture" && bash skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "通常実行ではskillのeval一式欠落を拒否する" "$package_missing_output"
elif ! printf '%s\n' "$package_missing_output" | rg -qF 'standard-apply: evals directory がない'; then
  fail "eval一式欠落を具体的に診断する" "$package_missing_output"
else
  pass "通常実行ではskillのeval一式欠落を拒否する"
fi
if package_isolated_output=$(cd "$package_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=with-skill bash skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "選択skillのevalだけを隠した旧隔離構成を拒否する" "$package_isolated_output"
elif ! printf '%s\n' "$package_isolated_output" | rg -qF '非公開 package の instruction または eval が残っている'; then
  fail "旧隔離構成のinstruction漏出を診断する" "$package_isolated_output"
else
  pass "選択skillのevalだけを隠した旧隔離構成を拒否する"
fi
if package_partial_context=$(cd "$package_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply bash skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "不完全な隔離contextでeval欠落を許可しない" "$package_partial_context"
else
  pass "不完全な隔離contextでeval欠落を許可しない"
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


printf '\n=== 5. OMP evaluator の公開契約 ===\n'
if regression_output=$(node --test "$SCRIPT_DIR/evaluator-regression.test.mjs" 2>&1); then
  printf '%s\n' "$regression_output"
  pass "OMP event・失敗境界・隔離・採点provenanceを保持する"
else
  fail "OMP evaluator の公開契約" "$regression_output"
fi

fi

printf '\n=== 6. LineStore の公開契約と隔離復元 ===\n'
if node - "$TEST_ROOT" "$SCRIPT_DIR/run-task-evals.mjs" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const cp = require("node:child_process");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const [root, runner] = process.argv.slice(2);
const repo = path.resolve(path.dirname(runner), "../../..");
const fixture = path.join(repo, "skills/standard-apply/evals/fixtures/line-store");
const project = path.join(root, "oracle-project");
const host = path.join(fixture, "host/check.mjs");
const digest = value => crypto.createHash("sha256").update(value).digest("hex");
const load = file => JSON.parse(fs.readFileSync(file, "utf8"));
const save = (file, value) => fs.writeFileSync(file, JSON.stringify(value, null, 2) + "\n");
fs.cpSync(path.join(fixture, "project"), project, {
  recursive: true, filter: file => !path.relative(path.join(fixture, "project"), file).split(path.sep).includes("node_modules"),
});
const installed = cp.spawnSync("npm", ["ci", "--ignore-scripts", "--no-audit", "--no-fund"], { cwd: project, encoding: "utf8" });
assert.equal(installed.status, 0, installed.stdout + installed.stderr);
const baselineStore = fs.readFileSync(path.join(project, "src/line-store.ts"), "utf8");
const baselineConsumer = fs.readFileSync(path.join(project, "src/render-selected.ts"), "utf8");
const consumer = baselineConsumer.replace('{ Err, Ok, type Result }', '{ type Result }')
  .replace(/  return positions\.map\(\(position\) => \{[\s\S]*?\n  \}\);/, "  return positions.map((position) => store.get(position));");
assert.notEqual(consumer, baselineConsumer);
const storage = map => `import { Err, Ok, type Result } from "ts-results-es";

export class LineStore {
  readonly #lines${map ? " = new Map<number, string>()" : ": string[] = []"};

  append(line: string): void {
    ${map ? "this.#lines.set(this.#lines.size, line)" : "this.#lines.push(line)"};
  }

  get(position: number): Result<string, "position-out-of-range"> {
    const line = ${map ? "this.#lines.get(position)" : "this.#lines[position]"};
    return line === undefined ? new Err("position-out-of-range" as const) : new Ok(line);
  }
}
`;
const check = (mode, expected = 0) => {
  const result = cp.spawnSync(process.execPath, [host, project, ...(mode ? ["--boundary", mode] : [])], { encoding: "utf8" });
  assert.equal(result.status === 0, expected === 0, result.stdout + result.stderr);
};
check();
fs.writeFileSync(path.join(project, "src/render-selected.ts"), consumer);
fs.writeFileSync(path.join(project, "src/line-store.ts"), storage(false));
check("hidden");
for (const broken of [
  storage(false).replace("this.#lines.push(line)", "this.#lines.unshift(line)"),
  storage(false).replace("this.#lines.push(line)", "if (!this.#lines.includes(line)) this.#lines.push(line)"),
  storage(false).replace("this.#lines[position]", "this.#lines.at(position)"),
  storage(false).replace("this.#lines[position]", "this.#lines[position + 1]"),
  storage(false).replace('new Err("position-out-of-range" as const)', 'new Err("wrong-error" as const)'),
  storage(false).replace("const line = this.#lines[position];", "const line = this.#lines[position];\n    if (line === undefined) this.#lines.pop();"),
]) {
  fs.writeFileSync(path.join(project, "src/line-store.ts"), broken);
  check("", 1);
}
for (const leak of [
  storage(false).replace("  append(", "  get exposed(): readonly string[] {\n    return this.#lines;\n  }\n\n  append("),
  storage(true).replace("readonly #lines", "readonly lines").replaceAll("this.#lines", "this.lines"),
]) {
  fs.writeFileSync(path.join(project, "src/line-store.ts"), leak);
  check();
  check(leak.includes("new Map") ? "map" : "hidden", 1);
}
fs.writeFileSync(path.join(project, "src/line-store.ts"), storage(true));
check("map");

const provider = path.join(root, "line-store-provider.mjs");
fs.writeFileSync(provider, `#!/usr/bin/env node
import fs from "node:fs";
import cp from "node:child_process";
import assert from "node:assert/strict";
if (process.argv[2] === "config") {
  console.log(JSON.stringify({ key: "modelRoles", value: { default: "regression/scripted-fixture" },
    type: "record", description: "" }));
  process.exit(0);
}
const finish = text => {
  const message = { role: "assistant", content: [{ type: "text", text }], provider: "regression",
    model: "scripted-fixture", timestamp: 2, stopReason: "stop",
    usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, totalTokens: 2,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
  console.log(JSON.stringify({ type: "message_end", message }));
  console.log(JSON.stringify({ type: "agent_end", messages: [message] }));
};
if (process.argv.includes("--no-skills")) {
  const prompt = fs.readFileSync(0, "utf8");
  const expectations = JSON.parse(prompt.split("\\n\\n").find(section => section.startsWith("Expectations: ")).slice(14));
  finish(JSON.stringify({ expectations: expectations.map(text => ({ text, passed: true,
    evidence: "adversarial scripted grader; fixed host rejection must prevail" })), feedback: "not model-quality evidence" }));
  process.exit(0);
}
const skillPath = "skill://" + process.env.SKILL_EVAL_ISOLATED_SKILL;
const skillText = fs.readFileSync("skills/" + process.env.SKILL_EVAL_ISOLATED_SKILL + "/SKILL.md", "utf8");
console.log(JSON.stringify({ type: "message_end", message: { role: "assistant", provider: "regression",
  model: "scripted-fixture", timestamp: 1, stopReason: "toolUse", usage: {},
  content: [{ type: "toolCall", id: "selected-skill", name: "read", arguments: { path: skillPath } }] } }));
console.log(JSON.stringify({ type: "tool_execution_start", toolCallId: "selected-skill", toolName: "read", args: { path: skillPath } }));
console.log(JSON.stringify({ type: "tool_execution_end", toolCallId: "selected-skill", toolName: "read",
  result: { content: [{ type: "text", text: skillText }] }, isError: false }));
const payload = JSON.parse(fs.readFileSync(process.env.LINE_STORE_PAYLOAD_FILE, "utf8"));
if (payload.expected) {
  for (const [file, content] of Object.entries(payload.expected)) {
    assert.equal(fs.readFileSync("target-project/" + file, "utf8"), content);
  }
}
if (payload.standard) {
  for (const [file, content] of Object.entries(payload.standard)) assert.equal(fs.readFileSync(file, "utf8"), content);
}
for (const forbidden of [
  "skills/standard-apply/evals", "skills/standard-update/scripts/run-task-evals.mjs",
  "skills/standard-update/scripts/skill-test.sh", "docs/minutes", "docs/decisions", "docs/reviews", "docs/research",
]) {
  assert(!fs.existsSync(forbidden), "actor oracle leak: " + forbidden);
  assert.notEqual(cp.spawnSync("git", ["show", "HEAD^:" + forbidden], { stdio: "ignore" }).status, 0);
}
assert(!fs.existsSync("target-project/host"));
for (const [file, content] of Object.entries(payload.files ?? {})) fs.writeFileSync("target-project/" + file, content);
if (payload.marker) fs.writeFileSync(payload.marker, "launched");
finish("scripted candidate; not a model evaluation");
`, { mode: 0o755 });
const run = (name, id, payload, snapshot, expectedStatus = 0, extra = []) => {
  const output = path.join(root, name);
  const payloadFile = path.join(root, `${name}-payload.json`);
  save(payloadFile, payload);
  const result = cp.spawnSync(process.execPath, [runner, "--configuration", "with-skill", "--skill", "standard-apply",
    "--eval-id", String(id), ...(snapshot ? ["--project-snapshot", snapshot] : []), ...extra], {
    encoding: "utf8", timeout: 3_600_000,
    env: { ...process.env, OMP_EVAL_COMMAND: provider, OMP_EVAL_TIMEOUT_MS: "60000", OMP_EVAL_MODEL: "",
      SKILL_EVAL_OUTPUT_ROOT: output,
      LINE_STORE_PAYLOAD_FILE: payloadFile },
  });
  assert.equal(result.status, expectedStatus, JSON.stringify({ error: result.error?.message,
    signal: result.signal, stdout: result.stdout, stderr: result.stderr }));
  return path.join(output, "standard-apply", `eval-${id}-default`, "with-skill");
};
const hidden = run("hidden", 9, { files: { "src/line-store.ts": storage(false), "src/render-selected.ts": consumer } });
assert.equal(load(path.join(hidden, "host-after.json")).passed, true);
const snapshotFile = path.join(hidden, "project-snapshot.json");
const snapshot = load(snapshotFile);
for (const [file, entry] of Object.entries(snapshot.files)) assert.equal(entry.sha256, digest(entry.content), file);
const restored = Object.fromEntries(Object.entries(snapshot.files).map(([file, entry]) => [file, entry.content]));
const mapped = run("mapped", 10, { expected: restored, files: { "src/line-store.ts": storage(true) } }, snapshotFile);
const verified = load(path.join(mapped, "host-after.json"));
assert.equal(verified.passed, true);
assert.deepEqual(verified.consumer_changes, []);
const mutationScope = JSON.parse(verified.verification_reports["mutation/scope.json"].content);
const mutationGate = JSON.parse(verified.verification_reports["mutation/gate.json"].content);
assert.deepEqual(mutationScope.changedProduction, ["src/line-store.ts"]);
assert.deepEqual(mutationScope.affectedProduction, ["src/render-selected.ts"]);
assert.deepEqual(mutationScope.mutate, ["src/line-store.ts", "src/render-selected.ts"]);
assert.deepEqual(mutationScope.testFiles, ["tests/render-selected.property.test.ts", "tests/render-selected.test.ts"]);
assert.equal(mutationGate.baseline, mutationScope.baseline);
assert.equal(mutationGate.mutationExecuted, true);
assert(mutationGate.generated > 0);
assert(mutationGate.eligible > 0);
assert.equal(mutationGate.totalUndetected, 0);
assert.equal(mutationGate.incomplete, 0);
assert.equal(mutationGate.success, true);
assert.equal(fs.readFileSync(path.join(mapped, "consumer-diff.patch"), "utf8"), "");
assert.equal(load(path.join(mapped, "project-before.json"))["src/line-store.ts"].content, storage(false));
const changedConsumer = consumer.replace("  const store = new LineStore();", "  const store = new LineStore();\n\n");
const changed = run("consumer-change", 10, { files: {
  "src/line-store.ts": storage(true), "src/render-selected.ts": changedConsumer,
} }, snapshotFile, 1);
assert.equal(load(path.join(changed, "host-after.json")).passed, false);
assert.deepEqual(load(path.join(changed, "host-after.json")).consumer_changes, ["src/render-selected.ts"]);
assert(fs.readFileSync(path.join(changed, "consumer-diff.patch"), "utf8").includes("render-selected.ts"));
const weakened = run("locked-test-change", 10, { files: {
  "src/line-store.ts": storage(true), "tests/render-selected.test.ts": "",
} }, snapshotFile, 1);
const lockedVerdict = load(path.join(weakened, "host-after.json"));
assert.equal(lockedVerdict.passed, false);
assert(lockedVerdict.locked_file_changes.includes("tests/render-selected.test.ts"));
assert(lockedVerdict.commands.some(command => command.command.includes(host) && command.passed));
const addedSource = "export function selectPosition(position: number): number {\n  return position;\n}\n";
const added = run("added-consumer", 10, { files: {
  "src/line-store.ts": storage(true), "src/selection.ts": addedSource,
} }, snapshotFile, 1);
assert.deepEqual(load(path.join(added, "host-after.json")).consumer_changes, ["src/selection.ts"]);
const addedPatchLines = fs.readFileSync(path.join(added, "consumer-diff.patch"), "utf8").split("\n");
assert(addedSource.trimEnd().split("\n").every(line => addedPatchLines.includes("+" + line)),
  "consumer diff must capture added untracked production source");
const rejectedOutput = path.join(root, "host-rejection-grading");
const rejectedEval = path.join(rejectedOutput, "standard-apply", "eval-10-default");
fs.mkdirSync(rejectedEval, { recursive: true });
fs.cpSync(mapped, path.join(rejectedEval, "old-skill"), { recursive: true });
fs.cpSync(weakened, path.join(rejectedEval, "with-skill"), { recursive: true });
for (const configuration of ["old-skill", "with-skill"]) {
  const graded = cp.spawnSync(process.execPath, [runner, "--configuration", configuration,
    "--skill", "standard-apply", "--eval-id", "10", "--grade-only"], {
    encoding: "utf8", env: { ...process.env, OMP_EVAL_COMMAND: provider,
      OMP_EVAL_TIMEOUT_MS: "60000", OMP_EVAL_MODEL: "",
      SKILL_EVAL_OUTPUT_ROOT: rejectedOutput, LINE_STORE_PAYLOAD: "{}" },
  });
  assert.equal(graded.status, 0, graded.stdout + graded.stderr);
}
const rejectedGrade = load(path.join(rejectedEval, "with-skill", "grading.json"));
assert.equal(rejectedGrade.summary.overall_pass, false);
assert.equal(rejectedGrade.summary.passed, 0, "host-rejected candidate cannot count as successful");
assert.equal(rejectedGrade.summary.pass_rate, 0);
assert.equal(load(path.join(rejectedEval, "benchmark.json")).delta_with_minus_old, null);
const marker = path.join(root, "unsafe-provider-marker");
for (const [name, mutate] of [
  ["missing-source", value => { delete value.files["src/render-selected.ts"]; }],
  ["missing-lock", value => { delete value.files["package-lock.json"]; }],
  ["changed-contract", value => { value.files["README.md"].content += "weakened"; value.files["README.md"].sha256 = digest(value.files["README.md"].content); }],
  ["traversal", value => { value.files["src/../../escaped.ts"] = { content: "", sha256: digest("") }; }],
  ["hash-mismatch", value => { value.files["src/line-store.ts"].content += " "; }],
]) {
  const unsafe = structuredClone(snapshot);
  mutate(unsafe);
  delete unsafe.sha256;
  unsafe.sha256 = digest(JSON.stringify(unsafe));
  const file = path.join(root, `${name}.json`);
  save(file, unsafe);
  run(name, 10, { marker }, file, 1);
  assert(!fs.existsSync(marker), name + " must fail before provider");
}
const definitions = load(path.join(repo, "skills/standard-apply/evals/evals.json"));
const badEval = structuredClone(definitions.evals.find(item => item.id === 10));
badEval.fixture.command = "arbitrary shell";
const badFile = path.join(root, "unsafe-eval.json");
save(badFile, { skill_name: "standard-apply", evals: [badEval] });
run("unsafe-fixture", 10, { marker }, null, 1, ["--eval-file", badFile]);
assert(!fs.existsSync(marker));
const linkedSnapshot = path.join(root, "linked-snapshot.json");
fs.symlinkSync(snapshotFile, linkedSnapshot);
run("linked-snapshot", 10, { marker }, linkedSnapshot, 1);
assert(!fs.existsSync(marker));
const missingStandard = path.join(root, "incomplete-standard");
fs.mkdirSync(missingStandard);
fs.writeFileSync(path.join(missingStandard, "README.md"), "# incomplete\n");
run("incomplete-standard", 10, { marker }, snapshotFile, 1, ["--standard-snapshot", missingStandard]);
assert(!fs.existsSync(marker));
const normBefore = path.join(root, "norm-before");
const normAfter = path.join(root, "norm-after");
fs.mkdirSync(normBefore);
for (const entry of ["README.md", "principles", "concerns", "structure", "tools", "languages", "process"]) {
  fs.cpSync(path.join(repo, entry), path.join(normBefore, entry), { recursive: true });
}
fs.cpSync(normBefore, normAfter, { recursive: true });
for (const file of ["structure/README.md", "process/design.md"]) fs.appendFileSync(path.join(normAfter, file), "\n");
const standardInput = norm => Object.fromEntries(["README.md", "structure/README.md", "process/design.md"]
  .map(file => [file, fs.readFileSync(path.join(norm, file), "utf8")]));
const normRunBefore = run("norm-before-eval", 7, { standard: standardInput(normBefore) }, null, 0, ["--standard-snapshot", normBefore]);
const normRunAfter = run("norm-after-eval", 7, { standard: standardInput(normAfter) }, null, 0, ["--standard-snapshot", normAfter]);
assert.notEqual(load(path.join(normRunBefore, "eval_metadata.json")).standard_sha256,
  load(path.join(normRunAfter, "eval_metadata.json")).standard_sha256);
assert.equal(load(path.join(normRunAfter, "standard-files.json"))["process/design.md"].content,
  fs.readFileSync(path.join(normAfter, "process/design.md"), "utf8"));
const excludedSymlink = path.join(root, "norm-excluded-symlink");
fs.cpSync(normBefore, excludedSymlink, { recursive: true });
fs.symlinkSync(root, path.join(excludedSymlink, "principles", "reports"));
run("excluded-norm-symlink", 7, { marker }, null, 1, ["--standard-snapshot", excludedSymlink]);
assert(!fs.existsSync(marker), "excluded-looking normative symlink must fail before provider");
const generatedName = path.join(normAfter, "principles", "reports");
fs.mkdirSync(generatedName);
fs.writeFileSync(path.join(generatedName, "contract.md"), "# Normative contract\n");
const completeNorm = run("complete-norm-files", 7, { standard: {
  "principles/reports/contract.md": "# Normative contract\n",
} }, null, 0, ["--standard-snapshot", normAfter]);
assert.equal(load(path.join(completeNorm, "standard-files.json"))["principles/reports/contract.md"].content,
  "# Normative contract\n");
NODE
then
  pass "固定host oracleで振る舞い・漏出・mutation・source復元・consumer不変・unsafe入力を判定する"
else
  fail "LineStoreの公開契約と隔離復元" "behavior regression failed"
fi

printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -eq 0 ]; then
  exit 0
fi
exit 1
