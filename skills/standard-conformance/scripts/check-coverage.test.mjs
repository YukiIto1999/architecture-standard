import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync, spawnSync } from "node:child_process";
import test from "node:test";

const script = fileURLToPath(new URL("./check-coverage.mjs", import.meta.url));
const areas = ["principles", "concerns", "structure", "tools", "languages", "process"];

function fixture(context) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "conformance-coverage-test-"));
  context.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const standard = path.join(root, "standard");
  const project = path.join(root, "project");
  fs.mkdirSync(standard);
  fs.mkdirSync(project);
  fs.writeFileSync(path.join(standard, "README.md"), "# 標準\n");
  for (const area of areas) {
    fs.mkdirSync(path.join(standard, area));
    fs.writeFileSync(path.join(standard, area, "README.md"), `# ${area}\n`);
  }
  execFileSync("git", ["init", "--quiet", project]);
  fs.writeFileSync(path.join(project, "core.mjs"), "export const answer = 42;\n");
  const reportPath = path.join(root, "report.json");
  function run(command, report, projectRoot = project) {
    if (report !== undefined) fs.writeFileSync(reportPath, JSON.stringify(report));
    const args = [script, command, "--standard-root", standard, "--project-root", projectRoot];
    if (command === "check") args.push("--report", reportPath);
    const result = spawnSync(process.execPath, args, { encoding: "utf8" });
    assert.equal(result.error, undefined);
    assert.notEqual(result.stdout, "", result.stderr);
    return { code: result.status, value: JSON.parse(result.stdout) };
  }
  function report() {
    const { code, value } = run("inventory");
    assert.equal(code, 0);
    return {
      violations: [],
      baseline: { file: "docs/conformance-baseline.json", newCount: 0 },
      coverage: {
        standardDigest: value.standardDigest,
        projectDigest: value.projectDigest,
        entries: value.documents.map((document) => ({
          document,
          disposition: "checked",
          evidence: [`${document}:1`, "project/core.mjs:1"],
          checks: [{ kind: "review", status: "passed", evidence: "fixture-review:decision" }],
        })),
      },
    };
  }
  return { root, standard, project, reportPath, run, report };
}

function rules(result) {
  return result.value.diagnostics.map((diagnostic) => diagnostic.rule);
}

const violation = {
  rule: "principles/README.md#規律",
  file: "core.mjs",
  line: 1,
  evidence: "fixture違反の観測",
  mechanizable: true,
};

test("違反0件でも文書の未照合を成功にしない", (context) => {
  const f = fixture(context);
  const report = f.report();
  report.coverage.entries = report.coverage.entries.filter((entry) => entry.document !== "concerns/README.md");
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.equal(result.value.status, "INCOMPLETE");
  assert.deepEqual(result.value.diagnostics.filter((value) => value.rule === "missing-document").map((value) => value.location), ["concerns/README.md"]);
});

test("正本の追加は手書き台帳を更新しなくても期待集合へ入る", (context) => {
  const f = fixture(context);
  const report = f.report();
  fs.writeFileSync(path.join(f.standard, "principles", "added.md"), "## 追加した規律\n\n### 要求\n追加した対象を照合する。\n");
  report.coverage.standardDigest = f.run("inventory").value.standardDigest;
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.ok(result.value.diagnostics.some((value) => value.rule === "missing-document" && value.location === "principles/added.md"));
});

test("未確定、未実行、根拠欠落、全件非適用を区別して止める", (context) => {
  const f = fixture(context);
  for (const [disposition, status, evidence, expected] of [
    ["unresolved", "passed", ["source:1"], "unresolved-applicability"],
    ["checked", "not-run", ["source:1"], "unexecuted-check"],
    ["checked", "passed", [], "missing-evidence"],
  ]) {
    const report = f.report();
    Object.assign(report.coverage.entries[0], { disposition, evidence });
    report.coverage.entries[0].checks[0].status = status;
    const result = f.run("check", report);
    assert.equal(result.code, 1);
    assert.ok(rules(result).includes(expected));
  }
  const report = f.report();
  report.coverage.entries = report.coverage.entries.map((entry) => ({ document: entry.document, disposition: "not-applicable", reason: "fixture非適用理由", evidence: ["fixture:decision"] }));
  assert.ok(rules(f.run("check", report)).includes("empty-assessment"));
});

