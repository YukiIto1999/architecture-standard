#!/usr/bin/env node
import { execFileSync, spawn } from "node:child_process";
import { cpSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import process from "node:process";

const repoRoot = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
const args = process.argv.slice(2);
const configuration = valueAfter("--configuration");
const selectedSkill = valueAfter("--skill");
const selectedEvalId = valueAfter("--eval-id");

if (!new Set(["old-skill", "without-skill", "with-skill"]).has(configuration)) {
  throw new Error("--configuration must be old-skill, without-skill, or with-skill");
}

const skillNames = selectedSkill
  ? [selectedSkill]
  : ["standard-apply", "standard-audit", "standard-update"];
const outputRoot = process.env.SKILL_EVAL_OUTPUT_ROOT
  ? path.resolve(process.env.SKILL_EVAL_OUTPUT_ROOT)
  : path.join(repoRoot, "docs", "reviews", "skill-evals", "iteration-1");
const claudeCommand = process.env.CLAUDE_EVAL_COMMAND || "claude";
let hadError = false;

for (const skillName of skillNames) {
  const evalPath = path.join(repoRoot, ".claude", "skills", skillName, "evals", "evals.json");
  const data = JSON.parse(readFileSync(evalPath, "utf8"));
  if (data.skill_name !== skillName) throw new Error(`${evalPath}: skill_name mismatch`);

  const evals = selectedEvalId
    ? data.evals.filter((item) => String(item.id) === selectedEvalId)
    : data.evals;
  if (evals.length === 0) throw new Error(`${skillName}: eval ${selectedEvalId} not found`);
  for (const item of evals) {
    await runEval(skillName, item);
  }
}
if (hadError) process.exitCode = 1;

async function runEval(skillName, item) {
  const runRoot = path.join(outputRoot, skillName, `eval-${item.id}-${item.model}`, configuration);
  rmSync(runRoot, { recursive: true, force: true });
  mkdirSync(runRoot, { recursive: true });

  const fixtureRoot = mkdtempSync(path.join(tmpdir(), `architecture-standard-${skillName}-${item.id}-`));
  const startedAt = new Date();

  try {
    execFileSync("git", ["clone", "--quiet", "--no-hardlinks", repoRoot, fixtureRoot]);
    if (configuration === "with-skill") overlayWorkingFiles(fixtureRoot, skillName);
    if (configuration === "without-skill") removeSkill(fixtureRoot, skillName);
    scrubFixtureMutationSource(fixtureRoot);
    hideCurrentSkillEvaluationOracles(fixtureRoot, skillName);
    const standardCommit = initializeSanitizedRepository(fixtureRoot);
    prepareFixture(fixtureRoot, standardCommit);
    initializeFixtureCommit(fixtureRoot);
    prepareEvaluationChange(fixtureRoot, skillName, item.id);

    const prompt = [
      "これは実タスク評価です。確認質問で止まらず、与えられた範囲を最後まで実行してください。",
      "作業対象は現在の一時fixtureだけです。元のrepositoryへは書き込まないでください。",
      "task の path は現在の作業directoryからの相対pathです。外部事実の確認が task に必要なら WebSearch と WebFetch を使えます。Bash は許可済みの検証 script と git show/status/diff だけに使ってください。",
      "ls、find、wc、cat、git log、git rev-parse を Bash で実行しないでください。file の読取と探索には Read、Glob、Grep を使えます。どれを使うかは task と、with-skill または old-skill では対象 skill の指示から判断してください。",
      "対象 skill が最初の対象 project 操作または閉じた参照経路を定める場合は、他の対象 project 操作より優先してください。この共通 prompt はその順序や禁止 tool の例外を作りません。",
      "skill が exact path、exact token、Glob pattern、回数を固定した場合は、その値を変えた試行や候補探索を前後に追加しないでください。禁止操作を後から自己申告しても経路遵守には戻らないため、最初の一回から固定値を使ってください。",
      "task が file を変更し、使用する skill が検証を要求する場合は、repository root から `bash .claude/skills/standard-update/scripts/verify.sh` の形で実行してください。読み取り専用 task へ検証を強制しないでください。",
      "この隔離評価では subagent は利用できません。skill が独立 reviewer を明示的に要求する場合だけ、その fallback として同じ session で scoped self-audit を行い、Agent や background task を起動して待たないでください。skill が要求しない self-audit は追加せず、閉じた経路が tool または file を制限する場合は fallback でもその範囲を広げないでください。",
      configuration === "without-skill"
        ? "この評価では project skill を使わずに実行してください。"
        : `これは発火評価ではありません。最初に Read tool で .claude/skills/${skillName}/SKILL.md を全文読み、その指示に従ってください。Skill(...) のような呼出し文字列を応答するだけで終えないでください。参照 resource は SKILL.md が必要としたものだけを読んでください。`,
      item.prompt,
    ].join("\n\n");

    const commandArgs = [
      "-p",
      prompt,
      "--output-format",
      "stream-json",
      "--verbose",
      "--no-session-persistence",
      "--permission-mode",
      "acceptEdits",
      "--allowedTools",
      "Read",
      "Glob",
      "Grep",
      "Edit",
      "Write",
      "WebSearch",
      "WebFetch",
      "Bash(bash .claude/skills/standard-update/scripts/verify.sh)",
      "Bash(*.claude/skills/standard-update/scripts/verify.sh*)",
      "Bash(bash .claude/skills/standard-update/scripts/verify-test.sh)",
      "Bash(bash .claude/skills/standard-update/scripts/skill-package-check.sh)",
      "Bash(git show *)",
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git -C * show *)",
      "Bash(git -C * status *)",
      "Bash(git -C * diff *)",
      "--disallowedTools",
      "Agent",
      "--setting-sources",
      "project",
      "--model",
      item.model,
      "--max-budget-usd",
      budgetFor(item.model),
    ];
    const env = { ...process.env };
    delete env.CLAUDECODE;
    env.SKILL_EVAL_ISOLATED_SKILL = skillName;
    env.SKILL_EVAL_CONFIGURATION = configuration;
    const result = await executeClaude(commandArgs, fixtureRoot, env, timeoutFor(item.model));
    const endedAt = new Date();
    const parsed = parseClaudeResult(result.stdout);
    const toolEvidence = collectToolEvidence(parsed.events);
    const { events, ...resultSummary } = parsed;

    writeFileSync(path.join(runRoot, "eval_metadata.json"), `${JSON.stringify({
      eval_id: item.id,
      eval_name: `${skillName}-${item.id}-${item.model}`,
      prompt: item.prompt,
      expectations: item.expectations,
      configuration,
      model: item.model,
    }, null, 2)}\n`);
    writeFileSync(path.join(runRoot, "result.json"), `${JSON.stringify(resultSummary, null, 2)}\n`);
    writeFileSync(path.join(runRoot, "final.md"), `${parsed.result ?? ""}\n`);
    writeFileSync(path.join(runRoot, "events.jsonl"), result.stdout ?? "");
    writeFileSync(path.join(runRoot, "tool-evidence.json"), `${JSON.stringify(toolEvidence, null, 2)}\n`);
    writeFileSync(path.join(runRoot, "stderr.txt"), result.stderr ?? "");
    writeFileSync(path.join(runRoot, "status.txt"), gitOutput(fixtureRoot, ["status", "--short"]));
    writeFileSync(path.join(runRoot, "status-ignored.txt"), gitOutput(fixtureRoot, ["status", "--short", "--ignored=matching"]));
    writeFileSync(path.join(runRoot, "diff.patch"), gitOutput(fixtureRoot, ["diff", "--no-ext-diff", "--binary"]));
    writeFileSync(path.join(runRoot, "timing.json"), `${JSON.stringify({
      executor_start: startedAt.toISOString(),
      executor_end: endedAt.toISOString(),
      executor_duration_seconds: (endedAt.getTime() - startedAt.getTime()) / 1000,
      total_cost_usd: parsed.total_cost_usd ?? null,
      usage: parsed.usage ?? null,
      exit_status: result.status,
      signal: result.signal,
      terminal_result_received: result.terminalResultReceived,
      terminated_after_result: result.terminatedAfterResult,
      error: result.error ?? null,
    }, null, 2)}\n`);

    const outcome = result.terminalResultReceived && parsed.is_error !== true && parsed.parse_error !== true && !result.error
      ? "EXECUTED_UNGRADED"
      : "ERROR";
    if (outcome === "ERROR") hadError = true;
    const diagnostic = result.error ? ` error=${result.error}` : "";
    process.stdout.write(`${outcome}: ${skillName} eval-${item.id} ${item.model} ${configuration}${diagnostic}\n`);
  } finally {
    assertOwnedFixture(fixtureRoot);
    rmSync(fixtureRoot, { recursive: true, force: true, maxRetries: 5, retryDelay: 50 });
  }
}

