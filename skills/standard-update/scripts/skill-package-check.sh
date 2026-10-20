#!/usr/bin/env bash
set -euo pipefail

STANDARD_ROOT_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --standard-root)
      if [ -n "$STANDARD_ROOT_ARG" ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        printf 'FAIL: --standard-root には空でない path を一度だけ指定すること\nusage: %s [--standard-root ROOT]\n' "${BASH_SOURCE[0]##*/}" >&2
        exit 2
      fi
      STANDARD_ROOT_ARG="$2"
      shift 2
      ;;
    *)
      printf 'FAIL: 不明な引数: %s\nusage: %s [--standard-root ROOT]\n' "$1" "${BASH_SOURCE[0]##*/}" >&2
      exit 2
      ;;
  esac
done

required_commands=(bash dirname fd node)
[ -n "$STANDARD_ROOT_ARG" ] || required_commands+=(git)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'FAIL: missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -n "$STANDARD_ROOT_ARG" ]; then
  STANDARD_ROOT="$(CDPATH= cd -- "$STANDARD_ROOT_ARG" 2>/dev/null && pwd -P)" || {
    printf 'FAIL: --standard-root が存在する directory ではない: %s\n' "$STANDARD_ROOT_ARG" >&2
    exit 2
  }
else
  STANDARD_ROOT="$(git -C "$SCRIPT_DIR/../../.." rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'FAIL: git repository で実行すること\n' >&2
    exit 1
  }
fi
cd "$STANDARD_ROOT"

node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const skillNames = ["standard-apply", "standard-audit", "standard-conformance", "standard-feedback", "standard-update", "cli-design", "property-testing"];
let violations = 0;

function reject(message) {
  console.error(`FAIL: ${message}`);
  violations += 1;
}

const present = file => {
  try { fs.lstatSync(file); return true; } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
};


for (const skillName of skillNames) {
  const root = path.join("skills", skillName);
  if (!present(root)) {
    reject(`${skillName}: skill directory がない`);
    continue;
  }
  if (!fs.lstatSync(root).isDirectory()) {
    reject(`${skillName}: skill directory は実 directory であること`);
    continue;
  }

  const skillPath = path.join(root, "SKILL.md");
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



printf 'PASS: skill package structure and applicable checks\n'
