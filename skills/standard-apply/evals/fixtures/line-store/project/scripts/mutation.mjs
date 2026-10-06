import { mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { changedRanges, mutationVerdict } from "./mutation-support.mjs";
import { run } from "./process.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
if (args.length !== 0 && (args.length !== 2 || args[0] !== "--base" || !args[1])) {
  throw new Error("Usage: mutation.mjs [--base <git-ref>]");
}
const base = args[1] ?? "HEAD";
const git = async (parameters) => (await run("git", parameters, {
  cwd: root,
  timeoutMs: 10_000,
  capture: true,
})).stdout;
const extensions = new Set([".ts", ".tsx", ".mts", ".cts", ".js", ".mjs", ".cjs"]);

async function collectChanges() {
  const baseline = (await git(["rev-parse", "--verify", "--end-of-options", `${base}^{commit}`])).trim();
  if (!/^[0-9a-f]{40,64}$/.test(baseline)) throw new Error("Git baseline did not resolve to a commit");
  const tracked = (await git(["diff", "--relative", "--name-only", "--diff-filter=ACMR", "--no-renames", "-z", baseline, "--", "src/"])).split("\0").filter(Boolean);
  const untracked = (await git(["ls-files", "--others", "--exclude-standard", "-z", "--", "src/"])).split("\0").filter(Boolean);
  const ignored = (await git(["ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--", "src/"])).split("\0").filter((file) => extensions.has(extname(file)));
  if (ignored.length > 0) throw new Error(`Ignored production source has no reliable Git diff: ${ignored.join(", ")}`);
  const changes = [];
  for (const file of [...new Set([...tracked, ...untracked])].sort()) {
    if (!file.startsWith("src/") || file.includes(":") || file.includes("\n") || file.includes("\\")) {
      throw new Error(`Unsupported production source path: ${file}`);
    }
    if (!extensions.has(extname(file))) continue;
    if (!(await stat(join(root, file))).isFile()) throw new Error(`Source is not a file: ${file}`);
    let ranges;
    if (untracked.includes(file)) {
      const source = await readFile(join(root, file), "utf8");
      const lines = source === "" ? 0 : source.split("\n").length - (source.endsWith("\n") ? 1 : 0);
      ranges = lines === 0 ? [] : [{ start: 1, end: lines }];
    } else {
      const diff = await git(["diff", "--relative", "--no-ext-diff", "--no-textconv", "--no-renames", "--unified=0", baseline, "--", file]);
      ranges = changedRanges(diff);
    }
    for (const range of ranges) changes.push({ file, ...range });
  }
  return { baseline, changes };
}

await mkdir(join(root, "reports/mutation"), { recursive: true });
try {
  const { baseline, changes } = await collectChanges();
  const mutate = changes.map(({ file, start, end }) => `${file}:${start}-${end}`);
  await writeFile(join(root, "reports/mutation/changed-lines.json"), `${JSON.stringify({ baseline, changes, mutate }, null, 2)}\n`);
  if (mutate.length === 0) {
    await writeFile(join(root, "reports/mutation/gate.json"), `${JSON.stringify({
      success: true, diffRetrieved: true, baseline, changedRanges: 0,
      mutationExecuted: false, reason: "no-changed-production-lines",
    }, null, 2)}\n`);
    process.stdout.write("No changed production lines; mutation was not executed.\n");
  } else {
    const { Stryker } = await import("@stryker-mutator/core");
    await new Stryker({
      mutate,
      testRunner: "vitest",
      plugins: ["@stryker-mutator/vitest-runner"],
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
      ...verdict, diffRetrieved: true, baseline, changedRanges: changes.length, mutationExecuted: true,
    }, null, 2)}\n`);
    if (!verdict.success) throw new Error(`Mutation gate failed: ${JSON.stringify(verdict)}`);
  }
} catch (error) {
  await writeFile(join(root, "reports/mutation/failure.json"), `${JSON.stringify({ success: false, error: String(error) }, null, 2)}\n`);
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
}
