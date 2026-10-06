import assert from "node:assert/strict";
import { test } from "node:test";
import { changedRanges, mutationVerdict } from "../project/scripts/mutation-support.mjs";

const report = (mutants, tests = [{ id: "t1" }]) => ({
  files: { "src/line-store.ts": { mutants } },
  testFiles: { "tests/render-selected.test.ts": { tests } },
});

test("changed ranges use added-side hunk positions including additions and deletions", () => {
  assert.deepEqual(changedRanges("@@ -2,3 +2,4 @@\n@@ -8,0 +10 @@\n@@ -20,2 +23,0 @@\n"), [
    { start: 2, end: 5 },
    { start: 10, end: 10 },
  ]);
  assert.deepEqual(changedRanges(""), []);
  assert.throws(() => changedRanges("@@ malformed @@"));
  assert.throws(() => changedRanges("Binary files a/src/line-store.ts and b/src/line-store.ts differ"));
});

test("undetected zero is the gate even when the mutation score is high", () => {
  const mutants = Array.from({ length: 100 }, (_, id) => ({ id, status: "Killed", testsCompleted: 1 }));
  mutants.push({ id: 100, status: "Survived", testsCompleted: 1 });
  const verdict = mutationVerdict(report(mutants));
  assert.equal(verdict.success, false);
  assert.equal(verdict.totalUndetected, 1);
  assert.equal(mutationVerdict(report([{ status: "NoCoverage" }])).success, false);
});

test("zero selected tests and incomplete mutant outcomes fail", () => {
  assert.throws(() => mutationVerdict(report([], [])));
  for (const mutant of [
    { status: "Killed", testsCompleted: 0, killedBy: ["t1"] },
    { status: "Timeout", coveredBy: [] },
    { status: "CompileError" },
    { status: "RuntimeError" },
    { status: "Ignored" },
    { status: "Pending" },
  ]) {
    assert.equal(mutationVerdict(report([mutant])).success, false);
  }
});

test("confirmed detection with test execution passes without a score threshold", () => {
  const verdict = mutationVerdict(report([
    { status: "Killed", testsCompleted: 1, killedBy: ["t1"] },
    { status: "Timeout", coveredBy: ["t1"] },
  ]));
  assert.equal(verdict.success, true);
  assert.equal(verdict.totalUndetected, 0);
  assert.equal(verdict.generated, 2);
});
