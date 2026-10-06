import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { run } from "../project/scripts/process.mjs";

const host = dirname(fileURLToPath(import.meta.url));

export async function checkProject(projectPath, { boundary } = {}) {
  if (!projectPath) throw new Error("Candidate project path is required");
  if (boundary !== undefined && !["hidden", "map"].includes(boundary)) {
    throw new Error(`Unknown fixture boundary contract: ${boundary}`);
  }
  const project = resolve(projectPath);
  const behavior = await run(process.execPath, [join(host, "behavior.mjs"), project], {
    cwd: project,
    timeoutMs: 30_000,
    capture: true,
  });
  const behaviorResult = JSON.parse(behavior.stdout);
  if (behaviorResult.success !== true) throw new Error("Canonical behavior oracle did not succeed");
  let boundaryResult;
  let boundaryElapsedMs;
  if (boundary !== undefined) {
    const result = await run(process.execPath, [join(host, "boundary.mjs"), project, boundary], {
      cwd: project,
      timeoutMs: 30_000,
      capture: true,
    });
    boundaryResult = JSON.parse(result.stdout);
    boundaryElapsedMs = result.elapsedMs;
    if (boundaryResult.success !== true) throw new Error("Canonical boundary oracle did not succeed");
  }
  return {
    success: true,
    behavior: behaviorResult,
    ...(boundaryResult ? { boundary: boundaryResult } : {}),
    elapsed_ms: { behavior: behavior.elapsedMs, ...(boundaryResult ? { boundary: boundaryElapsedMs } : {}) },
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [project, option, boundary, ...extra] = process.argv.slice(2);
  try {
    if (extra.length || (option !== undefined && (option !== "--boundary" || boundary === undefined))) {
      throw new Error("Usage: check.mjs <candidate-project> [--boundary hidden|map]");
    }
    const result = await checkProject(project, { boundary });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ success: false, error: String(error) }, null, 2)}\n`);
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  }
}
