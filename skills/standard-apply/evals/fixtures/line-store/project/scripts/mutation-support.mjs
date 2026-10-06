export function changedRanges(diff) {
  if (/^(?:Binary files |GIT binary patch)/m.test(diff)) {
    throw new Error("Binary diff cannot identify changed production lines");
  }
  const ranges = [];
  for (const line of diff.split("\n")) {
    if (!line.startsWith("@@ ")) continue;
    const match = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/.exec(line);
    if (!match) throw new Error(`Unrecognized diff hunk: ${line}`);
    const start = Number(match[1]);
    const count = match[2] === undefined ? 1 : Number(match[2]);
    if (count > 0) ranges.push({ start, end: start + count - 1 });
  }
  return ranges;
}

export function mutationVerdict(report) {
  if (!report || typeof report.files !== "object" || report.files === null) {
    throw new Error("Mutation report has no file results");
  }
  const mutants = Object.values(report.files).flatMap((file) => {
    if (!Array.isArray(file.mutants)) throw new Error("Mutation report has no mutant list");
    return file.mutants;
  });
  const tests = Object.values(report.testFiles ?? {}).flatMap((file) => file.tests ?? []);
  if (tests.length === 0) throw new Error("Mutation dry run executed no tests");
  const undetected = mutants.filter((mutant) => ["Survived", "NoCoverage"].includes(mutant.status));
  const incomplete = mutants.filter((mutant) => !["Killed", "Timeout", "Survived", "NoCoverage"].includes(mutant.status));
  const zeroTests = mutants.filter((mutant) => {
    if (["NoCoverage", "CompileError", "Ignored", "RuntimeError", "Pending"].includes(mutant.status)) return true;
    if (mutant.testsCompleted === 0) return true;
    if (mutant.status === "Timeout") return !(mutant.coveredBy?.length > 0);
    return !(mutant.testsCompleted > 0 || mutant.killedBy?.length > 0);
  });
  return {
    generated: mutants.length,
    totalUndetected: undetected.length,
    incomplete: incomplete.length,
    zeroTestMutants: zeroTests.length,
    success: undetected.length === 0 && incomplete.length === 0 && zeroTests.length === 0,
    failedMutants: mutants.filter((mutant) => undetected.includes(mutant) || incomplete.includes(mutant) || zeroTests.includes(mutant)),
  };
}
