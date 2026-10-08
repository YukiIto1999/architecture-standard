import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";

import { parseOmpStream } from "./omp-eval-adapter.mjs";
const scripts = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(scripts, "../../..");
const taskRunner = path.join(scripts, "run-task-evals.mjs");
const triggerRunner = path.join(scripts, "run-trigger-evals.mjs");
const root = mkdtempSync(path.join(tmpdir(), "architecture-standard-omp-regression-"));
const provider = path.join(root, "omp-fixture.mjs");
const load = file => JSON.parse(readFileSync(file, "utf8"));
const save = (file, value) => writeFileSync(file, JSON.stringify(value, null, 2) + "\n");
const digest = value => createHash("sha256").update(value).digest("hex");
const triggers = load(path.join(repo, "skills/standard-apply/evals/trigger-evals.json"));
const positiveQuery = triggers.findIndex(item => item.should_trigger && !Object.hasOwn(item, "expected_skill"));
const negativeQuery = triggers.findIndex(item => !item.should_trigger && !Object.hasOwn(item, "expected_skill"));

after(() => rmSync(root, { recursive: true, force: true }));

writeFileSync(provider, `#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
const args = process.argv.slice(2);
if (args[0] === "config") {
  console.log(JSON.stringify({ key: "modelRoles",
    value: process.env.REGRESSION_CONFIG_ERROR ? {} : { default: "regression/regression-model:medium" },
    type: "record", description: "" }));
  process.exit(0);
}
const value = name => args[args.indexOf(name) + 1];
const grader = args.includes("--no-skills") && value("--tools") === "";
const mode = grader ? process.env.REGRESSION_GRADER_CASE || "valid" : process.env.REGRESSION_CASE || "valid";
const model = process.env.REGRESSION_ACTUAL_MODEL || "regression-model";
const emit = event => process.stdout.write(JSON.stringify(event) + "\\n");
let timestamp = 0;
const message = (content, stopReason = "stop") => ({ role: "assistant", content, provider: "regression",
  model, timestamp: ++timestamp, stopReason,
  usage: { input: 4, output: 2, cacheRead: 0, cacheWrite: 0, totalTokens: 6,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } });
const messages = [];
const remember = current => {
  messages.push(current);
  emit({ type: "message_end", message: current });
  emit({ type: "turn_end", message: current, toolResults: [] });
};
const finish = (text = "scripted OMP consumer fixture", stopReason = "stop", terminal = true) => {
  const final = message([{ type: "text", text }], stopReason);
  if (mode === "changed-model") final.model = "unexpected-fallback";
  remember(final);
  if (terminal) emit({ type: "agent_end", messages });
};
const call = (id, name, arguments_, text, failed = false, completed = true) => {
  remember(message([{ type: "toolCall", id, name, arguments: arguments_ }], "toolUse"));
  emit({ type: "tool_execution_start", toolCallId: id, toolName: name, args: arguments_ });
  if (completed) emit({ type: "tool_execution_end", toolCallId: id, toolName: name,
    result: { content: [{ type: "text", text }] }, isError: failed });
};
const readSkill = (id, skill, spelling = "uri", contentMode = "full", failed = false, completed = true) => {
  const file = path.resolve("skills", skill, "SKILL.md");
  let text = fs.readFileSync(file, "utf8");
  if (contentMode === "metadata") text = text.split("---")[1];
  if (contentMode === "empty") text = "";
  if (contentMode === "range") text = text.split("\\n").slice(0, 5).join("\\n");
  const argument = spelling === "uri" ? "skill://" + skill : spelling === "absolute" ? file : "skills/" + skill + "/SKILL.md";
  call(id, "read", { path: contentMode === "range" ? argument + ":1-5" : argument }, text, failed, completed);
};
const checkProduct = () => {
  const run = () => spawnSync("bash", ["skills/standard-update/scripts/skill-package-check.sh"], { encoding: "utf8" });
  const valid = run();
  assert.equal(valid.status, 0, valid.stdout + valid.stderr);
  call("product-check", "bash", { command: "bash skills/standard-update/scripts/skill-package-check.sh" },
    valid.stdout + valid.stderr);
  const rejectChangedFile = (file, content) => {
    const original = fs.existsSync(file) ? fs.readFileSync(file) : null;
    if (content === null) fs.rmSync(file);
    else fs.writeFileSync(file, content);
    const rejected = run();
    if (original === null) fs.rmSync(file);
    else fs.writeFileSync(file, original);
    assert.notEqual(rejected.status, 0, "invalid actor package passed: " + file + "\\n" + rejected.stdout + rejected.stderr);
  };
  const selectedRoot = "skills/" + process.env.SKILL_EVAL_ISOLATED_SKILL;
  const withoutSkill = process.env.SKILL_EVAL_CONFIGURATION === "without-skill";
  if (withoutSkill) {
    fs.mkdirSync(selectedRoot);
    const partial = run();
    fs.rmSync(selectedRoot, { recursive: true });
    assert.notEqual(partial.status, 0, "without-skill accepted a remaining selected package");
    assert.match(partial.stdout + partial.stderr, /without-skill fixture に選択 package が残っている/);
    fs.symlinkSync("missing-selected-package", selectedRoot);
    const dangling = run();
    fs.rmSync(selectedRoot);
    assert.notEqual(dangling.status, 0, "without-skill accepted a dangling selected package");
    assert.match(dangling.stdout + dangling.stderr, /skill directory は実 directory であること/);
  } else {
    const selected = selectedRoot + "/SKILL.md";
    const skillName = process.env.SKILL_EVAL_ISOLATED_SKILL;
    rejectChangedFile(selected, fs.readFileSync(selected, "utf8").replace("name: " + skillName, "name: wrong-name"));
    rejectChangedFile(selected, null);
    rejectChangedFile("skills/cli-design/SKILL.md", null);
  }
  if (!(withoutSkill && process.env.SKILL_EVAL_ISOLATED_SKILL === "standard-conformance")) {
    const conformance = "skills/standard-conformance";
    fs.renameSync(conformance, conformance + ".fixture-backup");
    const missing = run();
    fs.renameSync(conformance + ".fixture-backup", conformance);
    assert.notEqual(missing.status, 0, "actor accepted a missing conformance dependency");
    assert.match(missing.stdout + missing.stderr, /standard-conformance: skill directory がない/);
    rejectChangedFile(conformance + "/scripts/check-coverage.mjs", null);
    rejectChangedFile(conformance + "/scripts/check-coverage.test.mjs", null);
  }
  const projectionFile = "skills/standard-audit/evals/evals.json";
  if (fs.existsSync(projectionFile)) {
    const projection = JSON.parse(fs.readFileSync(projectionFile, "utf8"));
    projection.evals[0].expectations = ["leaked expected answer"];
    rejectChangedFile(projectionFile, JSON.stringify(projection));
  }
  rejectChangedFile("skills/standard-feedback/SKILL.md", "unexpected actor instruction");
  const oracleRoot = "skills/standard-feedback/evals";
  fs.mkdirSync(oracleRoot);
  fs.writeFileSync(oracleRoot + "/evals.json", JSON.stringify({ expectations: ["leaked rubric"] }));
  const leaked = run();
  fs.rmSync(oracleRoot, { recursive: true });
  assert.notEqual(leaked.status, 0, "actor fixture accepted leaked eval rubrics");
};
if (process.env.REGRESSION_INVOCATIONS) fs.appendFileSync(process.env.REGRESSION_INVOCATIONS,
  JSON.stringify({ grader, cwd: process.cwd(), model: value("--model") }) + "\\n");
if (mode === "nonzero") process.exit(7);
if (mode === "malformed") {
  process.stdout.write("{not-json}\\n");
  process.exit(0);
}
if (mode === "truncated") {
  process.stdout.write('{"type":"message_end"');
  process.exit(0);
}
if (mode === "hang") setInterval(() => {}, 1000);
else if (mode === "late-read") {
  process.on("SIGTERM", () => {
    readSkill("late", "standard-apply");
    finish();
    process.exit(0);
  });
  setInterval(() => {}, 1000);
} else if (grader) {
  assert.equal(value("--tools"), "", "grader exposes tools");
  assert.equal(process.env.SKILL_EVAL_ISOLATED_SKILL, undefined);
  assert.equal(process.env.SKILL_EVAL_CONFIGURATION, undefined);
  assert(!fs.existsSync("skills"), "grader can see actor skills");
  assert(!fs.existsSync(".git"), "grader can see actor history");
  const config = JSON.parse(fs.readFileSync(value("--config"), "utf8"));
  assert.deepEqual(config.skills.customDirectories, []);
  const input = fs.readFileSync(0, "utf8");
  const sections = input.split("\\n\\n");
  const task = sections.find(section => section.startsWith("Task: ")).slice(6);
  const expectations = JSON.parse(sections.find(section => section.startsWith("Expectations: ")).slice(14));
  if (process.env.REGRESSION_SAVED_TASK) assert.equal(task, process.env.REGRESSION_SAVED_TASK);
  if (process.env.REGRESSION_SAVED_EXPECTATIONS) assert.deepEqual(expectations, JSON.parse(process.env.REGRESSION_SAVED_EXPECTATIONS));
  const grading = { expectations: expectations.map(text => ({ text, passed: true,
    evidence: "after-files.json: scripted consumer evidence, not model-quality evidence" })), feedback: "regression only" };
  if (mode === "wrong-rubric") grading.expectations[0].text = "another task";
  if (mode === "empty-evidence") grading.expectations[0].evidence = " ";
  if (mode === "nonboolean") grading.expectations[0].passed = "true";
  if (mode === "missing-feedback") delete grading.feedback;
  if (mode === "extra-property") grading.untrustedSuccess = true;
  if (mode === "tool-attempt") call("grader-tool", "read", { path: "README.md" }, "not permitted");
  finish(mode === "invalid-json" ? "not JSON" : JSON.stringify(grading), mode === "error-stop" ? "error" : "stop", mode !== "no-terminal");
} else if (process.env.REGRESSION_KIND === "trigger") {
  const skill = "standard-apply";
  if (mode === "negative") finish("該当なし");
  else if (mode === "competing-read") {
    call("other", "read", { path: "README.md" }, "ordinary workspace investigation before Skill selection");
    readSkill("target", skill);
    finish();
  } else if (mode === "competing-skill") {
    readSkill("other", "standard-audit");
    readSkill("target", skill);
    finish();
  } else if (mode === "similar-path") {
    call("other", "read", { path: "skills/standard-apply-extra/SKILL.md" }, fs.readFileSync("skills/standard-apply/SKILL.md", "utf8"));
    finish();
  } else {
    readSkill("target", skill, mode === "absolute-read" ? "absolute" : mode === "relative-read" ? "relative" : "uri",
      mode === "metadata-read" ? "metadata" : mode === "empty-read" ? "empty" : mode === "range-read" ? "range" : "full",
      mode === "failed-read", mode !== "requested-only");
    if (mode === "read-hang") setInterval(() => {}, 1000);
    else if (mode === "read-nonzero") { finish(); process.exitCode = 7; }
    else if (mode === "read-malformed") { process.stdout.write("not-json\\n"); finish(); }
    else finish("selection complete", mode === "error-stop" ? "error" : "stop", mode !== "no-terminal");
  }
} else if (process.env.REGRESSION_PRODUCT_ONLY) {
  checkProduct();
  finish("scripted product check; not model-quality evidence");
} else if (mode === "scope-projection") {
  readSkill("selected-skill", "standard-update");
  const projectionPath = "skills/standard-audit/evals/evals.json";
  const projectionText = fs.readFileSync(projectionPath, "utf8");
  const projection = JSON.parse(projectionText);
  assert.deepEqual(Object.keys(projection).sort(), ["evals", "skill_name"]);
  assert.equal(projection.skill_name, "standard-audit");
  assert(projection.evals.length >= 3);
  for (const entry of projection.evals) {
    assert.deepEqual(Object.keys(entry).sort(), ["id", "prompt"]);
    assert(Number.isInteger(entry.id));
    assert.equal(typeof entry.prompt, "string");
  }
  assert(fs.existsSync("skills/standard-audit/SKILL.md"));
  for (const name of ["standard-update", "standard-apply", "standard-feedback", "standard-conformance", "cli-design", "property-testing"]) {
    assert(!fs.existsSync("skills/" + name + "/evals"), "unexpected rubric: " + name);
  }
  call("scope-input", "read", { path: projectionPath }, projectionText);
  if (process.env.REGRESSION_PRODUCT_CHECK) checkProduct();
  finish("projected task choices are readable without grading rubrics");
} else if (process.env.REGRESSION_METHOD) {
  assert.equal(fs.existsSync("skills/cli-design/SKILL.md"), process.env.SKILL_EVAL_CONFIGURATION !== "without-skill");
  assert.equal(spawnSync("git", ["status", "--porcelain"], { encoding: "utf8" }).stdout, "");
  for (const file of ["target-project", "project-decisions", "architecture-decisions", "skills/cli-design/evals",
    "skills/standard-update/scripts/run-task-evals.mjs", "skills/standard-update/scripts/evaluator-regression.test.mjs"]) {
    assert(!fs.existsSync(file), "method context contains unrelated fixture or oracle: " + file);
  }
  if (process.env.SKILL_EVAL_CONFIGURATION !== "without-skill") readSkill("selected-skill", "cli-design");
  finish("scripted method task; not model-quality evidence");
} else {
  if (process.env.REGRESSION_GRADE_ONLY) throw new Error("grade-only executed actor");
  if (process.env.REGRESSION_ISOLATION) {
    assert(!fs.existsSync(".claude"), "generated legacy discovery directory");
    assert.equal(fs.existsSync("skills/standard-update/SKILL.md"), process.env.SKILL_EVAL_CONFIGURATION !== "without-skill");
    assert.equal(spawnSync("git", ["status", "--porcelain"], { encoding: "utf8" }).stdout, "");
    const forbidden = ["skills/standard-update/evals", "skills/standard-update/scripts/run-task-evals.mjs",
      "skills/standard-update/scripts/run-trigger-evals.mjs", "skills/standard-update/scripts/omp-eval-adapter.mjs",
      "skills/standard-update/scripts/omp-eval-policy.mjs",
      "skills/standard-update/scripts/skill-test.sh", "skills/standard-update/scripts/evaluator-regression.test.mjs"];
    for (const file of forbidden) {
      assert(!fs.existsSync(file), "actor oracle leak: " + file);
      assert.notEqual(spawnSync("git", ["show", "HEAD:" + file], { stdio: "ignore" }).status, 0);
      assert.notEqual(spawnSync("git", ["show", "HEAD^:" + file], { stdio: "ignore" }).status, 0);
    }
    const config = JSON.parse(fs.readFileSync(value("--config"), "utf8"));
    for (const key of ["enablePiUser", "enablePiProject", "enableClaudeUser", "enableClaudeProject",
      "enableCodexUser", "enableAgentsUser", "enableAgentsProject"]) assert.equal(config.skills[key], false, key);
    for (const directory of config.skills.customDirectories) {
      assert(path.resolve(directory).startsWith(process.cwd() + path.sep), "external skill discovery: " + directory);
    }
  }
  if (process.env.SKILL_EVAL_CONFIGURATION !== "without-skill" && mode !== "no-skill-read") {
    readSkill("selected-skill", process.env.SKILL_EVAL_ISOLATED_SKILL, "uri",
      mode === "metadata-skill-read" ? "metadata" : "full", mode === "failed-skill-read");
  }
  if (process.env.REGRESSION_PRODUCT_CHECK) checkProduct();
  fs.appendFileSync("concerns/configuration/config-vs-flags.md", "\\nscripted changed content\\n");
  fs.writeFileSync("docs/research/ignored-evidence.txt", "untracked or ignored consumer artifact");
  call("evidence-read", "read", { path: "docs/research/maintenance-input.md" }, "x".repeat(6000));
  if (mode === "failed-tool") call("failed-command", "bash", { command: "false" }, "exit=1", true);
  finish("actual final response", mode === "error-stop" ? "error" : "stop", mode !== "no-terminal");
  if (mode === "terminal-nonzero") process.exitCode = 7;
}
`, { mode: 0o755 });