test("同じsourceと正本の報告だけを受理し変更後は失効する", (context) => {
  const f = fixture(context);
  const report = f.report();
  const accepted = f.run("check", report);
  assert.equal(accepted.code, 0);
  assert.equal(accepted.value.status, "PASS");
  fs.writeFileSync(path.join(f.project, "core.mjs"), "export const answer = 43;\n");
  assert.ok(rules(f.run("check", report)).includes("stale-project"));
  const current = f.report();
  fs.appendFileSync(path.join(f.standard, "README.md"), "正本の変更。\n");
  assert.ok(rules(f.run("check", current)).includes("stale-standard"));
});

test("重複で欠落を埋めたり未知文書を照合済みにしたりできない", (context) => {
  const f = fixture(context);
  const report = f.report();
  report.coverage.entries[1] = structuredClone(report.coverage.entries[0]);
  report.coverage.entries.push({ ...report.coverage.entries[0], document: "unknown.md" });
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.ok(rules(result).includes("duplicate-document"));
  assert.ok(rules(result).includes("missing-document"));
  assert.ok(rules(result).includes("unknown-document"));
});

test("newCount自己申告で違反を隠せず実baselineだけでWARNにする", (context) => {
  const f = fixture(context);
  const report = f.report();
  report.violations.push(violation);
  const newViolation = f.run("check", report);
  assert.equal(newViolation.code, 1);
  assert.equal(newViolation.value.status, "FAIL");
  assert.equal(newViolation.value.newCount, 1);
  fs.mkdirSync(path.join(f.project, "docs"));
  fs.writeFileSync(path.join(f.project, "docs", "conformance-baseline.json"), JSON.stringify({ violations: [violation] }));
  const baselined = f.report();
  baselined.violations.push(violation);
  const knownViolation = f.run("check", baselined);
  assert.equal(knownViolation.code, 0);
  assert.equal(knownViolation.value.status, "WARN");
  assert.equal(knownViolation.value.baselineCount, 1);
  baselined.violations[0].evidence = "別の違反の観測";
  assert.equal(f.run("check", baselined).value.status, "FAIL");
});

test("失敗した検査を違反なしまたは非適用として消せない", (context) => {
  const f = fixture(context);
  const report = f.report();
  report.coverage.entries[0].checks[0].status = "failed";
  assert.ok(rules(f.run("check", report)).includes("unreported-failure"));
  const skipped = f.report();
  skipped.violations.push(violation);
  const entry = skipped.coverage.entries.find((value) => value.document === "principles/README.md");
  Object.assign(entry, { disposition: "not-applicable", reason: "fixture理由" });
  assert.ok(rules(f.run("check", skipped)).includes("skipped-violation"));
});

test("空領域や空文書を正本の成功した読取として扱わない", (context) => {
  const f = fixture(context);
  fs.writeFileSync(path.join(f.standard, "tools", "README.md"), "\n");
  assert.equal(f.run("inventory").code, 2);
  fs.unlinkSync(path.join(f.standard, "tools", "README.md"));
  assert.equal(f.run("inventory").code, 2);
});

test("nested projectでも同じcheckoutのconfig変更を観測する", (context) => {
  const f = fixture(context);
  const nested = path.join(f.project, "target-project");
  fs.mkdirSync(nested);
  fs.writeFileSync(path.join(nested, "core.mjs"), "export const answer = 42;\n");
  const report = f.report();
  report.coverage.projectDigest = f.run("inventory", undefined, nested).value.projectDigest;
  assert.equal(f.run("check", report, nested).code, 0);
  fs.writeFileSync(path.join(f.project, "build-config.json"), "{}\n");
  assert.ok(rules(f.run("check", report, nested)).includes("stale-project"));
});

