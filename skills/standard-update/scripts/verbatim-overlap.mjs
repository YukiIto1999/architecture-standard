#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { markdownBodyLines } from "./markdown-body-lines.mjs";

const args = process.argv.slice(2);
if (args.length !== 0 && (args.length !== 2 || args[0] !== "--standard-root" || args[1] === "")) {
  console.error("usage: verbatim-overlap.mjs [--standard-root ROOT]");
  process.exit(2);
}
const ROOT = fs.realpathSync(args.length === 2 ? args[1] : fileURLToPath(new URL("../../../", import.meta.url)));
const SEED = 10;
const THRESHOLD = 18;

// 正本の見出しの逐語引用が必須のため鉤括弧内の見出しの重複判定は不可
const AREAS = ["principles", "concerns", "structure", "tools", "languages", "process"];
const HEADINGS = new Set();
for (const area of AREAS) {
  const stack = [path.join(ROOT, area)];
  while (stack.length > 0) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir)) {
      const p = path.join(dir, entry);
      if (fs.statSync(p).isDirectory()) stack.push(p);
      else if (entry.endsWith(".md")) {
        for (const line of markdownBodyLines(fs.readFileSync(p, "utf8"))) {
          const m = line.match(/^#{1,3} (.+)$/);
          if (m) HEADINGS.add(m[1].trim());
        }
      }
    }
  }
}

/**
 * 原則と関心事の逐語一致を調べる本文の収集
 * @param {string} dir - 標準 root 相対の検査対象ディレクトリ
 * @returns {Array<{file: string, lineNo: number, text: string}>} 元の行番号を保持した引用の間の本文断片
 * @throws {@link Error} 対象ツリーへのアクセス失敗
 */
function readLines(dir) {
  const files = [];
  const stack = [dir];
  while (stack.length > 0) {
    const rel = stack.pop();
    for (const entry of fs.readdirSync(path.join(ROOT, rel))) {
      const relPath = `${rel}/${entry}`;
      if (fs.statSync(path.join(ROOT, relPath)).isDirectory()) stack.push(relPath);
      else if (entry.endsWith(".md")) files.push(relPath.slice(dir.length + 1));
    }
  }
  const out = [];
  for (const f of files) {
    const raw = fs.readFileSync(path.join(ROOT, dir, f), "utf8");
    const lines = markdownBodyLines(raw);
    lines.forEach((lineRaw, idx) => {
      let line = lineRaw;
      if (/^\s*#/.test(line)) return;
      if (/^\s*\|/.test(line)) return;
      if (/^\s*- \[/.test(line)) return;
      line = line.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1");
      line = line.replace(/「([^「」]+)」/g, (whole, name) => (HEADINGS.has(name) ? "\u0000" : whole));
      for (const segment of line.split("\u0000")) {
        const text = segment.trim();
        if (text.length >= SEED) out.push({ file: `${dir}/${f}`, lineNo: idx + 1, text });
      }
    });
  }
  return out;
}

const principlesLines = readLines("principles");
const concernsLines = readLines("concerns");

// seed index: seed substring -> [{lineIdx, pos}]
const seedIndex = new Map();
principlesLines.forEach((entry, lineIdx) => {
  const t = entry.text;
  for (let i = 0; i + SEED <= t.length; i++) {
    const seed = t.substr(i, SEED);
    if (!seedIndex.has(seed)) seedIndex.set(seed, []);
    seedIndex.get(seed).push({ lineIdx, pos: i });
  }
});

/**
 * 共通シードを含む関心事側の最大一致範囲の取得
 * @param {string} cText - 関心事側の比較対象の本文
 * @param {number} cPos - 関心事側の一致済みシードの開始位置
 * @param {string} pText - 原則側の比較対象の本文
 * @param {number} pPos - 原則側の同じシードの開始位置
 * @returns {{from: number, to: number}} 関心事側の開始位置を含み終了位置を含まない UTF-16 単位の一致範囲
 */
function extend(cText, cPos, pText, pPos) {
  let start = 0;
  while (
    cPos - start - 1 >= 0 &&
    pPos - start - 1 >= 0 &&
    cText[cPos - start - 1] === pText[pPos - start - 1]
  ) {
    start++;
  }
  let end = SEED;
  while (
    cPos + end < cText.length &&
    pPos + end < pText.length &&
    cText[cPos + end] === pText[pPos + end]
  ) {
    end++;
  }
  return { from: cPos - start, to: cPos + end }; // [from, to) in concerns text
}

const results = [];
concernsLines.forEach((cEntry) => {
  const cText = cEntry.text;
  const covered = []; // [from,to) spans already reported for this line
  for (let i = 0; i + SEED <= cText.length; i++) {
    if (covered.some((s) => i >= s[0] && i < s[1])) continue;
    const seed = cText.substr(i, SEED);
    const hits = seedIndex.get(seed);
    if (!hits) continue;
    for (const h of hits) {
      const pEntry = principlesLines[h.lineIdx];
      const span = extend(cText, i, pEntry.text, h.pos);
      const matched = cText.slice(span.from, span.to);
      if (matched.length >= THRESHOLD) {
        covered.push([span.from, span.to]);
        results.push({
          concernsFile: cEntry.file,
          concernsLine: cEntry.lineNo,
          principlesFile: pEntry.file,
          principlesLine: pEntry.lineNo,
          length: matched.length,
          text: matched,
        });
      }
    }
  }
});

// dedupe identical (concernsFile,concernsLine,text,principlesFile) entries
const seen = new Set();
const dedup = results.filter((r) => {
  const key = `${r.concernsFile}:${r.concernsLine}:${r.principlesFile}:${r.text}`;
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});

dedup.sort((a, b) => b.length - a.length);

console.log(`SEED=${SEED} THRESHOLD=${THRESHOLD}文字(5文節相当の近似)`);
console.log(`candidates: ${dedup.length}`);
for (const r of dedup) {
  console.log(
    `${r.length}\t${r.concernsFile}:${r.concernsLine}\t<->\t${r.principlesFile}:${r.principlesLine}\t"${r.text}"`
  );
}