function invoke(executable, args, env = {}) {
  const environment = { ...process.env, OMP_EVAL_COMMAND: provider, OMP_EVAL_MODEL: "", OMP_EVAL_TIMEOUT_MS: "5000", ...env };
  delete environment.NODE_TEST_CONTEXT;
  const result = spawnSync(process.execPath, [executable, ...args], {
    encoding: "utf8", timeout: 30_000,
    env: environment,
  });
  assert.equal(result.error, undefined, result.error?.message);
  assert.equal(result.signal, null, result.stdout + result.stderr);
  return result;
}

function trigger(mode, query = positiveQuery, env = {}) {
  const result = invoke(triggerRunner, ["standard-apply", String(query)], {
    REGRESSION_KIND: "trigger", REGRESSION_CASE: mode, ...env,
  });
  const observable = JSON.parse(result.stdout);
  assert.equal(observable.results.length, 1);
  return { ...result, observed: observable.results[0] };
}

function runTask(name, configuration = "with-skill", env = {}, extra = []) {
  const output = path.join(root, name);
  const result = invoke(taskRunner, ["--configuration", configuration, "--skill", "standard-update", "--eval-id", "10", ...extra], {
    SKILL_EVAL_OUTPUT_ROOT: output, REGRESSION_KIND: "task", REGRESSION_CASE: "valid", ...env,
  });
  return { ...result, output, run: path.join(output, "standard-update", "eval-10-default", configuration),
    evalRoot: path.join(output, "standard-update", "eval-10-default") };
}

