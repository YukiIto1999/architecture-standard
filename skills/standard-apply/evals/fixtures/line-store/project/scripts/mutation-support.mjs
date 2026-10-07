import { lstat } from "node:fs/promises";
import { extname, join } from "node:path";
import { run } from "./process.mjs";

const extensions = new Set([".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs"]);
const generatedRoots = new Set(["node_modules", "reports", "coverage", ".stryker-tmp"]);

/**
 * 固定fixtureの変更入力に対するproduction生成対象の選択
 * @param root - 固定testを持つLineStore projectのGit作業directory
 * @param base - 変更入力を比較するGit commit参照
 * @returns 未変更consumerを含む全production sourceの選択記録
 * @throws {@link Error} Git比較の不成立
 * @throws {@link Error} ignoredな入力による比較範囲の欠落
 * @throws {@link Error} 対象sourceの欠落
 * @throws {@link Error} 固定fixtureで扱えないsource path
 */
export async function selectMutationScope(root, base) {
  const git = async (parameters) => (await run("git", parameters, {
    cwd: root,
    timeoutMs: 10_000,
    capture: true,
  })).stdout;
  const baseline = (await git(["rev-parse", "--verify", "--end-of-options", `${base}^{commit}`])).trim();
  if (!/^[0-9a-f]{40,64}$/.test(baseline)) throw new Error("Git baseline did not resolve to a commit");
  const tracked = (await git(["diff", "--relative", "--no-ext-diff", "--no-textconv", "--name-only", "--no-renames", "-z", baseline, "--", "."])).split("\0").filter(Boolean);
  const untracked = (await git(["ls-files", "--others", "--exclude-standard", "-z", "--", "."])).split("\0").filter(Boolean);
  const ignored = (await git(["ls-files", "--others", "--ignored", "--exclude-standard", "--directory", "-z", "--", "."])).split("\0")
    .filter((file) => file && !generatedRoots.has(file.split("/")[0]));
  if (ignored.length > 0) throw new Error(`Ignored project input has no reliable Git comparison: ${ignored.join(", ")}`);
  const changedInputs = [...new Set([...tracked, ...untracked])].sort();
  const current = (await git(["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "src/", "tests/"])).split("\0").filter(Boolean);
  const productionFiles = [];
  const testFiles = [];
  for (const file of [...new Set(current)].sort()) {
    const production = file.startsWith("src/") && extensions.has(extname(file));
    const test = /^tests\/.*\.test\.ts$/.test(file);
    if (!production && !test) continue;
    if (/[:\r\n\\*?[\]{}!]/.test(file)) throw new Error(`Unsupported source path: ${file}`);
    let entry;
    try {
      entry = await lstat(join(root, file));
    } catch (error) {
      if (error.code === "ENOENT") continue;
      throw error;
    }
    if (!entry.isFile()) throw new Error(`Source is not a file: ${file}`);
    if (production) productionFiles.push(file);
    if (test) testFiles.push(file);
  }
  if (changedInputs.length > 0 && productionFiles.length === 0) {
    throw new Error("Changed project inputs have no production mutation targets");
  }
  const changedProduction = changedInputs.filter((file) => file.startsWith("src/") && extensions.has(extname(file)));
  const mutate = changedInputs.length === 0 ? [] : productionFiles;
  return {
    baseline, changedInputs, changedProduction,
    affectedProduction: mutate.filter((file) => !changedProduction.includes(file)),
    productionFiles, testFiles, mutate,
    selection: changedInputs.length === 0 ? "no-changed-inputs" : "fixture-production-closure",
  };
}

/**
 * 基線のtest実行に照合した実行可能mutantの完了判定
 * @param report - 完了したStryker実行の機械可読なmutation report
 * @returns 実行不能の除外を検出から分けた未検出0件の判定
 * @throws {@link Error} mutant結果の欠落
 * @throws {@link Error} 基線のtest実行証拠の欠落
 */
export function mutationVerdict(report) {
  if (!report || typeof report.files !== "object" || report.files === null) {
    throw new Error("Mutation report has no file results");
  }
  const mutants = Object.values(report.files).flatMap((file) => {
    if (!Array.isArray(file.mutants)) throw new Error("Mutation report has no mutant list");
    return file.mutants;
  });
  const tests = Object.values(report.testFiles ?? {}).flatMap((file) => file.tests ?? []);
  const testIds = new Set(tests.map((test) => test.id).filter((id) => typeof id === "string"));
  if (testIds.size === 0) throw new Error("Mutation dry run executed no identifiable tests");
  let excludedInvalid = 0;
  let detected = 0;
  let totalUndetected = 0;
  let incomplete = 0;
  let zeroTestMutants = 0;
  const failedMutants = [];
  for (const mutant of mutants) {
    if (mutant.status === "CompileError") {
      excludedInvalid++;
      continue;
    }
    const completed = Number.isInteger(mutant.testsCompleted) && mutant.testsCompleted > 0;
    const knownKill = Array.isArray(mutant.killedBy) && mutant.killedBy.length > 0
      && mutant.killedBy.every((id) => testIds.has(id));
    const knownReferences = [mutant.killedBy, mutant.coveredBy].every((ids) =>
      ids === undefined || (Array.isArray(ids) && ids.every((id) => testIds.has(id))));
    const executed = knownReferences && (completed || knownKill)
      && (mutant.testsCompleted === undefined || completed);
    if (mutant.status === "NoCoverage" && !(mutant.coveredBy?.length > 0)
      && !(mutant.killedBy?.length > 0) && !completed) {
      totalUndetected++;
    } else if (mutant.status === "Killed" && executed) {
      detected++;
      continue;
    } else if (mutant.status === "Survived" && executed) {
      totalUndetected++;
    } else {
      incomplete++;
      if (!executed) zeroTestMutants++;
    }
    failedMutants.push(mutant);
  }
  const eligible = mutants.length - excludedInvalid;
  return {
    generated: mutants.length, eligible, excludedInvalid, detected,
    totalUndetected, incomplete, zeroTestMutants,
    success: eligible > 0 && totalUndetected === 0 && incomplete === 0 && zeroTestMutants === 0,
    failedMutants,
  };
}
