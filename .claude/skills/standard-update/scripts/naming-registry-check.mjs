#!/usr/bin/env node
// concerns・structure・languages の製品名指しが tools のエントリに登録済みかを機械照合する。goal-25・goal-26(languages を追加)。
//
// 手法:
//   1. tools/{language,stack,inspection,services,platforms}.md の各 `## 見出し` エントリから、
//      見出しテキストと「採用は、」で始まる行を抽出し、名指し語(Latin token)の registry を作る。
//      「判断基準」欄は却下・比較の記述を含みうるため、registry の抽出対象にしない。
//   2. concerns/*.md・structure/**/*.md・languages/**/*.md の、fenced code と inline code(`...`)を
//      除いた本文のうち「である。」で終わる行(tools の採用行と同じ宣言文型)から、
//      大文字で始まり内部に小文字を含む token を候補として抽出する。
//      `*.md` で終わる token(標準内の自己参照ファイル名)は候補から除く。
//      inline code を除くのは、言語の型・API 名(`Effect`・`Drop` 等)を製品名と区別するためである。
//   3. 候補が registry に無ければ、tools に未登録の製品名指しとして報告する。
//
// 限界: 「…である。」の宣言文型に絞った検出であり、あらゆる言い回しを機械的に網羅する
//   汎用の固有名詞抽出ではない。HTTP・API のような一般的な頭字語(小文字を含まない token)は
//   候補から外れる。これは、規格・頭字語と、市場から選ぶ製品名を区別するための意図的な絞り込みである。
import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();

function extractRegistry() {
  const toolFiles = ["language", "stack", "inspection", "services", "platforms"].map((f) =>
    path.join(ROOT, "tools", `${f}.md`)
  );
  const tokenRe = /[A-Za-z][A-Za-z0-9_.#+@/-]*/g;
  const registry = new Set();
  for (const file of toolFiles) {
    const text = fs.readFileSync(file, "utf8");
    const blocks = text.split(/^## /m).slice(1);
    for (const block of blocks) {
      const heading = block.split("\n", 1)[0];
      let source = `${heading}\n`;
      for (const line of block.split("\n")) {
        if (line.startsWith("採用は、")) source += `${line}\n`;
      }
      let m;
      while ((m = tokenRe.exec(source))) registry.add(m[0]);
    }
  }
  return registry;
}

function walk(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, out);
    else if (p.endsWith(".md")) out.push(p);
  }
  return out;
}

function stripFences(text) {
  const lines = text.split("\n");
  let inFence = false;
  const out = [];
  for (const line of lines) {
    if (line.trim().startsWith("```")) {
      inFence = !inFence;
      continue;
    }
    out.push(inFence ? "" : line);
  }
  return out;
}

function stripInlineCode(line) {
  return line.replace(/`[^`]*`/g, "");
}

function findCandidates(files) {
  const candidateRe = /\b[A-Z][A-Za-z0-9_.#+@/-]*/g;
  const found = [];
  for (const file of files) {
    const lines = stripFences(fs.readFileSync(file, "utf8"));
    lines.forEach((rawLine, idx) => {
      const trimmed = rawLine.trim();
      if (!trimmed.endsWith("である。")) return;
      const line = stripInlineCode(trimmed);
      let m;
      while ((m = candidateRe.exec(line))) {
        const tok = m[0];
        if (tok.endsWith(".md")) continue; // 標準内の自己参照ファイル名
        if (!/[a-z]/.test(tok)) continue; // 内部に小文字を含まない頭字語(HTTP・API等)は対象外
        found.push({ file: path.relative(ROOT, file), line: idx + 1, token: tok, text: trimmed });
      }
    });
  }
  return found;
}

const registry = extractRegistry();

const files = [];
walk(path.join(ROOT, "concerns"), files);
walk(path.join(ROOT, "structure"), files);
walk(path.join(ROOT, "languages"), files);

const candidates = findCandidates(files);
const violations = candidates.filter((c) => !registry.has(c.token));

console.log(`tools registry size: ${registry.size}`);
console.log(`violations: ${violations.length}`);
for (const v of violations) {
  console.log(`${v.file}:${v.line}\t${v.token}\t"${v.text}"`);
}