function success(result) {
  const actorError = result.status !== 0 && result.run && existsSync(path.join(result.run, "stderr.txt"))
    ? readFileSync(path.join(result.run, "stderr.txt"), "utf8") : "";
  assert.equal(result.status, 0, result.stdout + result.stderr + actorError);
}

function failure(result) {
  assert.equal(result.status, 1, result.stdout + result.stderr);
}

test("trigger selection requires a successful complete read and terminal OMP outcome", () => {
  for (const mode of ["valid", "relative-read", "absolute-read"]) {
    const result = trigger(mode);
    success(result);
    assert.equal(result.observed.selected_skill, "standard-apply");
    assert.equal(result.observed.triggered, true);
    assert.equal(result.observed.error, null);
  }
  const negative = trigger("negative", negativeQuery);
  success(negative);
  assert.equal(negative.observed.selected_skill, null);
  assert.equal(negative.observed.triggered, false);
  const similar = trigger("similar-path");
  failure(similar);
  assert.notEqual(similar.observed.selected_skill, "standard-apply");
});

test("malformed, nonzero, incomplete, failed and timed-out trigger observations never pass", () => {
  for (const mode of ["nonzero", "malformed", "truncated", "no-terminal", "error-stop", "failed-read", "requested-only",
    "metadata-read", "empty-read", "range-read", "read-nonzero", "read-malformed"]) {
    const result = trigger(mode, ["metadata-read", "empty-read", "range-read"].includes(mode) ? positiveQuery : negativeQuery);
    failure(result);
    assert.equal(result.observed.pass, false);
    if (["nonzero", "malformed", "truncated", "no-terminal", "error-stop", "failed-read", "requested-only", "read-nonzero", "read-malformed"].includes(mode)) {
      assert.equal(typeof result.observed.error, "string", mode);
    }
  }
  for (const mode of ["hang", "read-hang", "late-read"]) {
    const result = trigger(mode, negativeQuery, { OMP_EVAL_TIMEOUT_MS: "200" });
    failure(result);
    assert.equal(result.observed.pass, false);
    assert.match(result.observed.error, /timeout|timed out/i);
    if (mode === "late-read") assert.equal(result.observed.selected_skill, null);
  }
});

