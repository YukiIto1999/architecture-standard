import { execFileSync, spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

export const ompAdapterSha256 = createHash("sha256")
  .update(readFileSync(new URL(import.meta.url)))
  .update(readFileSync(new URL("./omp-eval-policy.mjs", import.meta.url))).digest("hex");

export function resolveOmpModel(model = "default") {
  const requested = process.env.OMP_EVAL_MODEL || model;
  if (typeof requested !== "string" || !requested.trim() || /\s/.test(requested)) {
    throw new Error("OMP model must be a nonempty selector without whitespace");
  }
  if (requested !== "default") return requested;
  const response = JSON.parse(execFileSync(process.env.OMP_EVAL_COMMAND || "omp",
    ["config", "get", "modelRoles", "--json"], { encoding: "utf8", timeout: 30_000 }));
  const selector = response.value?.default;
  if (typeof selector !== "string" || !selector.includes("/") || /\s/.test(selector)) {
    throw new Error("OMP has no explicit default model selector; set OMP_EVAL_MODEL");
  }
  return selector;
}

export function ompTimeout(defaultMs) {
  const timeout = Number(process.env.OMP_EVAL_TIMEOUT_MS ?? defaultMs);
  if (!Number.isSafeInteger(timeout) || timeout < 1) throw new Error("OMP_EVAL_TIMEOUT_MS must be a positive integer");
  return timeout;
}

export async function runOmp({ cwd, prompt, model = "default", resolvedModel = resolveOmpModel(model),
  tools = [], skills = {}, bashPolicy = {}, reportPath = null, readableFiles = [], timeoutMs, systemPrompt, environment = {} }) {
  const controlRoot = mkdtempSync(path.join(tmpdir(), "architecture-standard-omp-control-"));
  const configFile = path.join(controlRoot, "config.json");
  const policyFile = path.join(controlRoot, "policy.json");
  const extensionFile = path.join(controlRoot, "policy.mjs");
  const config = {
    autoResume: false, advisor: { enabled: false }, prewalk: { enabled: false },
    contextPromotion: { enabled: false },
    retry: { modelFallback: false, usageAwareFallback: false, fallbackChains: {} },
    providers: { anthropic: { serverSideFallback: false }, "openai-codex": { codeMode: "off" } },
    memory: { backend: "off" }, memories: { enabled: false },
    hindsight: { mentalModelsEnabled: false, mentalModelAutoSeed: false },
    magicKeywords: { enabled: false },
    skills: {
      enabled: Object.keys(skills).length > 0, enableSkillCommands: false,
      enableCodexUser: false, enableClaudeUser: false, enableClaudeProject: false,
      enablePiUser: false, enablePiProject: false, enableAgentsUser: false, enableAgentsProject: false,
      customDirectories: [...new Set(Object.values(skills).map(file => path.dirname(path.dirname(file))))],
      ignoredSkills: [], includeSkills: Object.keys(skills),
    },
    skillful: true,
    commands: { enableClaudeUser: false, enableClaudeProject: false, enableOpencodeUser: false, enableOpencodeProject: false },
    tools: {
      xdev: false, approvalMode: "yolo", approval: Object.fromEntries(tools.map(name => [name, "allow"])),
      speculativeExecution: { enabled: false }, outputMaxColumns: 0,
    },
    bash: { allowCompoundCommands: false, autoBackground: { enabled: false }, direnv: "off", patterns: [] },
    read: { defaultLimit: 100_000, summarize: { prose: false } },
    mcp: { enableProjectConfig: false, notifications: false },
    plan: { defaultOnStartup: false }, archive: { enabled: false }, dev: { autoqa: false },
  };
  const policy = { cwd: realpathSync(cwd), tools, skills, bashPolicy, reportPath, readableFiles, systemPrompt };
  writeFileSync(configFile, JSON.stringify(config));
  writeFileSync(policyFile, JSON.stringify(policy));
  writeFileSync(extensionFile, readFileSync(new URL("./omp-eval-policy.mjs", import.meta.url)));
  const commandArgs = ["-p", "--mode", "json", "--no-session", "--no-rules", "--no-extensions",
    "--no-lsp", "--no-title", "--no-prewalk", "--no-pty", "--config", configFile,
    "--system-prompt", systemPrompt, "--tools", tools.join(","), "--model", resolvedModel,
    "--extension", extensionFile];
  if (Object.keys(skills).length === 0) commandArgs.push("--no-skills");
  const normalize = value => typeof value === "string"
    ? value.replaceAll(controlRoot, "<omp-control>").replaceAll(cwd, "<fixture>")
      .replaceAll(reportPath ? path.dirname(reportPath) : "\u0000", "<audit-report-directory>")
    : value;
  const commandContractArgs = commandArgs.map(normalize);
  const settingsContract = JSON.parse(JSON.stringify({ config, policy, resolved_model_selector: resolvedModel })
    .replaceAll(controlRoot, "<omp-control>").replaceAll(cwd, "<fixture>")
    .replaceAll(reportPath ? path.dirname(reportPath) : "\u0000", "<audit-report-directory>"));
  const env = { ...process.env };
  delete env.SKILL_EVAL_ISOLATED_SKILL;
  delete env.SKILL_EVAL_CONFIGURATION;
  Object.assign(env, environment);
  try {
    const execution = await executeOmp(process.env.OMP_EVAL_COMMAND || "omp", commandArgs, cwd, env, prompt, timeoutMs);
    const providerError = path.join(controlRoot, "provider-error.txt");
    if (existsSync(providerError)) execution.error ??= readFileSync(providerError, "utf8");
    const parsed = parseOmpStream(execution.stdout, tools);
    execution.terminalResultReceived = parsed.terminal_received;
    execution.error ??= parsed.error;
    return { ...execution, parsed, commandArgs, commandContractArgs, settingsContract,
      resolvedModel, toolEvidence: parsed.tool_evidence };
  } finally {
    rmSync(controlRoot, { recursive: true, force: true });
  }
}

function executeOmp(command, args, cwd, env, prompt, timeoutMs) {
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1) throw new Error("OMP execution timeout must be a positive integer");
  return new Promise(resolve => {
    const child = spawn(command, args, { cwd, env,
      stdio: ["pipe", "pipe", "pipe"], detached: process.platform !== "win32" });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let spawnError = null;
    let forceTimer = null;
    let settled = false;
    const terminate = signal => {
      if (!child.pid) return;
      if (process.platform !== "win32") {
        try { process.kill(-child.pid, signal); return; } catch (error) { if (error.code === "ESRCH") return; }
      }
      child.kill(signal);
    };
    const timer = setTimeout(() => {
      timedOut = true;
      terminate("SIGTERM");
      forceTimer = setTimeout(() => terminate("SIGKILL"), 2000);
    }, timeoutMs);
    const finish = (status, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearTimeout(forceTimer);
      resolve({ stdout, stderr, status, signal,
        error: spawnError ?? (timedOut ? "OMP execution timeout" : null)
          ?? (status !== 0 || signal !== null ? `OMP exited with status=${status} signal=${signal}` : null) });
    };
    child.stdin.on("error", () => {});
    child.stdin.end(prompt);
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", chunk => { if (!timedOut) stdout += chunk; });
    child.stderr.on("data", chunk => { stderr += chunk; });
    child.on("error", error => { spawnError = error.message; finish(null, null); });
    child.on("close", finish);
  });
}

