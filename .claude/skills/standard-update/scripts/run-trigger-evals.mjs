#!/usr/bin/env node
import { execFileSync, spawn } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import process from "node:process";

const repoRoot = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
const skillName = process.argv[2];
const allowedSkills = new Set(["standard-apply", "standard-audit", "standard-update"]);
if (!allowedSkills.has(skillName)) throw new Error("skill must be standard-apply, standard-audit, or standard-update");
const claudeCommand = process.env.CLAUDE_EVAL_COMMAND || "claude";
const timeoutMs = Number(process.env.CLAUDE_EVAL_TIMEOUT_MS || "60000");
if (!Number.isFinite(timeoutMs) || timeoutMs < 1) throw new Error("CLAUDE_EVAL_TIMEOUT_MS must be a positive number");

const sourceRoot = path.join(repoRoot, ".claude", "skills", skillName);
const allQueries = JSON.parse(readFileSync(path.join(sourceRoot, "evals", "trigger-evals.json"), "utf8"));
const selectedQuery = process.argv[3] === undefined ? null : Number(process.argv[3]);
if (selectedQuery !== null && (!Number.isInteger(selectedQuery) || selectedQuery < 0 || selectedQuery >= allQueries.length)) {
  throw new Error(`query index must be an integer from 0 to ${allQueries.length - 1}`);
}
const queries = selectedQuery === null ? allQueries : allQueries.filter((_, index) => index === selectedQuery);
const fixtureRoot = mkdtempSync(path.join(tmpdir(), `architecture-standard-trigger-${skillName}-`));

try {
  execFileSync("git", ["clone", "--quiet", "--no-hardlinks", repoRoot, fixtureRoot]);
  const skillsRoot = path.join(fixtureRoot, ".claude", "skills");
  for (const candidate of allowedSkills) {
    const candidatePath = path.join(skillsRoot, candidate);
    assertInside(fixtureRoot, candidatePath);
    rmSync(candidatePath, { recursive: true, force: true });
    cpSync(path.join(repoRoot, ".claude", "skills", candidate), candidatePath, { recursive: true, force: true });
  }

  const results = [];
  for (const item of queries) {
    const evaluation = await evaluateQuery(item.query);
    const expectedSkill = Object.hasOwn(item, "expected_skill")
      ? item.expected_skill
      : item.should_trigger ? skillName : null;
    const passed = evaluation.error === null && evaluation.selected_skill === expectedSkill;
    results.push({ query: item.query, expected_skill: expectedSkill, ...evaluation, pass: passed });
    process.stderr.write(`${passed ? "PASS" : "FAIL"}: selected=${evaluation.selected_skill ?? "none"} expected=${expectedSkill ?? "none"} error=${evaluation.error ?? "none"} trace=${JSON.stringify(evaluation.trace)} ${item.query}\n`);
  }

  const passed = results.filter((item) => item.pass).length;
  process.stdout.write(`${JSON.stringify({ skill_name: skillName, results, summary: { total: results.length, passed, failed: results.length - passed } }, null, 2)}\n`);
  process.exitCode = passed === results.length ? 0 : 1;
} finally {
  assertOwnedFixture(fixtureRoot);
  rmSync(fixtureRoot, { recursive: true, force: true });
}