test("a competing read or skill cannot be repaired by a later target read", () => {
  for (const mode of ["competing-read", "competing-skill"]) {
    const result = trigger(mode);
    failure(result);
    assert.equal(result.observed.pass, false);
    assert(result.observed.error || result.observed.selected_skill !== "standard-apply");
  }
});

test("task failures remain errors after plausible final output", () => {
  for (const mode of ["nonzero", "malformed", "truncated", "no-terminal", "error-stop", "terminal-nonzero",
    "no-skill-read", "failed-skill-read", "metadata-skill-read", "changed-model", "hang"]) {
    const result = runTask("task-error-" + mode, "with-skill", {
      REGRESSION_CASE: mode, ...(mode === "hang" ? { OMP_EVAL_TIMEOUT_MS: "200" } : {}),
    });
    failure(result);
    const timing = load(path.join(result.run, "timing.json"));
    const outcome = load(path.join(result.run, "result.json"));
    assert(timing.error || outcome.is_error, mode);
  }
});

test("repeated OMP message envelopes do not duplicate usage or completed tool evidence", () => {
  const result = runTask("deduplicated-artifacts", "with-skill", { REGRESSION_CASE: "failed-tool" });
  success(result);
  const evidence = load(path.join(result.run, "tool-evidence.json"));
  assert.equal(evidence.length, 3);
  assert.equal(evidence[0].name, "read");
  assert.equal(evidence[0].input.path, "skill://standard-update");
  assert.equal(evidence[1].name, "read");
  assert.equal(evidence[1].status, "succeeded");
  assert.deepEqual(evidence[1].result, [{ type: "text", text: "x".repeat(6000) }]);
  assert.equal(evidence[2].name, "bash");
  assert.equal(evidence[2].status, "error");
  assert.deepEqual(evidence[2].result, [{ type: "text", text: "exit=1" }]);
  assert.equal(readFileSync(path.join(result.run, "final.md"), "utf8").trim(), "actual final response");
  const outcome = load(path.join(result.run, "result.json"));
  assert.equal(outcome.usage.input, 16);
  assert.equal(outcome.usage.output, 8);
  assert.equal(Object.keys(outcome.model_usage).length, 1);
  const changed = load(path.join(result.run, "changed-files.json"));
  assert(changed.includes("docs/research/ignored-evidence.txt"));
  assert.equal(load(path.join(result.run, "after-files.json"))["docs/research/ignored-evidence.txt"], "untracked or ignored consumer artifact");
  assert.equal(load(path.join(result.run, "before-files.json"))["docs/research/ignored-evidence.txt"], null);
});