function executeClaude(commandArgs, cwd, env, timeoutMs) {
  return new Promise((resolve) => {
    const child = spawn(claudeCommand, commandArgs, {
      cwd,
      env,
      stdio: ["ignore", "pipe", "pipe"],
      detached: process.platform !== "win32",
    });
    let stdout = "";
    let stderr = "";
    let lineBuffer = "";
    let terminalResultReceived = false;
    let terminatedAfterResult = false;
    let timedOut = false;
    let spawnError = null;
    let resultTimer = null;
    let forceTimer = null;
    let timeoutForceTimer = null;
    let terminationRequestedAfterResult = false;
    let settled = false;

    const finish = (status, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutTimer);
      if (resultTimer !== null) clearTimeout(resultTimer);
      if (forceTimer !== null) clearTimeout(forceTimer);
      if (timeoutForceTimer !== null) clearTimeout(timeoutForceTimer);
      const cleanExit = status === 0 && signal === null;
      const expectedRunnerExit = isExpectedRunnerExit(status, signal, terminationRequestedAfterResult);
      const unexpectedExit = terminalResultReceived && !cleanExit && !expectedRunnerExit;
      resolve({
        stdout,
        stderr,
        status,
        signal,
        terminalResultReceived,
        terminatedAfterResult,
        error: spawnError
          ?? (timedOut ? "timeout before terminal result" : null)
          ?? (unexpectedExit ? `unexpected exit after terminal result: status=${status} signal=${signal}` : null),
      });
    };

    const timeoutTimer = setTimeout(() => {
      timedOut = true;
      terminateProcessGroup(child, "SIGTERM");
      timeoutForceTimer = setTimeout(() => {
        terminateProcessGroup(child, "SIGKILL");
      }, 2000);
    }, timeoutMs);

    child.on("error", (error) => {
      spawnError = error.message;
      finish(null, null);
    });
    child.stdout.on("data", (chunk) => {
      const text = chunk.toString("utf8");
      stdout += text;
      lineBuffer += text;
      while (lineBuffer.includes("\n")) {
        const newline = lineBuffer.indexOf("\n");
        const line = lineBuffer.slice(0, newline);
        lineBuffer = lineBuffer.slice(newline + 1);
        let event;
        try { event = JSON.parse(line); } catch { continue; }
        if (event.type !== "result") continue;
        terminalResultReceived = true;
        clearTimeout(timeoutTimer);
        resultTimer = setTimeout(() => {
          terminatedAfterResult = true;
          terminationRequestedAfterResult = terminateProcessGroup(child, "SIGTERM");
          if (terminationRequestedAfterResult) {
            forceTimer = setTimeout(() => {
              terminateProcessGroup(child, "SIGKILL");
            }, 2000);
          }
        }, 250);
      }
    });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString("utf8"); });
    child.on("close", (status, signal) => finish(status, signal));
  });
}

