#!/usr/bin/env bash
set -euo pipefail

required_commands=(bash dirname fd git node)
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
cd "$REPO_ROOT"

node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const skillNames = ["standard-apply", "standard-audit", "standard-conformance", "standard-feedback", "standard-update", "cli-design", "property-testing"];
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
const present = file => {
  try { fs.lstatSync(file); return true; } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
};
const actorFixture = isolatedEvaluation
  && skillNames.includes(isolatedSkill) && allowedConfigurations.has(isolatedConfiguration);
const exposedSkills = isolatedConfiguration === "without-skill" ? []
  : [isolatedSkill, ...(isolatedSkill === "standard-update" ? ["cli-design", "property-testing"] : [])];
const auditProjection = actorFixture && isolatedSkill === "standard-update"
  && present("skills/standard-audit/evals");
if (auditProjection) exposedSkills.push("standard-audit");
if (actorFixture && auditProjection) {
  const projectionRoot = "skills/standard-audit/evals";
  if (!fs.lstatSync(projectionRoot).isDirectory()
    || fs.readdirSync(projectionRoot).join(",") !== "evals.json") {
    reject("standard-audit: 隔離入力は evals.json の task ID と prompt だけであること");
  } else {
    const projection = parseJson(path.join(projectionRoot, "evals.json"));
    if (projection && (Object.keys(projection).sort().join(",") !== "evals,skill_name"
      || projection.skill_name !== "standard-audit" || !Array.isArray(projection.evals)
      || projection.evals.length < 3)) {
      reject("standard-audit: 隔離 task 入力が不正");
    } else if (projection) {
      const ids = new Set();
      for (const item of projection.evals) {
        if (!item || Object.keys(item).sort().join(",") !== "id,prompt"
          || !Number.isInteger(item.id) || ids.has(item.id)
          || typeof item.prompt !== "string" || item.prompt.length < 40) {
          reject("standard-audit: 隔離 task 入力に rubric または不正な task がある");
        }
        ids.add(item?.id);
      }
    }
  }
}


for (const skillName of skillNames) {
  const root = path.join("skills", skillName);
  if (!present(root)) {
    if (actorFixture && skillName === isolatedSkill && isolatedConfiguration === "without-skill") continue;
    reject(`${skillName}: skill directory がない`);
    continue;
  }
  if (!fs.lstatSync(root).isDirectory()) {
    reject(`${skillName}: skill directory は実 directory であること`);
    continue;
  }
  if (actorFixture && skillName === isolatedSkill && isolatedConfiguration === "without-skill") {
    reject(`${skillName}: without-skill fixture に選択 package が残っている`);
    continue;
  }
  const skillPath = path.join(root, "SKILL.md");
  if (actorFixture && !exposedSkills.includes(skillName)) {
    if (present(skillPath) || present(path.join(root, "references")) || present(path.join(root, "evals"))) {
      reject(`${skillName}: 非公開 package の instruction または eval が残っている`);
    }
    continue;
  }
  if (!present(skillPath) || !fs.lstatSync(skillPath).isFile()) {
    reject(`${skillName}: SKILL.md がない、または実 file ではない`);
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
  if (actorFixture) {
    if (present(path.join(root, "evals")) && !(auditProjection && skillName === "standard-audit")) {
      reject(`${skillName}: 隔離 fixture に eval oracle が残っている`);
    }
    continue;
  }

  const evalRoot = path.join(root, "evals");
  if (!fs.existsSync(evalRoot)) {
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
        if (typeof item.model !== "string" || !item.model || /\s/.test(item.model)) {
          reject(`${skillName}: model はdefaultまたは空白を含まないOMP selectorであること`);
        }
        if (Object.hasOwn(item, "fixture")) {
          const fixture = item.fixture;
          const keys = fixture && typeof fixture === "object" && !Array.isArray(fixture) ? Object.keys(fixture) : [];
          const lineStore = fixture?.kind === "line-store" && ["hide", "map"].includes(fixture.stage)
            && keys.length === 2 && keys.every(key => ["kind", "stage"].includes(key));
          const semantic = fixture?.kind === "semantic-boundaries" && ["explicit", "exploration"].includes(fixture.reading)
            && keys.length === 2 && keys.every(key => ["kind", "reading"].includes(key));
          if (skillName !== "standard-apply" || (!lineStore && !semantic)) {
            reject(`${skillName}: fixture は明示された安全なkindとstageまたはreadingだけを持つこと`);
          }
        }
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
done < <(fd --type f --extension sh --print0 . skills)

while IFS= read -r -d '' script; do
  node --check "$script" >/dev/null
done < <(fd --type f --extension mjs --print0 . skills)

if [ "${SKILL_EVAL_ISOLATED_SKILL:-}" = standard-conformance ] \
  && [ "${SKILL_EVAL_CONFIGURATION:-}" = without-skill ] \
  && [ ! -e skills/standard-conformance ] \
  && [ ! -L skills/standard-conformance ]; then
  printf 'SKIP: standard-conformance is absent in its without-skill fixture\n'
else
  node --test skills/standard-conformance/scripts/check-coverage.test.mjs
fi

printf 'PASS: skill package structure and applicable checks\n'