test("Gitignoreされたbaselineの変更も監査を失効させる", (context) => {
  const f = fixture(context);
  fs.mkdirSync(path.join(f.project, "docs"));
  fs.writeFileSync(path.join(f.project, ".gitignore"), "docs/conformance-baseline.json\n");
  fs.writeFileSync(path.join(f.project, "docs", "conformance-baseline.json"), JSON.stringify({ violations: [] }));
  const report = f.report();
  fs.writeFileSync(path.join(f.project, "docs", "conformance-baseline.json"), JSON.stringify({ violations: [violation] }));
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.ok(rules(result).includes("stale-project"));
});

test("同じcheckoutの別projectへ監査を転用できない", (context) => {
  const f = fixture(context);
  const nested = path.join(f.project, "other-project");
  fs.mkdirSync(nested);
  fs.writeFileSync(path.join(nested, "core.mjs"), "export const answer = 42;\n");
  const report = f.report();
  const result = f.run("check", report, nested);
  assert.equal(result.code, 1);
  assert.ok(rules(result).includes("stale-project"));
});

test("基線symlinkの参照先がignoreされても内容変更を見逃さない", (context) => {
  const f = fixture(context);
  fs.mkdirSync(path.join(f.project, "docs"));
  fs.writeFileSync(path.join(f.project, ".gitignore"), "docs/private-baseline.json\n");
  const actual = path.join(f.project, "docs", "private-baseline.json");
  fs.writeFileSync(actual, JSON.stringify({ violations: [] }));
  fs.symlinkSync("private-baseline.json", path.join(f.project, "docs", "conformance-baseline.json"));
  const report = f.report();
  fs.writeFileSync(actual, JSON.stringify({ violations: [violation] }));
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.ok(rules(result).includes("stale-project"));
});

test("正本が機械へ割り当てた規律をレビューだけで完了にできない", (context) => {
  const f = fixture(context);
  const concept = path.join(f.standard, "principles", "modeling");
  fs.mkdirSync(concept);
  fs.writeFileSync(path.join(concept, "README.md"), "# modeling\n\n## 規律\n\n- [状態](./states.md) — 機械(型検査)\n");
  fs.writeFileSync(path.join(concept, "states.md"), "## 不正な状態を構築不能にする\n\n### 要求\n不正な状態を型で禁止する。\n");
  const report = f.report();
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.ok(rules(result).includes("missing-assigned-check"));
  const entry = report.coverage.entries.find((value) => value.document === "principles/modeling/states.md");
  entry.checks = [{ rule: "principles/modeling/states.md#不正な状態を構築不能にする", kind: "machine", status: "passed", evidence: "fixture-typecheck:exit0" }];
  assert.equal(f.run("check", report).code, 0);
});

test("言語の対応表から規律ごとの機械と意味レビューを分離する", (context) => {
  const f = fixture(context);
  const language = path.join(f.standard, "languages", "typescript");
  fs.mkdirSync(language);
  fs.writeFileSync(path.join(language, "formation.md"), "## 状態\n\n### 要求\n状態を型で表す。\n\n## 不変\n\n### 要求\nreadonlyを使う。\n");
  fs.writeFileSync(path.join(language, "inspection.md"), "# inspection\n\n## 規則と検証機構の対応\n\n| ファイル | 規律 | 検証手段 |\n|---|---|---|\n| formation | 状態 | 型(判別子)+レビュー(型で表した意味) |\n| formation | 不変 | 型(readonly) |\n");
  const report = f.report();
  const entry = report.coverage.entries.find((value) => value.document === "languages/typescript/formation.md");
  entry.checks = [
    { rule: "languages/typescript/formation.md#状態", kind: "machine", status: "passed", evidence: "fixture-typecheck:exit0" },
    { rule: "languages/typescript/formation.md#不変", kind: "machine", status: "passed", evidence: "fixture-typecheck:exit0" },
  ];
  const omitted = f.run("check", report);
  assert.equal(omitted.code, 1);
  assert.ok(omitted.value.diagnostics.some((value) => value.rule === "missing-assigned-check" && value.location === "languages/typescript/formation.md#状態"));
  entry.checks.push({ rule: "languages/typescript/formation.md#状態", kind: "review", status: "passed", evidence: "fixture-review:meaning" });
  assert.equal(f.run("check", report).code, 0);
  entry.checks = entry.checks.filter((value) => value.rule !== "languages/typescript/formation.md#不変");
  entry.checks.push({ rule: "languages/typescript/formation.md#不変", kind: "applicability", status: "not-applicable", reason: "fixtureの適用条件と対象が異なる", evidence: "fixture:applicability-decision" });
  assert.equal(f.run("check", report).code, 0);
});

