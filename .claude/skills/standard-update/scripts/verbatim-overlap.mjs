#!/usr/bin/env node
// principles と concerns の逐語一致(5文節相当)を機械検出する。goal-04 の再発防止。
// 手法: line 単位のseed-and-extend部分文字列一致(シード長10文字→最大一致まで拡張)。
// 日本語は分かち書きが無いため、5文節をおよそ18文字以上の連続一致として近似する。
// 閾値未満は出力しない。閾値以上は真陽性か偽陽性かを人が判定する(短い定型句の一致は偽陽性になりうる)。
// verify.sh から呼ばれ、repo の root で実行する前提(cwd 基準で principles/・concerns/ を読む)。
import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const SEED = 10;
const THRESHOLD = 18;

function readLines(dir) {
  const files = fs.readdirSync(path.join(ROOT, dir)).filter((f) => f.endsWith(".md"));
  const out = [];
  for (const f of files) {
    const raw = fs.readFileSync(path.join(ROOT, dir, f), "utf8");
    const noFence = raw.replace(/```[\s\S]*?```/g, "");
    const lines = noFence.split("\n");
    lines.forEach((lineRaw, idx) => {
      let line = lineRaw;
      if (/^\s*#/.test(line)) return; // heading / section marker
      if (/^\s*\|/.test(line)) return; // table row
      line = line.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1"); // link text keep, path drop
      line = line.trim();
      if (line.length < SEED) return;
      out.push({ file: `${dir}/${f}`, lineNo: idx + 1, text: line });
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