function isExpectedRunnerExit(status, signal, terminationRequested) {
  if (!terminationRequested) return false;
  if (new Set(["SIGTERM", "SIGKILL"]).has(signal)) return true;
  return signal === null && new Set([143, 137]).has(status);
}

function terminateProcessGroup(child, signal) {
  if (!child.pid) return false;
  if (process.platform !== "win32") {
    try {
      process.kill(-child.pid, signal);
      return true;
    } catch (error) {
      if (error.code === "ESRCH") return false;
    }
  }
  return child.kill(signal);
}

function valueAfter(flag) {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : undefined;
}

function budgetFor(model) {
  return { haiku: "0.75", sonnet: "8.00", opus: "8.00" }[model];
}

function timeoutFor(model) {
  return { haiku: 600_000, sonnet: 900_000, opus: 900_000 }[model];
}

function overlayWorkingFiles(fixtureRoot, skillName) {
  const source = path.join(".claude", "skills", skillName);
  const from = path.join(repoRoot, source);
  const to = path.join(fixtureRoot, source);
  const baselineEvals = path.join(fixtureRoot, ".git", `baseline-evals-${skillName}`);
  const fixtureEvals = path.join(to, "evals");
  if (existsSync(fixtureEvals)) cpSync(fixtureEvals, baselineEvals, { recursive: true, force: true });
  rmSync(to, { recursive: true, force: true });
  cpSync(from, to, {
    recursive: true,
    force: true,
  });
  rmSync(path.join(to, "evals"), { recursive: true, force: true });
  if (existsSync(baselineEvals)) {
    cpSync(baselineEvals, path.join(to, "evals"), { recursive: true, force: true });
    rmSync(baselineEvals, { recursive: true, force: true });
  }
}

