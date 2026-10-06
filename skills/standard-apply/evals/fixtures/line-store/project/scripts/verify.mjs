import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { performance } from "node:perf_hooks";
import { fileURLToPath } from "node:url";
import { run } from "./process.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const [stage, ...extra] = process.argv.slice(2);
const budgets = { fast: 10_000, local: 120_000, push: 900_000 };
if (!Object.hasOwn(budgets, stage)) throw new Error(`Unknown verification stage: ${stage}`);
if (stage !== "push" && extra.length !== 0) throw new Error("Unexpected verification arguments");
const started = performance.now();
const steps = [];
const remaining = () => budgets[stage] - (performance.now() - started);

async function tool(name, entry, args, limit = remaining()) {
  if (limit <= 0) throw new Error(`${stage} exhausted its time budget`);
  const result = await run(process.execPath, [join(root, "node_modules", entry), ...args], {
    cwd: root,
    timeoutMs: Math.min(remaining(), limit),
  });
  steps.push({ name, elapsed_ms: result.elapsedMs });
}

async function fast() {
  const fastStarted = performance.now();
  const fastRemaining = () => budgets.fast - (performance.now() - fastStarted);
  await tool("types", "typescript/bin/tsc", ["--noEmit", "--project", "tsconfig.json"], fastRemaining());
  await tool("lint", "oxlint/bin/oxlint", ["--type-aware", "--deny-warnings", "src", "tests", "vitest.config.ts"], fastRemaining());
  await tool("format", "oxfmt/bin/oxfmt", ["--check", "src", "tests", "vitest.config.ts"], fastRemaining());
  if (fastRemaining() < 0) throw new Error("T0 exceeded its 10-second budget");
}

async function tests() {
  await tool("small-and-properties", "vitest/vitest.mjs", [
    "run", "--coverage", "--reporter=default", "--reporter=json", "--outputFile=reports/tests.json",
  ], budgets.local - (performance.now() - started));
  const report = JSON.parse(await readFile(join(root, "reports/tests.json"), "utf8"));
  if (report.success !== true || !(report.numTotalTests > 0)) {
    throw new Error("Small test execution must succeed and contain at least one test");
  }
}

await mkdir(join(root, "reports"), { recursive: true });
let failure;
try {
  await fast();
  if (stage !== "fast") {
    const localStarted = performance.now();
    await tests();
    const localElapsed = performance.now() - started;
    if (localElapsed > budgets.local) throw new Error("T1 exceeded its 2-minute budget");
    steps.push({ name: "test-phase", elapsed_ms: performance.now() - localStarted });
  }
  if (stage === "push") {
    const result = await run(process.execPath, [join(root, "scripts/mutation.mjs"), ...extra], {
      cwd: root,
      timeoutMs: remaining(),
    });
    steps.push({ name: "changed-line-mutation", elapsed_ms: result.elapsedMs });
  }
  if (remaining() < 0) throw new Error(`${stage} exceeded its time budget`);
} catch (error) {
  failure = error;
} finally {
  const report = {
    stage,
    budget_ms: budgets[stage],
    elapsed_ms: performance.now() - started,
    success: failure === undefined,
    steps,
    ...(failure ? { error: String(failure) } : {}),
  };
  await writeFile(join(root, `reports/verification-${stage}.json`), `${JSON.stringify(report, null, 2)}\n`);
}
if (failure) {
  process.stderr.write(`${failure.stack ?? failure}\n`);
  process.exitCode = 1;
}
