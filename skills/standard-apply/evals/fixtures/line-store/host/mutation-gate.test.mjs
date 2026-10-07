import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { cp, mkdir, mkdtemp, readFile, rename, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { selectMutationScope, mutationVerdict } from "../project/scripts/mutation-support.mjs";

const report = (mutants, tests = [{ id: "t1" }]) => ({
  files: { "src/line-store.ts": { mutants } },
  testFiles: { "tests/render-selected.test.ts": { tests } },
});

const project = join(dirname(fileURLToPath(import.meta.url)), "../project");
const productionFiles = ["src/line-store.ts", "src/render-selected.ts"];
const testFiles = ["tests/render-selected.property.test.ts", "tests/render-selected.test.ts"];

/**
 * 変更入力の選択を検査する隔離済みGit基線の作成
 * @param t - 作成したdirectoryの破棄を所有するtest
 * @returns 固定fixtureを保存したrepositoryのroot
 */
async function fixture(t) {
  const root = await mkdtemp(join(tmpdir(), "line-store-mutation-scope-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await cp(project, root, {
    recursive: true,
    filter: (file) => !["node_modules", "reports", "coverage", ".stryker-tmp"].includes(relative(project, file).split("/")[0]),
  });
  execFileSync("git", ["init", "--quiet"], { cwd: root });
  execFileSync("git", ["config", "user.name", "Skill Eval"], { cwd: root });
  execFileSync("git", ["config", "user.email", "skill-eval@example.invalid"], { cwd: root });
  execFileSync("git", ["config", "commit.gpgSign", "false"], { cwd: root });
  execFileSync("git", ["add", "."], { cwd: root });
  execFileSync("git", ["commit", "--quiet", "-m", "test: mutation検証入力の固定"], { cwd: root });
  return root;
}

test("an unchanged fixture has no changed or affected mutation scope", async (t) => {
  const root = await fixture(t);
  const scope = await selectMutationScope(root, "HEAD");
  assert.deepEqual(scope.changedInputs, []);
  assert.deepEqual(scope.productionFiles, productionFiles);
  assert.deepEqual(scope.testFiles, testFiles);
  assert.deepEqual(scope.mutate, []);
});

test("storage changes include the unchanged public consumer and the full test set", async (t) => {
  const root = await fixture(t);
  const consumer = await readFile(join(root, "src/render-selected.ts"), "utf8");
  const store = join(root, "src/line-store.ts");
  await writeFile(store, (await readFile(store, "utf8")).replace("this.lines.push(line)", "this.lines.unshift(line)"));
  const scope = await selectMutationScope(root, "HEAD");
  assert.deepEqual(scope.changedInputs, ["src/line-store.ts"]);
  assert.deepEqual(scope.mutate, productionFiles);
  assert.deepEqual(scope.testFiles, testFiles);
  assert.equal(await readFile(join(root, "src/render-selected.ts"), "utf8"), consumer);
});

test("non-production inputs select the same full production closure", async (t) => {
  for (const file of [
    "tests/render-selected.test.ts", "tests/expect-results.ts", "vitest.config.ts",
    "tsconfig.json", "package.json", "package-lock.json", "README.md", "scripts/verify.mjs",
  ]) {
    await t.test(file, async (t) => {
      const root = await fixture(t);
      await writeFile(join(root, file), `${await readFile(join(root, file), "utf8")}\n`);
      const scope = await selectMutationScope(root, "HEAD");
      assert.deepEqual(scope.changedInputs, [file]);
      assert.deepEqual(scope.mutate, productionFiles);
      assert.deepEqual(scope.testFiles, testFiles);
    });
  }
  await t.test("untracked generator input with uncertain impact", async (t) => {
    const root = await fixture(t);
    await mkdir(join(root, "templates"));
    await writeFile(join(root, "templates/lines.txt"), "alpha\n");
    const scope = await selectMutationScope(root, "HEAD");
    assert.deepEqual(scope.changedInputs, ["templates/lines.txt"]);
    assert.deepEqual(scope.mutate, productionFiles);
  });
});

test("deleted, renamed and untracked inputs do not disappear from impact selection", async (t) => {
  await t.test("source deletion", async (t) => {
    const root = await fixture(t);
    await rm(join(root, "src/line-store.ts"));
    const scope = await selectMutationScope(root, "HEAD");
    assert.deepEqual(scope.changedInputs, ["src/line-store.ts"]);
    assert.deepEqual(scope.mutate, ["src/render-selected.ts"]);
  });
  await t.test("test deletion", async (t) => {
    const root = await fixture(t);
    await rm(join(root, testFiles[0]));
    const scope = await selectMutationScope(root, "HEAD");
    assert.deepEqual(scope.changedInputs, [testFiles[0]]);
    assert.deepEqual(scope.mutate, productionFiles);
    assert.deepEqual(scope.testFiles, [testFiles[1]]);
  });
  await t.test("source rename", async (t) => {
    const root = await fixture(t);
    await rename(join(root, "src/line-store.ts"), join(root, "src/storage.ts"));
    const scope = await selectMutationScope(root, "HEAD");
    assert.deepEqual(scope.changedInputs, ["src/line-store.ts", "src/storage.ts"]);
    assert.deepEqual(scope.mutate, ["src/render-selected.ts", "src/storage.ts"]);
  });
  await t.test("untracked production source", async (t) => {
    const root = await fixture(t);
    await writeFile(join(root, "src/selection.ts"), "export const firstPosition = 0;\n");
    const scope = await selectMutationScope(root, "HEAD");
    assert.deepEqual(scope.changedInputs, ["src/selection.ts"]);
    assert.deepEqual(scope.mutate, [...productionFiles, "src/selection.ts"]);
  });
});

test("unreliable input comparisons and empty production closures fail closed", async (t) => {
  const root = await fixture(t);
  await assert.rejects(selectMutationScope(root, "missing-baseline"));
  await writeFile(join(root, ".gitignore"), `${await readFile(join(root, ".gitignore"), "utf8")}src/hidden.ts\n`);
  await writeFile(join(root, "src/hidden.ts"), "export const hidden = 1;\n");
  await assert.rejects(selectMutationScope(root, "HEAD"));
  await rm(join(root, "src/hidden.ts"));
  await rm(join(root, "src"), { recursive: true });
  await assert.rejects(selectMutationScope(root, "HEAD"));
});

test("deletion-only source hunks retain the remaining source and affected consumer", async (t) => {
  const root = await fixture(t);
  const store = join(root, "src/line-store.ts");
  await writeFile(store, (await readFile(store, "utf8")).replace("    this.lines.push(line);\n", ""));
  const scope = await selectMutationScope(root, "HEAD");
  assert.deepEqual(scope.changedInputs, ["src/line-store.ts"]);
  assert.deepEqual(scope.mutate, productionFiles);
  assert.deepEqual(scope.affectedProduction, ["src/render-selected.ts"]);
});

test("undetected zero is the gate even when the mutation score is high", () => {
  const mutants = Array.from({ length: 100 }, (_, id) => ({ id, status: "Killed", testsCompleted: 1 }));
  mutants.push({ id: 100, status: "Survived", testsCompleted: 1 });
  const verdict = mutationVerdict(report(mutants));
  assert.equal(verdict.success, false);
  assert.equal(verdict.totalUndetected, 1);
  assert.equal(mutationVerdict(report([{ status: "NoCoverage" }])).success, false);
});

test("completed coverage with no covering test is undetected rather than incomplete", () => {
  const verdict = mutationVerdict(report([{ status: "NoCoverage", coveredBy: [], testsCompleted: 0 }]));
  assert.equal(verdict.success, false);
  assert.equal(verdict.totalUndetected, 1);
  assert.equal(verdict.incomplete, 0);
  assert.equal(verdict.zeroTestMutants, 0);
  assert.equal(verdict.detected, 0);
});

test("zero discovery and zero baseline execution cannot approve mutation", () => {
  assert.throws(() => mutationVerdict(report([], [])));
  assert.equal(mutationVerdict(report([])).success, false);
});

test("runner failures and unexecuted selected tests are incomplete rather than detections", () => {
  for (const mutant of [
    { status: "Killed", testsCompleted: 0, killedBy: ["t1"] },
    { status: "Killed", killedBy: ["unknown-baseline-test"] },
    { status: "Survived", testsCompleted: 0, coveredBy: ["t1"] },
    { status: "NoCoverage", testsCompleted: 0, coveredBy: ["t1"] },
    { status: "RuntimeError" },
    { status: "Ignored" },
    { status: "Pending" },
  ]) {
    const verdict = mutationVerdict(report([mutant]));
    assert.equal(verdict.success, false);
    assert.equal(verdict.incomplete, 1);
    assert.equal(verdict.totalUndetected, 0);
    assert.equal(verdict.detected, 0);
  }
});

test("timeouts have no deadline-contract evidence even when coverage or execution is reported", () => {
  for (const mutant of [
    { status: "Timeout", coveredBy: [] },
    { status: "Timeout", coveredBy: ["t1"] },
    { status: "Timeout", coveredBy: ["t1"], testsCompleted: 1 },
  ]) {
    const verdict = mutationVerdict(report([mutant]));
    assert.equal(verdict.success, false);
    assert.equal(verdict.incomplete, 1);
    assert.equal(verdict.detected, 0);
    assert.equal(verdict.zeroTestMutants, mutant.testsCompleted ? 0 : 1);
  }
});

test("invalid mutations are excluded without being detected or marked incomplete", () => {
  const verdict = mutationVerdict(report([
    { status: "CompileError" },
    { status: "Killed", killedBy: ["t1"] },
  ]));
  assert.equal(verdict.success, true);
  assert.equal(verdict.generated, 2);
  assert.equal(verdict.eligible, 1);
  assert.equal(verdict.excludedInvalid, 1);
  assert.equal(verdict.detected, 1);
  assert.equal(verdict.incomplete, 0);
  assert.equal(verdict.zeroTestMutants, 0);
  assert.equal(mutationVerdict(report([{ status: "CompileError" }])).success, false);
});

test("confirmed detection with test execution passes without a score threshold", () => {
  const verdict = mutationVerdict(report([
    { status: "Killed", testsCompleted: 1, killedBy: ["t1"] },
    { status: "Killed", killedBy: ["t1"] },
  ]));
  assert.equal(verdict.success, true);
  assert.equal(verdict.totalUndetected, 0);
  assert.equal(verdict.generated, 2);
});
