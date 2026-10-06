import fc from "fast-check";
import { Err, Ok } from "ts-results-es";
import { expect, it } from "vitest";
import { renderSelected } from "../src/render-selected.js";
import { expectResults } from "./expect-results.js";

const propertySettings = { seed: 20_261_006, numRuns: 64 };
const lineInputs = fc.array(fc.string({ maxLength: 24 }), { maxLength: 24 });

it("全位置の走査は追加した行の列そのものになる", () => {
  fc.assert(
    fc.property(lineInputs, (lines) => {
      const positions = Array.from({ length: lines.length }, (_, position) => position);
      const results = renderSelected(Object.freeze(lines), Object.freeze(positions));
      expect(results).toEqual(lines.map((line) => new Ok(line)));
    }),
    propertySettings,
  );
});

it("同じ行と同じ要求の繰り返しは消去されない", () => {
  fc.assert(
    fc.property(fc.string({ maxLength: 24 }), fc.integer({ min: 1, max: 24 }), (line, count) => {
      const lines = Array.from({ length: count }, () => line);
      const positions = Array.from({ length: count * 2 }, (_, index) => index % count);
      expect(renderSelected(lines, positions)).toEqual(positions.map(() => new Ok(line)));
    }),
    propertySettings,
  );
});

it("範囲外の要求を挟んでも後続の行と要求順を保持する", () => {
  fc.assert(
    fc.property(lineInputs, fc.integer({ min: 1, max: 100 }), (lines, distance) => {
      const positions: number[] = [];
      const expected: (Ok<string> | Err<string>)[] = [];
      for (const [position, line] of lines.entries()) {
        positions.push(-distance, position, lines.length + distance, position);
        expected.push(
          new Err("position-out-of-range"),
          new Ok(line),
          new Err("position-out-of-range"),
          new Ok(line),
        );
      }
      expectResults(renderSelected(Object.freeze(lines), Object.freeze(positions)), expected);
    }),
    propertySettings,
  );
});