function removeSkill(fixtureRoot, skillName) {
  const target = path.join(fixtureRoot, ".claude", "skills", skillName);
  const prefix = path.resolve(fixtureRoot) + path.sep;
  if (!path.resolve(target).startsWith(prefix)) throw new Error(`skill path outside fixture: ${target}`);
  rmSync(target, { recursive: true, force: true });
}

function hideCurrentSkillEvaluationOracles(fixtureRoot, skillName) {
  const prefix = path.resolve(fixtureRoot) + path.sep;
  const targets = [
    path.join(fixtureRoot, ".claude", "skills", skillName, "evals"),
    path.join(fixtureRoot, ".claude", "skills", "standard-update", "scripts", "run-task-evals.mjs"),
    path.join(fixtureRoot, ".claude", "skills", "standard-update", "scripts", "run-trigger-evals.mjs"),
    path.join(fixtureRoot, ".claude", "skills", "standard-update", "scripts", "skill-test.sh"),
  ];
  for (const target of targets) {
    if (!path.resolve(target).startsWith(prefix)) throw new Error(`evaluation oracle outside fixture: ${target}`);
    rmSync(target, { recursive: true, force: true });
  }
}

function prepareFixture(fixtureRoot, standardCommit) {
  const targetRoot = path.join(fixtureRoot, "target-project");
  mkdirSync(path.join(targetRoot, "docs", "decisions"), { recursive: true });
  mkdirSync(path.join(targetRoot, "app"), { recursive: true });
  mkdirSync(path.join(targetRoot, "tests"), { recursive: true });
  writeFileSync(path.join(targetRoot, "README.md"), [
    "# evaluation target",
    "",
    "Rust API と durable worker を持つ想定の検査用 project。",
    "source root は `app/`、test root は `tests/` とする。",
    "",
  ].join("\n"));
  writeFileSync(path.join(targetRoot, "docs", "decisions", "0001-standard.md"), [
    "# architecture standard",
    "",
    `standard_commit: ${standardCommit}`,
    "",
  ].join("\n"));
  writeFileSync(path.join(targetRoot, "docs", "decisions", "0002-worker-contract.md"), [
    "# worker completion contract",
    "",
    "Status: Accepted",
    "",
    "`run` returns only after every submitted job has reached a terminal state.",
    "The persisted `JobStatus` is the authority for job completion.",
    "",
  ].join("\n"));
  writeFileSync(path.join(targetRoot, "app", "worker.rs"), [
    "pub async fn run(jobs: Vec<Job>) {",
    "    for job in jobs {",
    "        tokio::spawn(run_job(job));",
    "    }",
    "}",
    "",
  ].join("\n"));
  writeFileSync(path.join(targetRoot, "app", "api.rs"), [
    "pub async fn submit(jobs: Vec<Job>) -> &'static str {",
    "    crate::worker::run(jobs).await;",
    "    \"completed\"",
    "}",
    "",
  ].join("\n"));
  writeFileSync(path.join(targetRoot, "app", "state.rs"), [
    "pub enum JobStatus {",
    "    Pending,",
    "    Running,",
    "    Completed,",
    "    Failed,",
    "}",
    "",
    "pub struct JobRecord {",
    "    pub id: String,",
    "    pub status: JobStatus,",
    "}",
    "",
  ].join("\n"));
  writeFileSync(path.join(targetRoot, "tests", "worker.rs"), [
    "#[tokio::test]",
    "async fn submit_reports_completed() {",
    "    let response = submit(vec![slow_job()]).await;",
    "    assert_eq!(response, \"completed\");",
    "}",
    "",
  ].join("\n"));
}

