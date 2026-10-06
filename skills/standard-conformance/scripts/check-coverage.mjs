#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";

const areas = ["principles", "concerns", "structure", "tools", "languages", "process"];
const diagnostics = [];
const nonempty = (value) => typeof value === "string" && value.trim().length > 0;

function diagnose(rule, location, actual, expected) {
  diagnostics.push({ rule, location, actual, expected });
}

function requireValue(condition, message) {
  if (!condition) throw new Error(message);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function within(root, file) {
  const relative = path.relative(root, file);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}

function feed(hash, name, bytes) {
  hash.update(`${Buffer.byteLength(name)}:${name}${bytes.length}:`);
  hash.update(bytes);
}

function sectionLines(text, heading) {
  const lines = [];
  let active = false;
  let fence = null;
  for (const line of text.split("\n")) {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    if (marker) {
      if (!fence) fence = marker[1];
      else if (marker[1][0] === fence[0] && marker[1].length >= fence.length && line.slice(marker[0].length).trim() === "") fence = null;
      continue;
    }
    if (fence) continue;
    if (line.startsWith("## ")) active = line === `## ${heading}`;
    else if (active) lines.push(line);
  }
  return lines;
}

function mechanismKinds(expression) {
  let depth = 0;
  let names = "";
  for (const character of expression) {
    if (character === "(" || character === "（") depth += 1;
    else if (character === ")" || character === "）") depth -= 1;
    else if (depth === 0) names += character;
    requireValue(depth >= 0, `検証手段の括弧が不正: ${expression}`);
  }
  requireValue(depth === 0, `検証手段の括弧が不正: ${expression}`);
  const mechanical = new Set(["型", "型/実行テスト", "構造検査", "analyzer", "analyzer/lint", "analyzer と source generator", "計測", "mutation", "runner 検査", "artifact 検査", "実行テスト"]);
  const kinds = new Set();
  for (const name of names.split("+").map((value) => value.trim())) {
    requireValue(name === "レビュー" || mechanical.has(name), `未知の検証手段: ${name}`);
    kinds.add(name === "レビュー" ? "review" : "machine");
  }
  return [...kinds].sort();
}

function requiredChecks(texts) {
  const assignments = {};
  function assign(document, heading, kinds) {
    requireValue(Object.hasOwn(texts, document), `割当先の正本文書がない: ${document}`);
    const rule = `${document}#${heading}`;
    const list = assignments[document] ??= [];
    requireValue(!list.some((value) => value.rule === rule), `規律の検証割当が重複: ${rule}`);
    list.push({ rule, kinds });
  }
  for (const [document, text] of Object.entries(texts)) {
    if (/^(principles|concerns)\/[^/]+\/README\.md$/.test(document)) {
      for (const line of sectionLines(text, "規律")) {
        const match = line.match(/^- \[[^\]]+\]\(([^)]+\.md)\) — (機械(?:\+レビュー)?|レビュー)\(/);
        if (!match) continue;
        const target = path.posix.normalize(path.posix.join(path.posix.dirname(document), match[1]));
        requireValue(Object.hasOwn(texts, target), `台帳が未知の規律を指す: ${target}`);
        const heading = texts[target].match(/^## (.+)$/m)?.[1];
        requireValue(nonempty(heading), `規律の見出しがない: ${target}`);
        const kinds = [];
        if (match[2].includes("機械")) kinds.push("machine");
        if (match[2].includes("レビュー")) kinds.push("review");
        assign(target, heading, kinds);
      }
    }
    if (/^languages\/[^/]+\/inspection\.md$/.test(document)) {
      for (const line of sectionLines(text, "規則と検証機構の対応")) {
        if (!line.startsWith("|")) continue;
        const cells = line.split("|").map((value) => value.trim());
        if (cells[1] === "ファイル" || /^-+$/.test(cells[1])) continue;
        requireValue(cells.length === 5 && nonempty(cells[1]) && nonempty(cells[2]) && nonempty(cells[3]), `言語の検証対応表が不正: ${document}: ${line}`);
        const target = `${path.posix.dirname(document)}/${cells[1]}.md`;
        assign(target, cells[2], mechanismKinds(cells[3]));
      }
    }
  }
  for (const document of Object.keys(texts)) {
    if (/^(principles|concerns)\/[^/]+\/(?!README\.md$)[^/]+\.md$/.test(document)) requireValue(Object.hasOwn(assignments, document), `規律の検証割当がない: ${document}`);
  }
  return assignments;
}

function standardInventory(root) {
  const documents = ["README.md"];
  function walk(directory) {
    for (const entry of fs.readdirSync(path.join(root, directory), { withFileTypes: true })) {
      const relative = `${directory}/${entry.name}`;
      if (entry.isDirectory()) walk(relative);
      else if (entry.name.endsWith(".md")) {
        requireValue(entry.isFile(), `正本文書は通常fileである必要がある: ${relative}`);
        documents.push(relative);
      } else if (entry.isSymbolicLink()) {
        throw new Error(`正本のsymlinkを検査対象外にできない: ${relative}`);
      }
    }
  }
  for (const area of areas) {
    const before = documents.length;
    walk(area);
    requireValue(documents.length > before, `正本領域にMarkdown文書がない: ${area}`);
  }
  documents.sort();
  const hash = crypto.createHash("sha256");
  const texts = {};
  for (const document of documents) {
    const bytes = fs.readFileSync(path.join(root, document));
    texts[document] = bytes.toString("utf8");
    requireValue(texts[document].trim().length > 0, `正本文書が空: ${document}`);
    feed(hash, document, bytes);
  }
  return { documents, standardDigest: hash.digest("hex"), requiredChecks: requiredChecks(texts) };
}

function projectDigest(root) {
  const gitRoot = fs.realpathSync(execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim());
  requireValue(within(gitRoot, root), "--project-rootはGit repository内である必要がある");
  const listing = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z"], { cwd: gitRoot, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  const sourceFiles = listing.split("\0").filter(Boolean);
  requireValue(sourceFiles.length > 0, "Git-visible source集合が空");
  const baseline = path.relative(gitRoot, path.join(root, "docs/conformance-baseline.json"));
  const files = [...new Set([...sourceFiles, baseline])].sort();
  const hash = crypto.createHash("sha256");
  feed(hash, "project-root", Buffer.from(path.relative(gitRoot, root)));
  for (const file of files) {
    const absolute = path.join(gitRoot, file);
    let stat;
    try {
      stat = fs.lstatSync(absolute);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      feed(hash, file, Buffer.from("missing"));
      continue;
    }
    if (stat.isSymbolicLink()) {
      feed(hash, file, Buffer.concat([Buffer.from("symlink\0"), Buffer.from(fs.readlinkSync(absolute))]));
      if (file === baseline) {
        requireValue(within(root, fs.realpathSync(absolute)), "baseline symlinkがproject外を指す");
        feed(hash, "baseline-contents", fs.readFileSync(absolute));
      }
    } else {
      requireValue(stat.isFile(), `Git-visible sourceが通常file/symlinkでない: ${file}`);
      feed(hash, file, Buffer.concat([Buffer.from("file\0"), fs.readFileSync(absolute)]));
    }
  }
  return hash.digest("hex");
}

function violationKey(violation, location) {
  requireValue(violation && typeof violation === "object" && !Array.isArray(violation), `違反objectが必要: ${location}`);
  requireValue(nonempty(violation.rule) && nonempty(violation.file) && nonempty(violation.evidence), `違反のrule/file/evidenceが必要: ${location}`);
  requireValue(Number.isSafeInteger(violation.line) && violation.line > 0 && typeof violation.mechanizable === "boolean", `違反のline/mechanizableが不正: ${location}`);
  const file = violation.file;
  requireValue(!path.isAbsolute(file) && !file.split(/[\\/]/).includes(".."), `違反fileはproject相対pathである必要がある: ${location}`);
  return JSON.stringify([violation.rule, file, violation.line, violation.evidence, violation.mechanizable]);
}

function baselineCounts(report, projectRoot, documents) {
  requireValue(Array.isArray(report.violations), "violations arrayが必要");
  requireValue(report.baseline?.file === "docs/conformance-baseline.json", "baseline.fileはdocs/conformance-baseline.jsonである必要がある");
  const baselinePath = path.join(projectRoot, report.baseline.file);
  let baseline = [];
  let found = false;
  try {
    const actualPath = fs.realpathSync(baselinePath);
    requireValue(within(projectRoot, actualPath), "baseline symlinkがproject外を指す");
    const actual = readJson(actualPath);
    requireValue(Array.isArray(actual.violations), "baseline実体にviolations arrayが必要");
    baseline = actual.violations;
    found = true;
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  const current = new Set(report.violations.map((value, index) => {
    const key = violationKey(value, `violations[${index}]`);
    requireValue(documents.has(value.rule.split("#", 1)[0]), `違反が未知の正本を指す: violations[${index}]: ${value.rule}`);
    return key;
  }));
  const previous = new Set(baseline.map((value, index) => violationKey(value, `baseline.violations[${index}]`)));
  requireValue(current.size === report.violations.length && previous.size === baseline.length, "違反またはbaselineが重複している");
  const newCount = [...current].filter((key) => !previous.has(key)).length;
  const baselineCount = [...current].filter((key) => previous.has(key)).length;
  const resolvedCount = [...previous].filter((key) => !current.has(key)).length;
  return { newCount, baselineCount, resolvedCount, baselineFound: found };
}

function checkReport(report, inventory, digest, projectRoot) {
  const coverage = report.coverage;
  requireValue(coverage && Array.isArray(coverage.entries), "coverage.entries arrayが必要; violationsが空でも監査完了にはならない");
  requireValue(nonempty(coverage.standardDigest) && nonempty(coverage.projectDigest), "coverageの正本/source digestが必要");
  if (coverage.standardDigest !== inventory.standardDigest) diagnose("stale-standard", "coverage.standardDigest", coverage.standardDigest, inventory.standardDigest);
  if (coverage.projectDigest !== digest) diagnose("stale-project", "coverage.projectDigest", coverage.projectDigest, digest);
  const expected = new Set(inventory.documents);
  const counts = baselineCounts(report, projectRoot, expected);
  const seen = new Set();
  let checked = 0;
  for (const [index, entry] of coverage.entries.entries()) {
    const location = `coverage.entries[${index}]`;
    requireValue(entry && typeof entry === "object" && nonempty(entry.document), `documentを持つcoverage objectが必要: ${location}`);
    if (!expected.has(entry.document)) diagnose("unknown-document", location, entry.document, "現在の正本文書");
    if (seen.has(entry.document)) diagnose("duplicate-document", location, entry.document, "文書ごとに一つのdisposition");
    seen.add(entry.document);
    requireValue(["checked", "not-applicable", "unresolved"].includes(entry.disposition), `不正なdisposition: ${location}`);
    const evidence = Array.isArray(entry.evidence) && entry.evidence.length > 0 && entry.evidence.every(nonempty);
    if (!evidence) diagnose("missing-evidence", entry.document, entry.evidence ?? null, "正本とproject/tool観測を辿れる非空locator集合");
    if (entry.disposition === "unresolved") {
      diagnose("unresolved-applicability", entry.document, entry.reason ?? null, "適用判定と照合完了");
    } else if (entry.disposition === "not-applicable") {
      if (!nonempty(entry.reason)) diagnose("missing-applicability-reason", entry.document, entry.reason ?? null, "非適用の根拠");
      if (report.violations.some((violation) => violation.rule.split("#", 1)[0] === entry.document)) diagnose("skipped-violation", entry.document, "not-applicable", "違反を指摘した規律の照合");
    } else {
      if (!Array.isArray(entry.checks) || entry.checks.length === 0) {
        diagnose("missing-check", entry.document, entry.checks ?? null, "実検査または意味レビューの観測");
        continue;
      }
      for (const [checkIndex, check] of entry.checks.entries()) {
        requireValue(check && ["machine", "review", "applicability"].includes(check.kind), `不正なcheck kind: ${location}.checks[${checkIndex}]`);
        requireValue(check.kind === "applicability" ? ["not-applicable", "not-run"].includes(check.status) && nonempty(check.rule) && nonempty(check.reason) : ["passed", "failed", "not-run"].includes(check.status), `不正なcheck: ${location}.checks[${checkIndex}]`);
        if (check.rule !== undefined) requireValue(nonempty(check.rule) && check.rule.split("#", 1)[0] === entry.document, `check.ruleは同じdocumentの規律を指す必要がある: ${location}.checks[${checkIndex}]`);
        if (!nonempty(check.evidence)) diagnose("missing-check-evidence", entry.document, check.evidence ?? null, "実測outputまたはレビュー判断のlocator");
        if (check.status === "not-run") diagnose("unexecuted-check", entry.document, check.kind, "今回の対象に対する実測");
        if (check.status === "failed" && !report.violations.some((violation) => nonempty(check.rule) ? violation.rule === check.rule : violation.rule.split("#", 1)[0] === entry.document)) diagnose("unreported-failure", check.rule ?? entry.document, check.evidence, "失敗した規律に対応するviolation");
      }
      const executed = entry.checks.some((check) => check.kind !== "applicability" && check.status !== "not-run");
      if (executed) checked += 1;
      else diagnose("missing-check", entry.document, entry.checks.map((check) => check.kind), "適用判断とは別の実検査または意味レビュー");
      for (const check of entry.checks) {
        if (check.kind === "applicability" && check.status === "not-applicable" && entry.checks.some((other) => other.rule === check.rule && other.kind !== "applicability")) diagnose("contradictory-applicability", check.rule, "非適用と実照合の併記", "非適用か実照合のどちらか一つ");
      }
      for (const assignment of inventory.requiredChecks[entry.document] ?? []) {
        const observations = entry.checks.filter((check) => check.rule === assignment.rule);
        const excluded = observations.some((check) => check.kind === "applicability" && check.status === "not-applicable");
        if (excluded) continue;
        for (const kind of assignment.kinds) {
          if (!observations.some((check) => check.kind === kind && check.status !== "not-run")) diagnose("missing-assigned-check", assignment.rule, observations.map((check) => check.kind), kind);
        }
      }
    }
  }
  for (const document of expected) {
    if (!seen.has(document)) diagnose("missing-document", document, null, "照合または根拠を伴う非適用判定");
  }
  if (checked === 0) diagnose("empty-assessment", "coverage.entries", 0, "実際に照合した文書が少なくとも一つある監査");
  const complete = diagnostics.length === 0;
  if (counts.newCount > 0) diagnose("new-violations", report.baseline.file, counts.newCount, 0);
  const status = !complete ? "INCOMPLETE" : counts.newCount > 0 ? "FAIL" : counts.baselineCount > 0 ? "WARN" : "PASS";
  return { status, coverageComplete: complete, standardDigest: inventory.standardDigest, projectDigest: digest, expectedDocuments: expected.size, ...counts, diagnostics };
}

function main() {
  const [command, ...args] = process.argv.slice(2);
  requireValue(command === "inventory" || command === "check", "usage: check-coverage.mjs inventory|check --standard-root ROOT --project-root PROJECT [--report REPORT]");
  const options = {};
  for (let index = 0; index < args.length; index += 2) {
    const flag = args[index];
    requireValue(["--standard-root", "--project-root", "--report"].includes(flag) && nonempty(args[index + 1]) && !Object.hasOwn(options, flag), `不正または重複したoption: ${flag}`);
    options[flag] = args[index + 1];
  }
  requireValue(options["--standard-root"] && options["--project-root"], "--standard-rootと--project-rootが必要");
  const standardRoot = fs.realpathSync(options["--standard-root"]);
  const projectRoot = fs.realpathSync(options["--project-root"]);
  const inventory = standardInventory(standardRoot);
  const digest = projectDigest(projectRoot);
  if (command === "inventory") return { status: "INVENTORY", ...inventory, projectDigest: digest };
  requireValue(options["--report"], "checkには--reportが必要");
  const reportPath = fs.realpathSync(options["--report"]);
  const gitRoot = fs.realpathSync(execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd: projectRoot, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim());
  requireValue(!within(gitRoot, reportPath), "監査報告は対象projectのGit repositoryの外に置く");
  return checkReport(readJson(reportPath), inventory, digest, projectRoot);
}

try {
  const result = main();
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = ["INCOMPLETE", "FAIL"].includes(result.status) ? 1 : 0;
} catch (error) {
  console.log(JSON.stringify({ status: "INVALID", diagnostics: [{ rule: "invalid-input", location: "input", actual: error.message, expected: "読取可能な現在正本、Git source、完全な監査報告" }] }, null, 2));
  process.exitCode = 2;
}
