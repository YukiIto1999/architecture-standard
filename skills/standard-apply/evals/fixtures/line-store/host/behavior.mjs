import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export async function checkBehavior(projectPath) {
  const project = resolve(projectPath);
  const require = createRequire(join(project, "package.json"));
  const { register } = await import(pathToFileURL(require.resolve("tsx/esm/api")).href);
  const loader = register({ namespace: "line-store-oracle", tsconfig: join(project, "tsconfig.json") });
  try {
    const entry = pathToFileURL(join(project, "src/render-selected.ts")).href;
    const { renderSelected } = await loader.import(entry, import.meta.url);
    const { Ok, Err } = await loader.import("ts-results-es", entry);
    assert.equal(typeof renderSelected, "function", "Fixed public entry must be exported");
    let cases = 0;
    const verify = (lines, positions, expected) => {
      const frozenLines = Object.freeze([...lines]);
      const frozenPositions = Object.freeze([...positions]);
      const results = renderSelected(frozenLines, frozenPositions);
      assert.ok(Array.isArray(results), "Public entry must return an array");
      assert.equal(results.length, positions.length, "One result is required for each request");
      for (const [index, result] of results.entries()) {
        const answer = expected[index];
        assert.ok(result instanceof Ok || result instanceof Err, "Results must be ts-results-es instances");
        if (answer.kind === "ok") {
          assert.equal(result.isOk(), true, `Expected success at request ${index}`);
          assert.equal(result.value, answer.value);
        } else {
          assert.equal(result.isErr(), true, `Expected failure at request ${index}`);
          assert.equal(result.error, "position-out-of-range");
        }
      }
      assert.deepEqual(frozenLines, lines, "Line input must remain unchanged");
      assert.deepEqual(frozenPositions, positions, "Position input must remain unchanged");
      cases += 1;
    };
    const ok = (value) => ({ kind: "ok", value });
    const err = { kind: "err" };
    verify(["alpha", "beta", "alpha"], [0, 2, 1, 2, 0], [ok("alpha"), ok("alpha"), ok("beta"), ok("alpha"), ok("alpha")]);
    verify([], [-1, 0, 1], [err, err, err]);
    verify([], [], []);
    verify([""], [-1, 0, 1, 0], [err, ok(""), err, ok("")]);
    verify(["only"], [0, 0, 1, -1, 0], [ok("only"), ok("only"), err, err, ok("only")]);
    verify(["a", "b", "a"], [-1, 0, 3, 2, 4, 1, 0], [err, ok("a"), err, ok("a"), err, ok("b"), ok("a")]);
    verify(["a", "b"], [Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, 1], [err, err, ok("b")]);
    verify(["unused"], [], []);
    const alphabet = ["", "alpha", "beta", "alpha\nbeta", "日本語"];
    for (let size = 0; size <= 16; size += 1) {
      const lines = Array.from({ length: size }, (_, index) => alphabet[(size + index * 3) % alphabet.length]);
      const positions = [];
      const expected = [];
      for (let position = size - 1; position >= 0; position -= 1) {
        positions.push(-1, position, size, position);
        expected.push(err, ok(lines[position]), err, ok(lines[position]));
      }
      verify(lines, positions, expected);
      verify(lines, positions, expected);
    }
    return { success: true, cases, integerPrecondition: true };
  } finally {
    await loader.unregister();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const result = await checkBehavior(process.argv[2]);
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  }
}
