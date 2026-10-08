import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";

export default function evaluatorPolicy(pi) {
  const policy = JSON.parse(readFileSync(new URL("./policy.json", import.meta.url), "utf8"));
  pi.on("session_start", () => { pi.setActiveTools(policy.tools); });
  pi.on("before_provider_request", event => {
    const payload = event.payload;
    try {
      if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new Error("unrecognized provider payload");
      if (payload.tools !== undefined && !Array.isArray(payload.tools)) throw new Error("unrecognized provider tools");
      return { ...payload, tools: filterProviderTools(payload.tools ?? [], policy.tools) };
    } catch (error) {
      writeFileSync(new URL("./provider-error.txt", import.meta.url), String(error.message));
      return { ...payload, tools: [] };
    }
  });
  const catalog = Object.entries(policy.skills).map(([name, file]) => {
    const source = readFileSync(file, "utf8");
    const description = /^description:\s*(.+)$/m.exec(source)?.[1];
    if (!description || !new RegExp(`^name:\\s*${name}$`, "m").test(source)) throw new Error(`invalid Skill metadata: ${name}`);
    return `- ${name}: ${description}\n  Load the complete instructions with read(path=\"skill://${name}\") or read(path=\"${file}\").`;
  }).join("\n");
  pi.on("before_agent_start", () => ({
    systemPrompt: [policy.systemPrompt, ...(catalog ? [`Available isolated Skills (name and description only):\n${catalog}`] : [])],
  }));
  pi.on("tool_call", event => {
    let reason;
    try { reason = rejectedCall(event, policy); } catch { reason = "invalid or inaccessible tool input"; }
    if (reason) return { block: true, reason: `Evaluation permission denied: ${reason}` };
  });
}

