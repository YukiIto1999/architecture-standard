import { spawn } from "node:child_process";
import { performance } from "node:perf_hooks";

export async function run(command, args, { cwd, timeoutMs, capture = false }) {
  const started = performance.now();
  const child = spawn(command, args, {
    cwd,
    detached: process.platform !== "win32",
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    env: { ...process.env, NO_COLOR: "1" },
  });
  let stdout = "";
  let stderr = "";
  child.stdout?.setEncoding("utf8");
  child.stderr?.setEncoding("utf8");
  child.stdout?.on("data", (chunk) => { stdout += chunk; });
  child.stderr?.on("data", (chunk) => { stderr += chunk; });
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    if (!child.pid) return;
    if (process.platform === "win32") child.kill("SIGKILL");
    else {
      try { process.kill(-child.pid, "SIGKILL"); }
      catch (error) { if (error.code !== "ESRCH") child.kill("SIGKILL"); }
    }
  }, Math.max(1, timeoutMs));
  try {
    const exit = await new Promise((resolve, reject) => {
      child.once("error", reject);
      child.once("close", (code, signal) => resolve({ code, signal }));
    });
    const elapsedMs = performance.now() - started;
    if (timedOut || elapsedMs > timeoutMs) {
      throw new Error(`${command} exceeded ${timeoutMs}ms`);
    }
    if (exit.code !== 0) {
      throw new Error(`${command} exited ${exit.code ?? exit.signal}: ${stderr}`);
    }
    return { stdout, stderr, elapsedMs };
  } finally {
    clearTimeout(timer);
  }
}
