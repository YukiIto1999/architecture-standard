#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { loadedSkill, ompTimeout, resolveOmpModel, runOmp } from "./omp-eval-adapter.mjs";

const repoRoot = execFileSync("git", ["-C", fileURLToPath(new URL("../../../", import.meta.url)), "rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
const skillName = process.argv[2];
const allowedSkills = new Set(["standard-apply", "standard-audit", "standard-conformance", "standard-feedback", "standard-update", "cli-design", "property-testing"]);
if (!allowedSkills.has(skillName)) throw new Error(`skill must be one of ${[...allowedSkills].join(", ")}`);
const timeoutMs = ompTimeout(60_000);
const resolvedModel = resolveOmpModel();
const sourceRoot = path.join(repoRoot, "skills", skillName);
const allQueries = JSON.parse(readFileSync(path.join(sourceRoot, "evals", "trigger-evals.json"), "utf8"));
const selectedQuery = process.argv[3] === undefined ? null : Number(process.argv[3]);
if (selectedQuery !== null && (!Number.isInteger(selectedQuery) || selectedQuery < 0 || selectedQuery >= allQueries.length)) {
  throw new Error(`query index must be an integer from 0 to ${allQueries.length - 1}`);
}
const queries = selectedQuery === null ? allQueries : allQueries.filter((_, index) => index === selectedQuery);
const fixtureRoot = mkdtempSync(path.join(tmpdir(), `architecture-standard-trigger-${skillName}-`));
const skills = {};
try {
  for (const candidate of allowedSkills) {
    const candidatePath = path.join(fixtureRoot, "skills", candidate);
    mkdirSync(candidatePath, { recursive: true });
    const skillFile = path.join(candidatePath, "SKILL.md");
    cpSync(path.join(repoRoot, "skills", candidate, "SKILL.md"), skillFile);
    skills[candidate] = skillFile;
  }
  const results = [];
  for (const item of queries) {
    const evaluation = await evaluateQuery(item.query);
    const expectedSkill = Object.hasOwn(item, "expected_skill")
      ? item.expected_skill : item.should_trigger ? skillName : null;
    const passed = evaluation.error === null && evaluation.selected_skill === expectedSkill;
    results.push({ query: item.query, expected_skill: expectedSkill, ...evaluation, pass: passed });
    process.stderr.write(`${passed ? "PASS" : "FAIL"}: selected=${evaluation.selected_skill ?? "none"} expected=${expectedSkill ?? "none"} error=${evaluation.error ?? "none"} trace=${JSON.stringify(evaluation.trace)} ${item.query}\n`);
  }
  const passed = results.filter(item => item.pass).length;
  process.stdout.write(`${JSON.stringify({ skill_name: skillName, results,
    summary: { total: results.length, passed, failed: results.length - passed } }, null, 2)}\n`);
  process.exitCode = passed === results.length ? 0 : 1;
} finally {
  const resolved = path.resolve(fixtureRoot);
  if (!resolved.startsWith(path.resolve(tmpdir()) + path.sep) || !path.basename(resolved).startsWith("architecture-standard-trigger-")) {
    throw new Error(`refusing to remove unowned fixture: ${resolved}`);
  }
  rmSync(fixtureRoot, { recursive: true, force: true });
}

async function evaluateQuery(query) {
  const prompt = [
    "これは Skill の発火先だけを測る隔離評価です。依頼そのものは実行しないでください。",
    "利用可能な Skill の name と description だけから依頼に一致する Skill を選んでください。一致すれば最初かつ唯一の tool call として read(path=skill://ID) でその SKILL.md の本文全体を読み、終えてください。",
    "対象 path の探索、確認質問、作業計画、他の tool call を先に行わないでください。一致しなければ tool を呼ばず、該当なしとだけ応答してください。",
    `依頼: ${query}`,
  ].join("\n\n");
  const execution = await runOmp({ cwd: fixtureRoot, prompt, resolvedModel, tools: ["read"], skills, timeoutMs,
    systemPrompt: "You are an isolated Skill routing evaluator. Select solely from the available isolated Skill names and descriptions. Load one matching Skill using read, or do not call tools when no Skill matches. Do not execute the task." });
  const calls = execution.toolEvidence;
  const first = calls[0];
  const selectedSkill = first ? loadedSkill(first, skills, fixtureRoot) : null;
  const firstCompetingTool = first && selectedSkill === null ? first.name : null;
  let error = execution.error;
  if (calls.length > 1) error ??= "multiple tool calls in Skill routing evaluation";
  if (first && selectedSkill === null) error ??= "first tool did not successfully load a complete recognized Skill";
  const trace = calls.slice(0, 8).map(call => `tool:${call.name}:${JSON.stringify(call.input)}:${call.status}`);
  return { selected_skill: selectedSkill, triggered: selectedSkill !== null,
    first_competing_tool: firstCompetingTool, observation_window_expired: execution.error === "OMP execution timeout",
    terminal_result_received: execution.terminalResultReceived, exit_status: execution.status, signal: execution.signal,
    requested_model: process.env.OMP_EVAL_MODEL || "default", resolved_model_selector: execution.resolvedModel,
    actual_models: execution.parsed.actual_models, model_usage: execution.parsed.model_usage,
    usage: execution.parsed.usage, total_cost_usd: execution.parsed.total_cost_usd,
    error, trace, tool_evidence: calls };
}
