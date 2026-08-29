#!/usr/bin/env bash
set -euo pipefail

required_commands=(bash fd git node)
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
cd "$REPO_ROOT"

node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const skillNames = ["standard-apply", "standard-audit", "standard-update"];
const allowedModels = new Set(["haiku", "sonnet", "opus"]);
const allowedConfigurations = new Set(["old-skill", "without-skill", "with-skill"]);
const isolatedSkill = process.env.SKILL_EVAL_ISOLATED_SKILL ?? "";
const isolatedConfiguration = process.env.SKILL_EVAL_CONFIGURATION ?? "";
const isolatedEvaluation = isolatedSkill !== "" || isolatedConfiguration !== "";
let violations = 0;

function reject(message) {
  console.error(`FAIL: ${message}`);
  violations += 1;
}

function parseJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    reject(`${file}: JSON を読めない: ${error.message}`);
    return undefined;
  }
}

if (isolatedEvaluation
  && (!skillNames.includes(isolatedSkill) || !allowedConfigurations.has(isolatedConfiguration))) {
  reject("隔離評価では SKILL_EVAL_ISOLATED_SKILL と SKILL_EVAL_CONFIGURATION の有効な組が必要");
}

for (const skillName of skillNames) {
  const root = path.join(".claude", "skills", skillName);
  if (!fs.existsSync(root)) {
    if (isolatedEvaluation && skillName === isolatedSkill && isolatedConfiguration === "without-skill") continue;
    reject(`${skillName}: skill directory がない`);
    continue;
  }
  const skillPath = path.join(root, "SKILL.md");
  if (!fs.existsSync(skillPath)) {
    reject(`${skillName}: SKILL.md がない`);
    continue;
  }

  const skillSource = fs.readFileSync(skillPath, "utf8");
  const frontmatter = skillSource.match(/^---\n([\s\S]*?)\n---\n/);
  if (!frontmatter) {
    reject(`${skillName}: YAML frontmatter がない`);
  } else {
    const name = frontmatter[1].match(/^name:\s*(.+)$/m)?.[1]?.trim();
    const description = frontmatter[1].match(/^description:\s*(.+)$/m)?.[1]?.trim();
    if (name !== skillName) reject(`${skillName}: frontmatter name が directory と一致しない`);
    if (!name || name.length > 64 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) {
      reject(`${skillName}: name は64文字以下のlowercase/digit/hyphenであること`);
    }
    if (!description || description.length > 1024 || /[<>]/.test(description)) {
      reject(`${skillName}: description は1..1024文字でXML tagを含まないこと`);
    }
  }
  const lineCount = skillSource.endsWith("\n")
    ? skillSource.slice(0, -1).split("\n").length
    : skillSource.split("\n").length;
  if (lineCount >= 500) reject(`${skillName}: SKILL.md は500行未満であること`);

  const evalRoot = path.join(root, "evals");
  if (!fs.existsSync(evalRoot)) {
    if (isolatedEvaluation && skillName === isolatedSkill) continue;
    reject(`${skillName}: evals directory がない`);
    continue;
  }

  const evalPath = path.join(evalRoot, "evals.json");
  const triggerPath = path.join(evalRoot, "trigger-evals.json");
  if (!fs.existsSync(evalPath) || !fs.existsSync(triggerPath)) {
    reject(`${skillName}: evals directory には evals.json と trigger-evals.json の両方が必要`);
    continue;
  }

  const data = parseJson(evalPath);
  if (data) {
    if (data.skill_name !== skillName) reject(`${skillName}: skill_name が一致しない`);
    if (!Array.isArray(data.evals) || data.evals.length < 3) {
      reject(`${skillName}: task eval は3件以上必要`);
    } else {
      const ids = new Set();
      for (const item of data.evals) {
        if (!Number.isInteger(item.id) || ids.has(item.id)) reject(`${skillName}: eval id が不正または重複`);
        ids.add(item.id);
        if (typeof item.prompt !== "string" || item.prompt.length < 40) reject(`${skillName}: prompt が短すぎる`);
        if (typeof item.expected_output !== "string" || item.expected_output.length < 20) {
          reject(`${skillName}: expected_output が短すぎる`);
        }
        if (!Array.isArray(item.expectations) || item.expectations.length < 3
          || item.expectations.some((expectation) => typeof expectation !== "string" || expectation.length === 0)) {
          reject(`${skillName}: expectations は空でない文字列を3件以上持つこと`);
        }
        if (!Array.isArray(item.files)) reject(`${skillName}: files は配列であること`);
        if (!allowedModels.has(item.model)) reject(`${skillName}: model が不正`);
      }
      const models = new Set(data.evals.map((item) => item.model));
      for (const model of allowedModels) {
        if (!models.has(model)) reject(`${skillName}: ${model} の task eval がない`);
      }
    }
  }

  const triggers = parseJson(triggerPath);
  if (triggers) {
    if (!Array.isArray(triggers) || triggers.length < 20) {
      reject(`${skillName}: trigger eval は20件以上必要`);
    } else {
      const queries = new Set();
      const positive = triggers.filter((item) => item.should_trigger === true).length;
      const negative = triggers.filter((item) => item.should_trigger === false).length;
      if (positive < 8 || negative < 8) reject(`${skillName}: positive/negative は各8件以上必要`);
      for (const item of triggers) {
        if (typeof item.query !== "string" || item.query.length < 20 || queries.has(item.query)) {
          reject(`${skillName}: trigger query が短いか重複している`);
        }
        queries.add(item.query);
        if (typeof item.should_trigger !== "boolean") reject(`${skillName}: should_trigger はbooleanであること`);
        if (Object.hasOwn(item, "expected_skill") && item.expected_skill !== null
          && !skillNames.includes(item.expected_skill)) {
          reject(`${skillName}: expected_skill が不正`);
        }
      }
    }
  }
}

console.log(`package violations: ${violations}`);
process.exit(violations === 0 ? 0 : 1);
NODE

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(fd --type f --extension sh --print0 . .claude/skills)

while IFS= read -r -d '' script; do
  node --check "$script" >/dev/null
done < <(fd --type f --extension mjs --print0 . .claude/skills)

printf 'PASS: skill package structure and script syntax\n'
