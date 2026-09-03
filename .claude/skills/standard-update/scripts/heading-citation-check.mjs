#!/usr/bin/env node
// 鉤括弧「」で引用された規律名が、同じ行の link 先 file の見出しに逐語一致するかを検査する。
// 対象は標準本文(principles/concerns/structure/tools/tools/process + root README.md)。
// fenced code の中は見出しとしても引用としても数えない。
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";

const ROOT = process.cwd();
const AREAS = ["principles", "concerns", "structure", "tools", "process"];

function mdFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) out.push(...mdFiles(path));
    else if (entry.endsWith(".md")) out.push(path);
  }
  return out;
}

const files = AREAS.flatMap((area) => mdFiles(join(ROOT, area)));
files.push(join(ROOT, "README.md"));

function bodyLines(path) {
  const lines = [];
  let inFence = false;
  let fenceMark = "";
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const fence = line.match(/^\s*(`{3,}|~{3,})/);
    if (fence) {
      if (!inFence) {
        inFence = true;
        fenceMark = fence[1][0];
      } else if (fence[1][0] === fenceMark) {
        inFence = false;
      }
      lines.push(null);
      continue;
    }
    lines.push(inFence ? null : line);
  }
  return lines;
}

const headings = new Map();
for (const file of files) {
  const set = new Set();
  for (const line of bodyLines(file)) {
    if (line === null) continue;
    const m = line.match(/^#{1,3} (.+)$/);
    if (m) set.add(m[1].trim());
  }
  headings.set(resolve(file), set);
}

const violations = [];
let citations = 0;
for (const file of files) {
  const dir = dirname(file);
  bodyLines(file).forEach((line, index) => {
    if (line === null) return;
    // 引用の検査対象は link を含む行だけ。引用は link 先の見出しに加え、同じ file 内の見出しも指せる。
    const targets = [resolve(file)];
    let hasLink = false;
    for (const link of line.matchAll(/\]\(([^)#\s]+\.md)\)/g)) {
      hasLink = true;
      const target = resolve(dir, link[1]);
      if (headings.has(target)) targets.push(target);
    }
    if (!hasLink) return;
    for (const quote of line.matchAll(/「([^「」]+)」/g)) {
      citations += 1;
      const name = quote[1];
      if (!targets.some((target) => headings.get(target).has(name))) {
        violations.push(`${file.slice(ROOT.length + 1)}:${index + 1}: 「${name}」 が link 先にも自 file にも見出しとして無い`);
      }
    }
  });
}

console.log(`link 行の鉤括弧引用: ${citations}`);
for (const violation of violations) console.log(violation);
console.log(`citation violations: ${violations.length}`);
process.exit(violations.length === 0 ? 0 : 1);