function rejectedCall(event, policy) {
  if (!policy.tools.includes(event.toolName)) return `disabled tool ${event.toolName}`;
  const input = event.input;
  if (event.toolName === "web_search") return null;
  if (event.toolName === "bash") return allowedBash(input, policy) ? null : "command is outside the fixed Bash allowlist";
  if (event.toolName === "edit") {
    const patch = input?.input;
    if (typeof patch !== "string") return "unrecognized edit input";
    const files = [...patch.matchAll(/^\[([^\r\n]+)#[0-9A-Fa-f]{4}\]$/gm)].map(match => match[1]);
    if (files.length === 0 || files.some(file => !allowedPath(file, policy, true))) return "edit path is outside the fixture";
    for (const match of patch.matchAll(/^MV (.+)$/gm)) {
      const file = match[1].replace(/^"(.*)"$/, "$1");
      if (!allowedPath(file, policy, true)) return "edit destination is outside the fixture";
    }
    return null;
  }
  const writing = event.toolName === "write";
  if (!["read", "write", "grep", "glob"].includes(event.toolName)) return "unrecognized tool";
  const locator = input?.path ?? (event.toolName === "grep" || event.toolName === "glob" ? "." : null);
  if (typeof locator !== "string") return "missing path";
  const paths = event.toolName === "grep" || event.toolName === "glob" ? locator.split(";") : [locator];
  return paths.every(file => allowedPath(file, policy, writing)) ? null : "path is outside the fixture or exposes evaluator controls";
}

function filterProviderTools(tools, allowed) {
  return tools.flatMap(tool => {
    if (!tool || typeof tool !== "object" || Array.isArray(tool)) throw new Error("unrecognized provider tool schema");
    if (tool.type === "namespace" && Array.isArray(tool.tools)) {
      const nested = filterProviderTools(tool.tools, allowed);
      return nested.length ? [{ ...tool, tools: nested }] : [];
    }
    const declarationKey = Object.hasOwn(tool, "functionDeclarations") ? "functionDeclarations"
      : Object.hasOwn(tool, "function_declarations") ? "function_declarations" : null;
    if (declarationKey) {
      if (!Array.isArray(tool[declarationKey])) throw new Error("unrecognized provider function declarations");
      const nested = filterProviderTools(tool[declarationKey], allowed);
      return nested.length ? [{ ...tool, [declarationKey]: nested }] : [];
    }
    const name = tool.name ?? tool.function?.name;
    if (typeof name !== "string") throw new Error("unrecognized provider tool name");
    return allowed.includes(name) ? [tool] : [];
  });
}

function allowedPath(locator, policy, writing) {
  if (!writing && /^https?:\/\//i.test(locator)) return policy.tools.includes("web_search");
  if (!writing && /^artifact:\/\/[A-Za-z0-9_-]+(?::[^\s]*)?$/.test(locator)) return true;
  const skill = /^skill:\/\/([^/:]+)(.*)$/.exec(locator);
  if (skill) {
    if (writing || !Object.hasOwn(policy.skills, skill[1])) return false;
    locator = skill[2].startsWith("/")
      ? path.join(path.dirname(policy.skills[skill[1]]), skill[2].slice(1))
      : policy.skills[skill[1]] + skill[2];
  } else if (/^[a-z][a-z0-9+.-]*:\/\//i.test(locator)) return false;
  let file = locator.replace(/:[^/]*$/, "");
  const globIndex = file.search(/[?*\[{]/);
  if (globIndex !== -1) file = file.slice(0, globIndex);
  file = path.resolve(policy.cwd, file || ".");
  if (!writing && policy.readableFiles.includes(file) && inside(policy.cwd, realpathSync(file))) return true;
  if (policy.reportPath && file === policy.reportPath) return true;
  if (!inside(policy.cwd, file)) return false;
  const relative = path.relative(policy.cwd, file);
  if (relative.split(path.sep).some(part => [".omp", ".claude", ".agents", ".codex", ".opencode"].includes(part))) return false;
  if (relative.split(path.sep).includes("evals")) return false;
  if (["AGENTS.md", "CLAUDE.md", "GEMINI.md", ".mcp.json", "mcp.json"].includes(path.basename(file))) return false;
  if (relative.split(path.sep).includes(".git")) return false;
  let existing = file;
  while (!existsSync(existing) && existing !== path.dirname(existing)) existing = path.dirname(existing);
  if (!inside(policy.cwd, realpathSync(existing))) return false;
  if (!writing && path.basename(file) === "SKILL.md" && !Object.values(policy.skills).some(candidate => realpathSync(candidate) === realpathSync(file))) return false;
  return true;
}

function inside(root, file) {
  const relative = path.relative(root, file);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}

function shellWords(command) {
  if (typeof command !== "string" || !command.trim() || /[$`;&|<>\n\r(){}]/.test(command)) return null;
  const words = [];
  let word = "";
  let quote = null;
  let started = false;
  for (let index = 0; index < command.length; index++) {
    const character = command[index];
    if (quote) {
      if (character === quote) quote = null;
      else word += character;
      continue;
    }
    if (character === "'" || character === '"') { quote = character; started = true; continue; }
    if (/\s/.test(character)) {
      if (started) { words.push(word); word = ""; started = false; }
      continue;
    }
    if (character === "\\") return null;
    word += character;
    started = true;
  }
  if (quote) return null;
  if (started) words.push(word);
  return words;
}

function allowedBash(input, policy) {
  if (!input || typeof input !== "object" || input.name || input.async || input.ready || input.pty) return false;
  const cwd = path.resolve(policy.cwd, input.cwd ?? ".");
  if (!inside(policy.cwd, cwd) || !existsSync(cwd) || !inside(policy.cwd, realpathSync(cwd))) return false;
  const words = shellWords(input.command);
  if (!words) return false;
  if (words[0] === "git") {
    const args = words.slice(1);
    if (args[0] === "-C") {
      const directory = args[1] && path.resolve(cwd, args[1]);
      if (!directory || !existsSync(directory) || !inside(policy.cwd, realpathSync(directory))) return false;
      args.splice(0, 2);
    }
    return ["show", "status", "diff"].includes(args[0])
      && !args.some(arg => /^(--ext-diff|--textconv|--no-index|--output|--exec|--config-env)(=|$)/.test(arg));
  }
  if (cwd !== policy.cwd) return false;
  if (words[0] === "bash" && policy.bashPolicy.standardVerification === true && words.length === 2) {
    return ["verify.sh", "verify-test.sh", "skill-package-check.sh"]
      .some(name => words[1] === `skills/standard-update/scripts/${name}`);
  }
  if (policy.bashPolicy.projectVerification === true && words.length === 5 && words[0] === "npm"
    && words[1] === "--prefix" && words[2] === "target-project" && words[3] === "run") {
    return ["check", "verify", "verify:push"].includes(words[4]);
  }
  if (policy.bashPolicy.conformance === true && words[0] === "node"
    && words[1] === "skills/standard-conformance/scripts/check-coverage.mjs" && ["inventory", "check"].includes(words[2])) {
    for (let index = 3; index < words.length; index += 2) {
      const flag = words[index];
      const value = words[index + 1];
      if (!["--standard-root", "--project-root", "--report"].includes(flag) || !value) return false;
      if (flag === "--report") {
        if (!policy.reportPath || path.resolve(policy.cwd, value) !== policy.reportPath) return false;
      } else if (!allowedPath(value, policy, false)) return false;
    }
    return true;
  }
  return false;
}