function prepareEvaluationChange(fixtureRoot, skillName, evalId) {
  // fixture-mutation:start
  if (skillName === "standard-audit" && evalId === 4) {
    const principlesReadme = path.join(fixtureRoot, "principles", "README.md");
    replaceKnownStateOnce(principlesReadme, [
      "要求した範囲は、受入条件、標準の必須規律、安全、互換性、必要な検証を欠かさず作り切る。",
    ],
      "要求した範囲は、必要な品質を適切に満たす。",
    );
  }
  // fixture-mutation:end

  // fixture-mutation:start
  if (skillName === "standard-update" && evalId === 1) {
    const principlesReadme = path.join(fixtureRoot, "principles", "README.md");
    const injectedTypo = ["## 情報の", "概観"].join("");
    replaceKnownStateOnce(principlesReadme, ["## 意図伝達の階層", "## 情報の正本"], injectedTypo);
  }
  // fixture-mutation:end

  // fixture-mutation:start
  if (skillName === "standard-update" && evalId === 4) {
    const auditSkill = path.join(fixtureRoot, ".claude", "skills", "standard-audit", "SKILL.md");
    replaceKnownStateOnce(auditSkill, [
      "- **A 思想の足場**: root `README.md` の目的、領域、標準の単一性、配置規則に照らし、各規律の前提と所有者がずれていないか。",
    ],
      "- **A 思想の足場**: root `README.md` の目的、領域、標準の単一性、配置規則だけを思想基準とし、各規律の前提と所有者がずれていないか。",
    );
  }
  // fixture-mutation:end

  // fixture-mutation:start
  if (skillName === "standard-update" && evalId === 5) {
    const transactionConcern = path.join(fixtureRoot, "concerns", "transaction", "invisible-partial-commits.md");
    const legacyExample = `### 例
\`\`\`
// 途中まで書いて失敗し、不完全な状態を成功として返す
write(a); write(b) /* ここで失敗 */; return ok
// 一つの確定点までで止め、失敗なら何も公開しない
transaction { write(a); write(b) }   // 失敗時はどちらも未確定。再実行で回復できる
\`\`\``;
    const currentExample = `### 例

複数の書き込みを個別に実行し、二つ目の失敗を無視すると、不完全な状態を成功として返す。

\`\`\`
write(a)
ignoreFailure(write(b))
return ok
\`\`\`

一つの確定点までで止め、失敗時はどちらの書き込みも公開しない。未確定のままなら再実行で回復できる。

\`\`\`
transaction { write(a); write(b) }
\`\`\``;
    const defectiveExample = `### 例
\`\`\`
// 二つ目の失敗を無視して成功を返す
write(a)
ignoreFailure(write(b))
return ok
// 一つの確定点なら失敗時にどちらも公開しない
transaction { write(a); write(b) }
\`\`\``;
    replaceKnownStateOnce(transactionConcern, [legacyExample, currentExample], defectiveExample);
  }
  // fixture-mutation:end

  // fixture-mutation:start
  if (skillName === "standard-update" && evalId === 6) {
    const commentPrinciple = path.join(fixtureRoot, "principles", "comment", "declaration-contracts.md");
    const legacyExample = `### 例
\`\`\`ts
// 名前の直訳で、署名を超える情報がない
/** 素数かどうかを判定する。 */
function isPrime(candidate: number): boolean { /* ... */ }
// 利用者が用途を判断できる目的を一行に示す
/** 候補の素数判定 */
function isPrime(candidate: number): boolean { /* ... */ }
\`\`\``;
    const currentExample = `### 例
名前を言い換えただけでは、呼び出し側が知らなければならない契約を示せない。

\`\`\`ts
/**
 * 候補の素数判定
 * @param candidate - 判定する候補
 * @returns candidate が素数なら true
 */
function isPrime(candidate: number): boolean { /* ... */ }
\`\`\`

前提と再利用する状態を書けば、実装を読まずに正しく呼び出せる。

\`\`\`ts
/**
 * 直前までの倍数表を再利用する連続した素数判定
 * @param candidate - 直前の呼び出しより大きい候補
 * @returns candidate が素数なら true
 */
function isPrime(candidate: number): boolean { /* ... */ }
\`\`\``;
    const defectiveExample = `### 例
名前を直訳した summary と、用途を示す summary を比べる。

\`\`\`ts
/** 素数かどうかを判定する。 */
function isPrime(candidate: number): boolean { /* ... */ }

/** 素数かどうかを判定する。 */
function isPrime(candidate: number): boolean { /* ... */ }
\`\`\``;
    replaceKnownStateOnce(commentPrinciple, [legacyExample, currentExample], defectiveExample);
  }
  // fixture-mutation:end

}

