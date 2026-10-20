#!/usr/bin/env node
import { readFileSync, readdirSync, realpathSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { markdownBodyLines } from "./markdown-body-lines.mjs";

const args = process.argv.slice(2);
if (args.length !== 0 && (args.length !== 2 || args[0] !== "--standard-root" || args[1] === "")) {
  console.error("usage: heading-citation-check.mjs [--standard-root ROOT]");
  process.exit(2);
}
const ROOT = realpathSync(args.length === 2 ? args[1] : fileURLToPath(new URL("../../../", import.meta.url)));
const AREAS = ["principles", "concerns", "structure", "tools", "languages", "process"];

/**
 * 標準の見出し索引に含める Markdown ファイルの列挙
 * @param {string} dir - 探索を始める領域のディレクトリ
 * @returns {string[]} 配下の Markdown ファイルのパス
 * @throws {@link Error} 対象ツリーへのアクセス失敗
 */
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

/**
 * 引用診断の行番号を保持する Markdown 本文の読取り
 * @param {string} path - 検査対象の Markdown ファイルのパス
 * @returns {string[]} フェンスの行を空文字に置き換えた元の行番号順の本文
 * @throws {@link Error} 対象ファイルの読取り失敗
 */
function bodyLines(path) {
  return markdownBodyLines(readFileSync(path, "utf8"));
}

const headings = new Map();
for (const file of files) {
  const set = new Set();
  for (const line of bodyLines(file)) {
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