test("task and grader isolate ambient skills, history and oracle files", () => {
  const marker = path.join(root, "isolated-invocations.jsonl");
  for (const configuration of ["without-skill", "with-skill"]) {
    const result = runTask("isolation", configuration, {
      REGRESSION_ISOLATION: "1",
      REGRESSION_INVOCATIONS: marker,
    }, ["--grade"]);
    success(result);
    assert.equal(load(path.join(result.run, "grading.json")).summary.overall_pass, true);
  }
  const calls = readFileSync(marker, "utf8").trim().split("\n").map(line => JSON.parse(line));
  assert.deepEqual(calls.map(call => call.grader), [false, true, false, true]);
  assert(calls.every(call => !existsSync(call.cwd)), "isolated fixture remains after execution");
});

test("actual actor fixtures retain valid product checks without exposing hidden instructions or rubrics", () => {
  for (const configuration of ["old-skill", "with-skill"]) {
    const result = runTask("actor-product-check", configuration, {
      REGRESSION_PRODUCT_CHECK: "1", OMP_EVAL_TIMEOUT_MS: "25000",
    });
    success(result);
    const check = load(path.join(result.run, "tool-evidence.json")).find(event => event.id === "product-check");
    assert.equal(check.status, "succeeded");
    assert(check.result[0].text.includes("PASS: skill package structure and applicable checks"));
  }
  const conformanceWithout = invoke(taskRunner, [
    "--configuration", "without-skill", "--skill", "standard-conformance", "--eval-id", "1",
  ], {
    SKILL_EVAL_OUTPUT_ROOT: path.join(root, "conformance-product-check"),
    REGRESSION_PRODUCT_ONLY: "1", OMP_EVAL_TIMEOUT_MS: "25000",
  });
  success(conformanceWithout);
  for (const configuration of ["old-skill", "with-skill"]) {
    const output = path.join(root, "scope-product-check");
    const result = invoke(taskRunner, ["--configuration", configuration, "--skill", "standard-update", "--eval-id", "4"], {
      SKILL_EVAL_OUTPUT_ROOT: output, REGRESSION_CASE: "scope-projection",
      REGRESSION_PRODUCT_CHECK: "1", OMP_EVAL_TIMEOUT_MS: "25000",
    });
    success(result);
  }
});

test("default selector and explicit override record the actual provider model without fallback", () => {
  const marker = path.join(root, "model-invocations.jsonl");
  const normal = runTask("default-model", "with-skill", { REGRESSION_INVOCATIONS: marker });
  success(normal);
  const definitions = load(path.join(repo, "skills/standard-update/evals/evals.json"));
  const explicitFile = path.join(root, "explicit-model-eval.json");
  save(explicitFile, { skill_name: definitions.skill_name,
    evals: [{ ...definitions.evals.find(item => item.id === 10), model: "regression/eval-selector" }] });
  const explicit = runTask("explicit-eval-model", "with-skill", {
    REGRESSION_INVOCATIONS: marker, REGRESSION_ACTUAL_MODEL: "eval-selector",
  }, ["--eval-file", explicitFile]);
  success(explicit);
  const override = runTask("override-model", "with-skill", {
    OMP_EVAL_MODEL: "regression/explicit-model", REGRESSION_ACTUAL_MODEL: "explicit-model",
    REGRESSION_INVOCATIONS: marker, REGRESSION_CONFIG_ERROR: "1",
  });
  success(override);
  const calls = readFileSync(marker, "utf8").trim().split("\n").map(line => JSON.parse(line));
  assert.deepEqual(calls.map(call => call.model), ["regression/regression-model:medium", "regression/eval-selector", "regression/explicit-model"]);
  assert.equal(load(path.join(normal.run, "eval_metadata.json")).model, "default");
  const actualModels = Object.keys(load(path.join(override.run, "result.json")).model_usage);
  assert.deepEqual(actualModels, ["regression/explicit-model"]);
  const metadata = load(path.join(override.run, "eval_metadata.json"));
  assert.deepEqual(metadata.actual_models, actualModels);
  assert.equal(metadata.resolved_model_selector, "regression/explicit-model");
  const refused = runTask("refused-model", "with-skill", {
    OMP_EVAL_MODEL: "regression/missing-model", REGRESSION_CASE: "nonzero", REGRESSION_INVOCATIONS: marker,
  });
  failure(refused);
  assert.equal(readFileSync(marker, "utf8").trim().split("\n").length, 4, "runner retried with a fallback model");
  const unavailableDefault = runTask("missing-default-model", "with-skill", {
    REGRESSION_CONFIG_ERROR: "1", REGRESSION_INVOCATIONS: marker,
  });
  failure(unavailableDefault);
  assert.equal(readFileSync(marker, "utf8").trim().split("\n").length, 4, "unresolved default launched a model");
});

test("invalid graders cannot turn missing, malformed or untrusted evidence into a pass", () => {
  const initial = runTask("grader-rejections");
  success(initial);
  for (const mode of ["wrong-rubric", "empty-evidence", "nonboolean", "missing-feedback", "extra-property", "invalid-json",
    "tool-attempt", "error-stop", "nonzero", "malformed", "no-terminal"]) {
    const result = runTask("grader-rejections", "with-skill", {
      REGRESSION_GRADE_ONLY: "1", REGRESSION_GRADER_CASE: mode,
    }, ["--grade-only"]);
    failure(result);
    const grading = load(path.join(result.run, "grading.json"));
    assert.equal(grading.summary.overall_pass, false, mode);
    assert.equal(typeof grading.error, "string", mode);
  }
});