export function parseOmpStream(stdout, allowedTools) {
  const calls = new Map();
  const messages = [];
  const modelUsage = {};
  const eventTypes = new Set(["session", "agent_start", "turn_start", "message_start", "message_update",
    "message_end", "tool_execution_start", "tool_execution_update", "tool_stream_update",
    "tool_execution_end", "turn_end", "agent_end"]);
  const validContent = content => Array.isArray(content) && content.every(block => block !== null
    && typeof block === "object" && ["text", "thinking", "toolCall", "image"].includes(block.type)
    && (block.type !== "text" || typeof block.text === "string")
    && (block.type !== "thinking" || typeof block.thinking === "string")
    && (block.type !== "image" || (typeof block.data === "string" && typeof block.mimeType === "string")));
  let terminal = null;
  let error = null;
  const fail = reason => { error ??= reason; };
  for (const line of String(stdout ?? "").split("\n")) {
    if (!line.trim()) continue;
    let event;
    try { event = JSON.parse(line); } catch { fail("malformed OMP JSON stream"); continue; }
    if (!event || typeof event !== "object" || Array.isArray(event) || typeof event.type !== "string") {
      fail("invalid OMP stream event"); continue;
    }
    if (!eventTypes.has(event.type)) { fail(`unrecognized OMP stream event: ${event.type}`); continue; }
    if (["message_start", "message_end"].includes(event.type) && (!event.message
      || typeof event.message.role !== "string" || !validContent(event.message.content))) fail("invalid OMP message envelope");
    if (terminal) { fail("OMP event after terminal agent_end"); continue; }
    if (event.type === "agent_end") {
      if (!Array.isArray(event.messages) || event.messages.some(message => !message
        || typeof message.role !== "string" || !validContent(message.content))) fail("invalid OMP terminal messages");
      terminal = event;
      continue;
    }
    if (event.type === "message_end" && event.message?.role === "assistant") {
      const message = event.message;
      if (!validContent(message.content) || typeof message.provider !== "string" || !message.provider
        || typeof message.model !== "string" || !message.model) {
        fail("assistant message missing OMP model identity or content"); continue;
      }
      messages.push(message);
      if (!["stop", "toolUse"].includes(message.stopReason)) fail(`OMP assistant stopReason=${message.stopReason}`);
      const identity = `${message.provider}/${message.model}`;
      modelUsage[identity] ??= {};
      addUsage(modelUsage[identity], message.usage);
      for (const block of message.content) {
        if (block.type !== "toolCall") continue;
        if (typeof block.id !== "string" || typeof block.name !== "string" || !block.arguments || typeof block.arguments !== "object") {
          fail("invalid OMP tool call"); continue;
        }
        if (!allowedTools.includes(block.name)) fail(`OMP called disabled tool: ${block.name}`);
        const existing = calls.get(block.id);
        if (existing && existing.name !== block.name) fail("conflicting OMP tool identity");
        if (!existing) calls.set(block.id, { id: block.id, name: block.name, input: block.arguments, status: "no-result" });
      }
    }
    if (event.type === "tool_execution_start") {
      if (typeof event.toolCallId !== "string" || typeof event.toolName !== "string" || !event.args || typeof event.args !== "object") {
        fail("invalid OMP tool start"); continue;
      }
      if (!allowedTools.includes(event.toolName)) fail(`OMP called disabled tool: ${event.toolName}`);
      const existing = calls.get(event.toolCallId);
      if (existing && existing.name !== event.toolName) fail("conflicting OMP tool identity");
      if (!existing) calls.set(event.toolCallId, { id: event.toolCallId, name: event.toolName, input: event.args, status: "no-result" });
    }
    if (event.type === "tool_execution_end") {
      const call = calls.get(event.toolCallId);
      if (!call || call.name !== event.toolName || !event.result || !Array.isArray(event.result.content)
        || typeof event.isError !== "boolean") { fail("invalid or unpaired OMP tool result"); continue; }
      if (call.status !== "no-result") { fail("duplicate OMP tool result"); continue; }
      call.status = event.isError || event.result.isError === true ? "error" : "succeeded";
      call.result = event.result.content;
      call.details = event.result.details ?? null;
    }
  }
  if (!terminal) fail("missing terminal OMP agent_end");
  if (messages.length === 0) fail("missing completed OMP assistant message");
  if (Object.keys(modelUsage).length > 1) fail("OMP model changed during evaluation; fallback is forbidden");
  const final = messages.at(-1);
  const terminalFinal = Array.isArray(terminal?.messages) ? terminal.messages.findLast(message => message?.role === "assistant") : null;
  if (final && (!terminalFinal || terminalFinal.provider !== final.provider || terminalFinal.model !== final.model
    || terminalFinal.stopReason !== final.stopReason || JSON.stringify(terminalFinal.content) !== JSON.stringify(final.content))) {
    fail("OMP terminal answer does not match completed assistant message");
  }
  if (final?.stopReason !== "stop" || final?.content.some(block => block.type === "toolCall")
    || !final?.content.some(block => block.type === "text")) fail("missing final OMP assistant answer");
  if ([...calls.values()].some(call => call.status === "no-result")) fail("missing completed OMP tool result");
  const usage = {};
  for (const model of Object.values(modelUsage)) addUsage(usage, model);
  return { result: final?.content.filter(block => block.type === "text").map(block => block.text).join("\n") ?? "",
    is_error: error !== null, error,
    terminal_received: terminal !== null, terminal_reason: final?.stopReason ?? null,
    model_usage: modelUsage, actual_models: Object.keys(modelUsage).sort(),
    total_cost_usd: usage.cost?.total ?? null, usage, tool_evidence: [...calls.values()] };
}