test("割当のない文書でも適用判断だけを実照合にできない", (context) => {
  const f = fixture(context);
  const report = f.report();
  const entry = report.coverage.entries.find((value) => value.document === "README.md");
  entry.checks = [{ rule: "README.md#scope", kind: "applicability", status: "not-applicable", reason: "fixtureの条件は適用しない", evidence: "fixture:condition" }];
  const result = f.run("check", report);
  assert.equal(result.code, 1);
  assert.ok(rules(result).includes("missing-check"));
  entry.checks.push({ rule: "README.md#scope", kind: "review", status: "passed", evidence: "fixture:review" });
  const contradiction = f.run("check", report);
  assert.equal(contradiction.code, 1);
  assert.ok(rules(contradiction).includes("contradictory-applicability"));
});

test("削除済み正本の基線は履歴として比較し解消件数を報告する", (context) => {
  const f = fixture(context);
  const retired = { ...violation, rule: "tools/retired.md#旧規律" };
  fs.mkdirSync(path.join(f.project, "docs"));
  fs.writeFileSync(path.join(f.project, "docs", "conformance-baseline.json"), JSON.stringify({ violations: [retired] }));
  const report = f.report();
  const result = f.run("check", report);
  assert.equal(result.code, 0);
  assert.equal(result.value.resolvedCount, 1);
  assert.equal(result.value.newCount, 0);
  report.violations.push(retired);
  assert.equal(f.run("check", report).code, 2);
});

test("同じ文書の基線違反で別規律の検査失敗を隠せない", (context) => {
  const f = fixture(context);
  fs.writeFileSync(path.join(f.standard, "principles", "README.md"), "# principles\n\n## 旧規律\n\n## 新規律\n");
  const previous = { ...violation, rule: "principles/README.md#旧規律" };
  fs.mkdirSync(path.join(f.project, "docs"));
  fs.writeFileSync(path.join(f.project, "docs", "conformance-baseline.json"), JSON.stringify({ violations: [previous] }));
  const report = f.report();
  report.violations = [previous];
  const failedRule = "principles/README.md#新規律";
  report.coverage.entries.find((entry) => entry.document === "principles/README.md").checks = [
    { rule: failedRule, kind: "machine", status: "failed", evidence: "fixture-typecheck:new-rule-failure" },
  ];
  const hidden = f.run("check", report);
  assert.equal(hidden.code, 1);
  assert.ok(hidden.value.diagnostics.some((entry) => entry.rule === "unreported-failure" && entry.location === failedRule));
  report.violations.push({ ...previous, rule: failedRule, evidence: "fixture新規失敗の観測" });
  const reported = f.run("check", report);
  assert.equal(reported.code, 1);
  assert.equal(reported.value.status, "FAIL");
  assert.equal(reported.value.newCount, 1);
});

test("別文書の規律を現在文書の実照合として数えない", (context) => {
  const f = fixture(context);
  const report = f.report();
  report.coverage.entries.find((entry) => entry.document === "principles/README.md").checks = [
    { rule: "concerns/README.md#規律", kind: "review", status: "passed", evidence: "fixture-review:other-document" },
  ];
  const misplaced = f.run("check", report);
  assert.equal(misplaced.code, 2);
  assert.ok(misplaced.value.diagnostics[0].actual.includes("check.rule"));
});