function replaceKnownStateOnce(filePath, knownStates, replacement) {
  const source = readFileSync(filePath, "utf8");
  const matches = knownStates.flatMap((candidate) => {
    const count = source.split(candidate).length - 1;
    return Array.from({ length: count }, () => candidate);
  });
  if (matches.length !== 1) {
    throw new Error(`${filePath}: expected exactly one known fixture state, found ${matches.length}`);
  }
  if (matches[0] === replacement) throw new Error(`${filePath}: fixture replacement must change the source`);
  const updated = source.replace(matches[0], replacement);
  if (updated === source) throw new Error(`${filePath}: fixture mutation produced no change`);
  writeFileSync(filePath, updated);
}

function scrubFixtureMutationSource(fixtureRoot) {
  const runnerPath = path.join(fixtureRoot, ".claude", "skills", "standard-update", "scripts", "run-task-evals.mjs");
  if (!existsSync(runnerPath)) return;
  const source = readFileSync(runnerPath, "utf8");
  let sanitized = source.replace(
    /  \/\/ fixture-mutation:start\n[\s\S]*?  \/\/ fixture-mutation:end\n/g,
    "  // Fixture mutation is owned by the outer evaluator.\n",
  );
  if (sanitized === source && source.includes("fixture-mutation:")) {
    throw new Error("fixture mutation block not scrubbed");
  }
  if (sanitized.includes(["injected", "Typo"].join(""))) {
    const functionStart = sanitized.indexOf("function prepareFixture(");
    const mutationStart = sanitized.indexOf('\n  if (skillName === "standard-update" && evalId === 1) {', functionStart);
    const mutationEnd = sanitized.indexOf("\n  }\n}", mutationStart);
    if (functionStart < 0 || mutationStart < 0 || mutationEnd < 0) {
      throw new Error("legacy fixture mutation block not scrubbed");
    }
    sanitized = `${sanitized.slice(0, mutationStart)}\n  // Fixture mutation is owned by the outer evaluator.${sanitized.slice(mutationEnd + 4)}`;
  }
  writeFileSync(runnerPath, sanitized);
}