test("saved task rubric is authoritative and incompatible grading provenance blocks comparison", () => {
  for (const configuration of ["old-skill", "with-skill"]) {
    const result = runTask("grading-provenance", configuration, {}, ["--grade"]);
    success(result);
  }
  const evalRoot = path.join(root, "grading-provenance/standard-update/eval-10-default");
  const benchmark = () => load(path.join(evalRoot, "benchmark.json"));
  assert.equal(benchmark().comparable, true);
  const savedPrompt = "historical saved task prompt";
  const savedExpectations = ["historical saved expectation"];
  for (const configuration of ["old-skill", "with-skill"]) {
    const file = path.join(evalRoot, configuration, "eval_metadata.json");
    save(file, { ...load(file), prompt: savedPrompt, expectations: savedExpectations });
  }
  const grade = (configuration, env = {}) => {
    const result = runTask("grading-provenance", configuration, {
      REGRESSION_GRADE_ONLY: "1", REGRESSION_SAVED_TASK: savedPrompt,
      REGRESSION_SAVED_EXPECTATIONS: JSON.stringify(savedExpectations), ...env,
    }, ["--grade-only"]);
    success(result);
    return result;
  };
  grade("old-skill");
  const current = grade("with-skill");
  assert.equal(benchmark().comparable, true);
  const grading = load(path.join(current.run, "grading.json"));
  assert.deepEqual(grading.expectations.map(item => item.text), savedExpectations);
  assert.equal(grading.provenance.task_prompt, savedPrompt);
  assert.deepEqual(grading.provenance.expectations, savedExpectations);
  grade("with-skill", { REGRESSION_ACTUAL_MODEL: "different-grader-model" });
  assert.equal(benchmark().comparable, false);
  assert.equal(benchmark().delta_with_minus_old, null);
  grade("with-skill");
  const metadataFile = path.join(current.run, "eval_metadata.json");
  const original = load(metadataFile);
  for (const mutation of [
    { ...original, command_args: [...original.command_args, "--unexpected-option"] },
    { ...original, command_normalization: undefined },
    { ...original, command_normalization: { ...original.command_normalization, control_directory: "/different-control" } },
  ]) {
    save(metadataFile, mutation);
    grade("with-skill");
    assert.equal(benchmark().comparable, false);
    assert.equal(benchmark().delta_with_minus_old, null);
  }
  for (const field of ["execution_settings_sha256", "task_sha256", "standard_sha256"]) {
    save(metadataFile, { ...original, [field]: digest("different " + field) });
    grade("with-skill");
    assert.equal(benchmark().comparable, false, field);
    assert.equal(benchmark().delta_with_minus_old, null);
  }
  save(metadataFile, original);
  grade("with-skill");
  assert.equal(benchmark().comparable, true);
  const oldGradingFile = path.join(evalRoot, "old-skill/grading.json");
  const oldGrading = load(oldGradingFile);
  const withoutProvenance = structuredClone(oldGrading);
  delete withoutProvenance.provenance;
  save(oldGradingFile, withoutProvenance);
  grade("with-skill");
  assert.equal(benchmark().comparable, false);
  assert.equal(benchmark().delta_with_minus_old, null);
  save(oldGradingFile, oldGrading);
  grade("with-skill");
  assert.equal(benchmark().comparable, true);
  const rerun = runTask("grading-provenance", "with-skill", { REGRESSION_CASE: "nonzero" });
  failure(rerun);
  assert(!existsSync(path.join(current.run, "grading.json")), "rerun retained obsolete grading");
  assert(!existsSync(path.join(evalRoot, "benchmark.json")), "rerun retained obsolete comparison");
});