function evaluateQuery(query) {
  return new Promise((resolve) => {
    const args = [
      "-p", query,
      "--output-format", "stream-json",
      "--verbose",
      "--include-partial-messages",
      "--no-session-persistence",
      "--permission-mode", "plan",
      "--allowedTools", "Skill",
      "--setting-sources", "project",
      "--model", "haiku",
    ];
    const env = { ...process.env };
    delete env.CLAUDECODE;
    const child = spawn(claudeCommand, args, {
      cwd: fixtureRoot,
      env,
      stdio: ["ignore", "pipe", "pipe"],
      detached: process.platform !== "win32",
    });
    let buffer = "";
    let pendingSkillTool = false;
    let partialInput = "";
    let settled = false;
    let stderr = "";
    const trace = [];
    let selectedSkill = null;
    const otherSkills = [];
    let firstCompetingTool = null;
    let streamParseError = null;
    let selectionError = null;
    let sawTerminalResult = false;
    let resultError = null;
    let spawnError = null;
    let observationWindowExpired = false;
    let terminationRequestedAfterResult = false;
    let terminationRequestedAfterSelection = false;
    let terminationRequestedAfterObservation = false;
    let terminationRequestedAfterCompetingTool = false;
    let resultTimer = null;
    let forceTimer = null;
    let timeoutForceTimer = null;

    const finish = (code, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (resultTimer !== null) clearTimeout(resultTimer);
      if (forceTimer !== null) clearTimeout(forceTimer);
      if (timeoutForceTimer !== null) clearTimeout(timeoutForceTimer);
      const cleanExit = code === 0 && signal === null;
      const runnerTerminationRequested = terminationRequestedAfterResult
        || terminationRequestedAfterSelection
        || terminationRequestedAfterObservation
        || terminationRequestedAfterCompetingTool;
      const expectedRunnerExit = isExpectedRunnerExit(code, signal, runnerTerminationRequested);
      const evaluationComplete = sawTerminalResult
        || selectedSkill !== null
        || terminationRequestedAfterSelection
        || observationWindowExpired
        || firstCompetingTool !== null;
      const unexpectedExit = selectedSkill === null && evaluationComplete && !cleanExit && !expectedRunnerExit;
      const error = spawnError
        ?? streamParseError
        ?? selectionError
        ?? resultError
        ?? (!evaluationComplete ? `exit=${code} signal=${signal} terminal=false stderr=${stderr.trim()}` : null)
        ?? (unexpectedExit ? `unexpected exit after evaluation completion: status=${code} signal=${signal}` : null);
      resolve({
        selected_skill: selectedSkill,
        triggered: selectedSkill !== null,
        other_skills: otherSkills,
        first_competing_tool: firstCompetingTool,
        observation_window_expired: observationWindowExpired,
        error,
        trace,
      });
    };

    const timer = setTimeout(() => {
      inspectBufferedFragment();
      observationWindowExpired = true;
      terminationRequestedAfterObservation = terminateProcessGroup(child, "SIGTERM");
      if (terminationRequestedAfterObservation) {
        timeoutForceTimer = setTimeout(() => {
          terminateProcessGroup(child, "SIGKILL");
        }, 2000);
      }
    }, timeoutMs);
    child.on("error", (error) => {
      spawnError = error.message;
      finish(null, null);
    });
    child.on("close", (code, signal) => {
      inspectBufferedFragment();
      finish(code, signal);
    });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString("utf8"); });
    child.stdout.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      while (buffer.includes("\n")) {
        const newline = buffer.indexOf("\n");
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        if (!line) continue;
        if (isObservationClosed()) continue;
        let event;
        try {
          event = JSON.parse(line);
        } catch {
          streamParseError ??= "malformed stream-json event";
          continue;
        }
        inspectEvent(event);
      }
    });

    function inspectBufferedFragment() {
      const fragment = buffer.trim();
      buffer = "";
      if (!fragment) return;
      if (isObservationClosed()) return;
      try {
        inspectEvent(JSON.parse(fragment));
      } catch {
        streamParseError ??= "malformed stream-json event";
      }
    }

    function isObservationClosed() {
      return observationWindowExpired
        || selectedSkill !== null
        || sawTerminalResult
        || firstCompetingTool !== null
        || terminationRequestedAfterSelection
        || terminationRequestedAfterCompetingTool;
    }

    function inspectEvent(event) {
      if (event.type !== "result" && isObservationClosed()) return;
      if (event.type === "stream_event") {
        const streamEvent = event.event ?? {};
        if (streamEvent.type === "content_block_start") {
          const block = streamEvent.content_block ?? {};
          if (block.type !== "tool_use") return;
          pendingSkillTool = block.name === "Skill";
          partialInput = "";
          if (!pendingSkillTool) recordCompetingTool(block.name);
        } else if (streamEvent.type === "content_block_delta" && pendingSkillTool) {
          const delta = streamEvent.delta ?? {};
          if (delta.type !== "input_json_delta") return;
          partialInput += delta.partial_json ?? "";
        } else if (streamEvent.type === "content_block_stop" && pendingSkillTool) {
          recordSkillSelection(parseSkillInput(partialInput));
          pendingSkillTool = false;
        }
      } else if (event.type === "assistant") {
        for (const block of event.message?.content ?? []) {
          if (trace.length < 8) trace.push(block.type === "tool_use" ? `tool:${block.name}:${JSON.stringify(block.input)}` : `${block.type}:${String(block.text ?? "").slice(0, 160)}`);
          if (block.type !== "tool_use") continue;
          if (block.name === "Skill") {
            recordSkillSelection(parseSkillInput(block.input));
          } else {
            recordCompetingTool(block.name);
          }
        }
      } else if (event.type === "result") {
        sawTerminalResult = true;
        clearTimeout(timer);
        if (selectedSkill !== null
          || terminationRequestedAfterSelection
          || terminationRequestedAfterObservation
          || terminationRequestedAfterCompetingTool) return;
        resultError = event.is_error === true ? `result error: ${event.result ?? "unknown"}` : null;
        resultTimer = setTimeout(() => {
          terminationRequestedAfterResult = terminateProcessGroup(child, "SIGTERM");
          if (terminationRequestedAfterResult) {
            forceTimer = setTimeout(() => {
              terminateProcessGroup(child, "SIGKILL");
            }, 2000);
          }
        }, 250);
      }
    }

    function recordSkillSelection(candidate) {
      if (candidate === null) {
        selectionError = "Skill tool called without an exact recognized skill";
        return;
      }
      if (allowedSkills.has(candidate) && firstCompetingTool !== null) {
        selectionError = `Skill selected after competing tool: ${firstCompetingTool}`;
        return;
      }
      if (!allowedSkills.has(candidate)) {
        if (candidate.startsWith("standard-")) {
          selectionError = `Skill tool called with an unrecognized standard skill: ${candidate}`;
        } else if (!otherSkills.includes(candidate)) {
          otherSkills.push(candidate);
        }
        recordCompetingTool(`Skill(${candidate})`);
        return;
      }
      if (selectedSkill !== null && selectedSkill !== candidate) {
        selectionError = `multiple skills selected: ${selectedSkill}, ${candidate}`;
        return;
      }
      selectedSkill = candidate;
      if (!sawTerminalResult && !terminationRequestedAfterSelection) {
        clearTimeout(timer);
        terminationRequestedAfterSelection = terminateProcessGroup(child, "SIGTERM");
        if (terminationRequestedAfterSelection) {
          forceTimer = setTimeout(() => {
            terminateProcessGroup(child, "SIGKILL");
          }, 2000);
        }
      }
    }

    function recordCompetingTool(toolName) {
      if (selectedSkill !== null || firstCompetingTool !== null || sawTerminalResult) return;
      firstCompetingTool = toolName;
      clearTimeout(timer);
      terminationRequestedAfterCompetingTool = terminateProcessGroup(child, "SIGTERM");
      if (terminationRequestedAfterCompetingTool) {
        forceTimer = setTimeout(() => {
          terminateProcessGroup(child, "SIGKILL");
        }, 2000);
      }
    }
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

function parseSkillInput(value) {
  let input = value;
  if (typeof input === "string") {
    try { input = JSON.parse(input); } catch { return null; }
  }
  const name = input?.skill;
  return typeof name === "string" && name.length > 0 ? name : null;
}

function assertInside(root, target) {
  const prefix = path.resolve(root) + path.sep;
  if (!path.resolve(target).startsWith(prefix)) throw new Error(`path outside fixture: ${target}`);
}

function assertOwnedFixture(target) {
  const resolved = path.resolve(target);
  const prefix = path.resolve(tmpdir()) + path.sep;
  if (!resolved.startsWith(prefix) || !path.basename(resolved).startsWith("architecture-standard-trigger-")) {
    throw new Error(`refusing to remove unowned fixture: ${resolved}`);
  }
}