function configureFixtureGit(fixtureRoot) {
  execFileSync("git", ["config", "user.name", "Skill Eval"], { cwd: fixtureRoot });
  execFileSync("git", ["config", "user.email", "skill-eval@example.invalid"], { cwd: fixtureRoot });
  execFileSync("git", ["config", "commit.gpgSign", "false"], { cwd: fixtureRoot });
  execFileSync("git", ["config", "core.hooksPath", "/dev/null"], { cwd: fixtureRoot });
}

function initializeSanitizedRepository(fixtureRoot) {
  assertOwnedFixture(fixtureRoot);
  rmSync(path.join(fixtureRoot, ".git"), { recursive: true, force: true, maxRetries: 5, retryDelay: 50 });
  execFileSync("git", ["init", "--quiet"], { cwd: fixtureRoot });
  configureFixtureGit(fixtureRoot);
  execFileSync("git", ["add", "-A"], { cwd: fixtureRoot });
  execFileSync("git", ["commit", "--quiet", "-m", "test: create sanitized standard snapshot"], { cwd: fixtureRoot });
  return execFileSync("git", ["rev-parse", "HEAD"], { cwd: fixtureRoot, encoding: "utf8" }).trim();
}

function initializeFixtureCommit(fixtureRoot) {
  configureFixtureGit(fixtureRoot);
  execFileSync("git", ["add", "-A"], { cwd: fixtureRoot });
  execFileSync("git", ["commit", "--quiet", "-m", "test: prepare skill evaluation fixture"], { cwd: fixtureRoot });
}

function parseClaudeResult(stdout) {
  const events = [];
  let parseError = false;
  for (const line of String(stdout ?? "").split("\n")) {
    if (!line.trim()) continue;
    try { events.push(JSON.parse(line)); } catch { parseError = true; }
  }
  const resultEvent = events.findLast((event) => event.type === "result");
  return {
    result: resultEvent?.result ?? "",
    is_error: resultEvent?.is_error ?? resultEvent === undefined,
    parse_error: parseError || resultEvent === undefined,
    total_cost_usd: resultEvent?.total_cost_usd ?? null,
    usage: resultEvent?.usage ?? null,
    events,
  };
}

function collectToolEvidence(events) {
  const calls = new Map();
  for (const event of events) {
    if (event.type === "assistant") {
      for (const block of event.message?.content ?? []) {
        if (block.type === "tool_use") calls.set(block.id, {
          id: block.id,
          name: block.name,
          input: block.input,
          status: "no-result",
        });
      }
    }
    if (event.type === "user") {
      for (const block of event.message?.content ?? []) {
        if (block.type !== "tool_result") continue;
        const call = calls.get(block.tool_use_id);
        if (!call) continue;
        call.status = block.is_error === true ? "error" : "succeeded";
        call.result = typeof block.content === "string" ? block.content.slice(0, 2000) : block.content;
      }
    }
  }
  return [...calls.values()];
}

function gitOutput(cwd, commandArgs) {
  return execFileSync("git", commandArgs, { cwd, encoding: "utf8" });
}

function assertOwnedFixture(fixtureRoot) {
  const resolved = path.resolve(fixtureRoot);
  const allowed = path.resolve(tmpdir()) + path.sep;
  if (!resolved.startsWith(allowed) || !path.basename(resolved).startsWith("architecture-standard-")) {
    throw new Error(`refusing to remove unowned fixture: ${resolved}`);
  }
}
