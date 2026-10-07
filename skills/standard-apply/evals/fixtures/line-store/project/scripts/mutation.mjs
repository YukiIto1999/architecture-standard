import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { selectMutationScope, mutationVerdict } from "./mutation-support.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
if (args.length !== 0 && (args.length !== 2 || args[0] !== "--base" || !args[1])) {
  throw new Error("Usage: mutation.mjs [--base <git-ref>]");
}
const base = args[1] ?? "HEAD";

await mkdir(join(root, "reports/mutation"), { recursive: true });
await Promise.all(["scope.json", "gate.json", "mutation.json", "failure.json"]
  .map((file) => rm(join(root, "reports/mutation", file), { force: true })));
try {
  const scope = await selectMutationScope(root, base);
  const { baseline, mutate } = scope;
  await writeFile(join(root, "reports/mutation/scope.json"), `${JSON.stringify(scope, null, 2)}\n`);
  if (mutate.length === 0) {
    await writeFile(join(root, "reports/mutation/gate.json"), `${JSON.stringify({
      success: true, diffRetrieved: true, baseline, changedInputs: 0,
      selectedProductionFiles: 0, mutationExecuted: false, reason: scope.selection,
    }, null, 2)}\n`);
    process.stdout.write("No changed project inputs; mutation was not executed.\n");
  } else {
    const { Stryker } = await import("@stryker-mutator/core");
    await new Stryker({
      mutate,
      testRunner: "vitest",
      plugins: ["@stryker-mutator/vitest-runner", "@stryker-mutator/typescript-checker"],
      checkers: ["typescript"],
      tsconfigFile: "tsconfig.json",
      typescriptChecker: { prioritizePerformanceOverAccuracy: false },
      vitest: { configFile: "vitest.config.ts", related: false },
      coverageAnalysis: "perTest",
      reporters: ["clear-text", "json"],
      jsonReporter: { fileName: "reports/mutation/mutation.json" },
      concurrency: 1,
      timeoutMS: 5_000,
      timeoutFactor: 2,
      incremental: false,
    }).runMutationTest();
    const report = JSON.parse(await readFile(join(root, "reports/mutation/mutation.json"), "utf8"));
    const verdict = mutationVerdict(report);
    await writeFile(join(root, "reports/mutation/gate.json"), `${JSON.stringify({
      ...verdict, diffRetrieved: true, baseline, changedInputs: scope.changedInputs.length,
      selectedProductionFiles: mutate.length, mutationExecuted: true,
    }, null, 2)}\n`);
    if (!verdict.success) throw new Error(`Mutation gate failed: ${JSON.stringify(verdict)}`);
  }
} catch (error) {
  await writeFile(join(root, "reports/mutation/failure.json"), `${JSON.stringify({ success: false, error: String(error) }, null, 2)}\n`);
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
}