test("a historical missing method skill is unavailable rather than invented or executed", () => {
  const fixture = path.join(root, "historical-method-source");
  const git = args => {
    const result = spawnSync("git", ["-C", fixture, ...args], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stdout.trim();
  };
  const cloned = spawnSync("git", ["clone", "--quiet", "--no-hardlinks", repo, fixture], { encoding: "utf8" });
  assert.equal(cloned.status, 0, cloned.stdout + cloned.stderr);
  cpSync(path.join(repo, "skills"), path.join(fixture, "skills"), { recursive: true, force: true });
  rmSync(path.join(fixture, "skills/cli-design"), { recursive: true, force: true });
  git(["add", "-A", "--", "skills"]);
  git(["-c", "user.name=Skill Test", "-c", "user.email=skill-test@example.invalid", "-c", "commit.gpgSign=false",
    "commit", "--quiet", "--allow-empty", "-m", "test: 過去版での方法 Skill 欠落条件の用意"]);
  const baseline = git(["rev-parse", "HEAD"]);
  cpSync(path.join(repo, "skills/cli-design"), path.join(fixture, "skills/cli-design"), { recursive: true });
  const marker = path.join(root, "historical-provider-calls");
  const output = path.join(root, "historical-method-evals");
  for (const mode of ["--grade", "--grade-only"]) {
    const result = invoke(path.join(fixture, "skills/standard-update/scripts/run-task-evals.mjs"), [
      "--configuration", "old-skill", "--skill", "cli-design", "--eval-id", "1", "--baseline-ref", baseline, mode,
    ], { SKILL_EVAL_OUTPUT_ROOT: output, REGRESSION_INVOCATIONS: marker });
    success(result);
  }
  assert(!existsSync(marker), "historical absence launched a provider or grader");
  const run = path.join(output, "cli-design/eval-1-default/old-skill");
  assert.equal(load(path.join(run, "historical-unavailable.json")).baseline_commit, baseline);
  assert(!existsSync(path.join(run, "eval_metadata.json")));
  assert(!existsSync(path.join(run, "grading.json")));
  const methodRunner = path.join(fixture, "skills/standard-update/scripts/run-task-evals.mjs");
  const evalRoot = path.join(output, "cli-design/eval-1-default");
  for (const configuration of ["without-skill", "with-skill"]) {
    const result = invoke(methodRunner, ["--configuration", configuration, "--skill", "cli-design",
      "--eval-id", "1", "--baseline-ref", baseline, "--grade"], {
      SKILL_EVAL_OUTPUT_ROOT: output, REGRESSION_METHOD: "1",
    });
    success(result);
  }
  const without = load(path.join(evalRoot, "without-skill/eval_metadata.json"));
  const withSkill = load(path.join(evalRoot, "with-skill/eval_metadata.json"));
  for (const field of ["fixture_sha256", "target_input_sha256", "standard_sha256", "task_sha256",
    "execution_settings_sha256", "baseline_commit"]) assert.equal(without[field], withSkill[field], field);
  assert.equal(without.instruction_sha256, null);
  assert.equal(typeof withSkill.instruction_sha256, "string");
  const benchmark = load(path.join(evalRoot, "benchmark.json"));
  assert.equal(benchmark.comparison_configuration, "without-skill");
  assert.equal(benchmark.comparable, true);
  assert(benchmark.delta_with_minus_without);
  assert(!Object.hasOwn(benchmark, "delta_with_minus_old"));
});

test("a baseline missing a neutral package fails before provider execution", () => {
  const fixture = path.join(root, "incomplete-baseline-source");
  const cloned = spawnSync("git", ["clone", "--quiet", "--no-hardlinks", repo, fixture], { encoding: "utf8" });
  assert.equal(cloned.status, 0, cloned.stdout + cloned.stderr);
  cpSync(path.join(repo, "skills"), path.join(fixture, "skills"), { recursive: true, force: true });
  rmSync(path.join(fixture, "skills/standard-audit/SKILL.md"));
  for (const args of [
    ["add", "-A", "--", "skills"],
    ["-c", "user.name=Skill Test", "-c", "user.email=skill-test@example.invalid", "-c", "commit.gpgSign=false",
      "commit", "--quiet", "-m", "test: 比較元での共通 Skill 欠落条件の用意"],
  ]) {
    const result = spawnSync("git", ["-C", fixture, ...args], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  }
  const marker = path.join(root, "incomplete-baseline-provider-calls");
  for (const configuration of ["old-skill", "without-skill", "with-skill"]) {
    const result = invoke(path.join(fixture, "skills/standard-update/scripts/run-task-evals.mjs"), [
      "--configuration", configuration, "--skill", "standard-audit", "--eval-id", "1",
    ], { SKILL_EVAL_OUTPUT_ROOT: path.join(root, "incomplete-baseline-evals"), REGRESSION_INVOCATIONS: marker });
    failure(result);
    assert.match(result.stdout + result.stderr, /lacks neutral skill package skills\/standard-audit\/SKILL\.md/);
    assert(!existsSync(marker), "incomplete baseline launched a provider");
  }
});

test("scope-selection tasks receive public task choices without evaluator rubrics", () => {
  const output = path.join(root, "scope-projection-evals");
  for (const configuration of ["old-skill", "with-skill"]) {
    const result = invoke(taskRunner, ["--configuration", configuration, "--skill", "standard-update", "--eval-id", "4"], {
      SKILL_EVAL_OUTPUT_ROOT: output, REGRESSION_CASE: "scope-projection",
    });
    success(result);
    const run = path.join(output, "standard-update/eval-4-default", configuration);
    const evidence = load(path.join(run, "tool-evidence.json"));
    const publicInput = evidence.find(call => call.id === "scope-input");
    assert.equal(publicInput.status, "succeeded");
    const projection = JSON.parse(publicInput.result[0].text);
    assert(projection.evals.every(entry => Object.keys(entry).length === 2));
  }
});
test("unknown event and terminal content cannot pass a negative routing query", () => {
  const message = { role: "assistant", provider: "regression", model: "model",
    stopReason: "stop", content: [{ type: "text", text: "none" }] };
  const events = [{ type: "message_end", message }, { type: "agent_end", messages: [message] }];
  const parse = value => parseOmpStream(value.map(event => JSON.stringify(event)).join("\n"), []);
  assert.equal(parse(events).is_error, false);
  const call = { id: "edit-stream", name: "edit", arguments: { input: "patch" } };
  const toolMessage = { ...message, stopReason: "toolUse", content: [{ type: "toolCall", ...call }] };
  const streamed = [
    { type: "message_end", message: toolMessage },
    { type: "tool_execution_start", toolCallId: call.id, toolName: call.name, args: call.arguments },
    { type: "tool_stream_update", toolCallId: call.id, toolName: call.name },
    { type: "tool_execution_end", toolCallId: call.id, toolName: call.name,
      result: { content: [{ type: "text", text: "edited" }] }, isError: false },
    ...events,
  ];
  const completed = parseOmpStream(streamed.map(event => JSON.stringify(event)).join("\n"), ["edit"]);
  assert.equal(completed.error, null);
  assert.equal(completed.tool_evidence[0].status, "succeeded");
  assert.equal(parse([{ type: "undocumented_event" }, ...events]).is_error, true);
  for (const content of [[{ type: "undocumented_content" }], [{ type: "thinking", thinking: "no answer" }]]) {
    const invalid = { ...message, content };
    assert.equal(parse([{ type: "message_end", message: invalid },
      { type: "agent_end", messages: [invalid] }]).is_error, true);
  }
});

test("provider hooks expose only allowed tool schemas and reject forbidden calls before execution", async () => {
  const control = mkdtempSync(path.join(root, "policy-control-"));
  const workspace = mkdtempSync(path.join(root, "policy-workspace-"));
  const extensionFile = path.join(control, "policy.mjs");
  cpSync(path.join(scripts, "omp-eval-policy.mjs"), extensionFile);
  const { default: install } = await import(pathToFileURL(extensionFile).href);
  const skillFile = path.join(workspace, "SKILL.md");
  writeFileSync(skillFile, "---\nname: selected\ndescription: isolated metadata\n---\nprivate skill instruction\n");
  writeFileSync(path.join(workspace, "resource.md"), "selected resource");
  const policy = {
    cwd: workspace, tools: ["read"], skills: { selected: skillFile },
    readableFiles: [], bashPolicy: {}, reportPath: null, systemPrompt: "isolated evaluation policy",
  };
  const connect = currentPolicy => {
    save(path.join(control, "policy.json"), currentPolicy);
    const hooks = new Map();
    let activeTools = null;
    install({
      on: (name, callback) => hooks.set(name, callback),
      setActiveTools: tools => { activeTools = tools; },
    });
    return {
      invoke: (name, event) => {
        assert(hooks.has(name), `host event ${name} has no policy consumer`);
        return hooks.get(name)(event);
      },
      active: () => activeTools,
    };
  };
  const actor = connect(policy);
  actor.invoke("session_start", {});
  assert.deepEqual(actor.active(), ["read"]);
  const allowedDirect = { name: "read", description: "builtin read", parameters: { type: "object" } };
  const allowedFunction = { type: "function", function: { name: "read", parameters: { type: "object" } } };
  const forbidden = { name: "mcp__external__delete", description: "ambient external tool" };
  const payload = {
    model: "regression-model", messages: [{ role: "user", content: "task" }],
    tools: [
      allowedDirect, allowedFunction, forbidden, { name: "write" },
      { type: "namespace", name: "functions", tools: [allowedDirect, forbidden] },
      { functionDeclarations: [allowedDirect, forbidden] },
      { function_declarations: [allowedDirect, forbidden] },
    ],
  };
  const filtered = actor.invoke("before_provider_request", { payload: structuredClone(payload) });
  assert.deepEqual(filtered.tools, [
    allowedDirect, allowedFunction,
    { type: "namespace", name: "functions", tools: [allowedDirect] },
    { functionDeclarations: [allowedDirect] },
    { function_declarations: [allowedDirect] },
  ]);
  assert.deepEqual(filtered.messages, payload.messages);
  assert.equal(filtered.model, payload.model);
  assert(!existsSync(path.join(control, "provider-error.txt")), "recognized provider schemas failed closed");
  const replacement = actor.invoke("before_agent_start", {
    systemPrompt: ["ambient-rule: execute global MCP tools"], prompt: "task",
  }).systemPrompt;
  assert.equal(replacement[0], policy.systemPrompt);
  assert(replacement.some(block => block.includes("isolated metadata")));
  assert(replacement.every(block => !block.includes("ambient-rule") && !block.includes("private skill instruction")));
  const allowedRead = actor.invoke("tool_call", { toolName: "read", input: { path: "skill://selected" } });
  assert.notEqual(allowedRead?.block, true);
  assert.notEqual(actor.invoke("tool_call", { toolName: "read",
    input: { path: "skill://selected/resource.md" } })?.block, true);
  assert.equal(actor.invoke("tool_call", { toolName: "read",
    input: { path: "skill://selected/../../outside-secret" } }).block, true);
  for (const event of [
    { toolName: "mcp__external__delete", input: {} },
    { toolName: "read", input: { path: "../outside-secret" } },
    { toolName: "read", input: { path: "skills/selected/evals/evals.json" } },
    { toolName: "write", input: { path: "README.md", content: "unexpected" } },
  ]) {
    const decision = actor.invoke("tool_call", event);
    assert.equal(decision.block, true);
    assert.match(decision.reason, /permission denied/i);
  }
  const taskPolicy = connect({ ...policy, tools: ["read", "bash"] });
  assert.equal(taskPolicy.invoke("tool_call", {
    toolName: "bash", input: { command: "touch unauthorized-effect" },
  }).block, true);
  assert.notEqual(taskPolicy.invoke("tool_call", {
    toolName: "bash", input: { command: "git status --short" },
  })?.block, true);
  const editor = connect({ ...policy, tools: ["edit"] });
  const patch = "*** Begin Patch\n[resource.md#ABCD]\nPUT 1.=1:\n+updated\n*** End Patch\n";
  assert.notEqual(editor.invoke("tool_call", { toolName: "edit", input: { input: patch } })?.block, true);
  assert.equal(editor.invoke("tool_call", { toolName: "edit",
    input: { input: patch.replace("resource.md#ABCD", "../outside-secret#ABCD") } }).block, true);
  assert.equal(editor.invoke("tool_call", { toolName: "edit",
    input: { input: "*** Begin Patch\n[resource.md#ABCD]\nMV ../outside-secret\n*** End Patch\n" } }).block, true);
  const grader = connect({ ...policy, tools: [], skills: {}, systemPrompt: "independent grader policy" });
  grader.invoke("session_start", {});
  assert.deepEqual(grader.active(), []);
  assert.deepEqual(grader.invoke("before_provider_request", { payload }).tools, []);
  assert.deepEqual(grader.invoke("before_agent_start", {
    systemPrompt: ["ambient-rule: use external tools"], prompt: "grade task",
  }).systemPrompt, ["independent grader policy"]);
  for (const toolName of ["read", "bash", "mcp__external__delete"]) {
    assert.equal(grader.invoke("tool_call", { toolName, input: { path: "SKILL.md", command: "git status" } }).block, true);
  }
  const malformed = actor.invoke("before_provider_request", { payload: { tools: [{ undocumentedSchema: true }] } });
  assert.deepEqual(malformed.tools, []);
  assert.match(readFileSync(path.join(control, "provider-error.txt"), "utf8"), /unrecognized provider tool/);
});