function addUsage(target, source) {
  if (!source || typeof source !== "object") return;
  for (const [key, value] of Object.entries(source)) {
    if (typeof value === "number" && Number.isFinite(value)) target[key] = (target[key] ?? 0) + value;
    else if (key === "cost" && value && typeof value === "object") { target.cost ??= {}; addUsage(target.cost, value); }
  }
}

export function loadedSkill(call, skills, cwd) {
  if (call.name !== "read" || call.status !== "succeeded" || typeof call.input?.path !== "string") return null;
  const locator = call.input.path;
  const uri = /^skill:\/\/([^/:]+)(?::raw)?$/.exec(locator);
  let file;
  try {
    if (uri) file = skills[uri[1]];
    else {
      if (/^[a-z]+:\/\//i.test(locator)) return null;
      const selector = locator.indexOf(":");
      if (selector !== -1 && locator.slice(selector) !== ":raw") return null;
      file = path.resolve(cwd, selector === -1 ? locator : locator.slice(0, selector));
    }
    if (!file) return null;
    const actual = realpathSync(file);
    const entry = Object.entries(skills).find(([, candidate]) => realpathSync(candidate) === actual);
    if (!entry) return null;
    const details = call.details;
    if (details?.summary || details?.truncation?.truncated || details?.meta?.truncation
      || details?.meta?.artifactError || details?.meta?.limits?.columnTruncated) return null;
    const normalize = text => text.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").trimEnd();
    const expected = normalize(readFileSync(actual, "utf8"));
    const texts = (call.result ?? []).filter(block => block.type === "text" && typeof block.text === "string").map(block => block.text);
    const rendered = normalize(texts.join("\n"));
    const unnumbered = rendered.replace(/^\d+[:|]/gm, "");
    if (!expected || !(rendered.includes(expected) || unnumbered.includes(expected))) return null;
    return entry[0];
  } catch { return null; }
}
