import { Err, Ok } from "ts-results-es";
import { expect, it } from "vitest";
import { renderSelected } from "../src/render-selected.js";
import { expectResults } from "./expect-results.js";

it("追加順と重複行を保持する", () => {
  expectResults(renderSelected(["alpha", "beta", "alpha"], [0, 1, 2]), [
    new Ok("alpha"),
    new Ok("beta"),
    new Ok("alpha"),
  ]);
});

it("要求の順序と同じ位置への複数の要求を保持する", () => {
  expectResults(renderSelected(["alpha", "beta", "gamma"], [2, 0, 2, 1, 0]), [
    new Ok("gamma"),
    new Ok("alpha"),
    new Ok("gamma"),
    new Ok("beta"),
    new Ok("alpha"),
  ]);
});

it("空の文字列も格納された行として返す", () => {
  expectResults(renderSelected([""], [0, 0]), [new Ok(""), new Ok("")]);
});

it("位置の要求がなければ結果も空になる", () => {
  expect(renderSelected(["alpha"], [])).toEqual([]);
  expect(renderSelected([], [])).toEqual([]);
});

it("空状態ではどの要求位置も範囲外になる", () => {
  expectResults(renderSelected([], [-1, 0, 1, Number.MAX_SAFE_INTEGER]), [
    new Err("position-out-of-range"),
    new Err("position-out-of-range"),
    new Err("position-out-of-range"),
    new Err("position-out-of-range"),
  ]);
});

it("負の位置と末尾以降の位置を拒否する", () => {
  expectResults(renderSelected(["alpha"], [-2, -1, 0, 1, 2]), [
    new Err("position-out-of-range"),
    new Err("position-out-of-range"),
    new Ok("alpha"),
    new Err("position-out-of-range"),
    new Err("position-out-of-range"),
  ]);
});

it("失敗した要求の後も元の位置の行を取得できる", () => {
  expectResults(renderSelected(["alpha", "beta", "alpha"], [-1, 0, 3, 2, 4, 1, 0]), [
    new Err("position-out-of-range"),
    new Ok("alpha"),
    new Err("position-out-of-range"),
    new Ok("alpha"),
    new Err("position-out-of-range"),
    new Ok("beta"),
    new Ok("alpha"),
  ]);
});

it("readonlyの入力を変更せず繰り返し同じ結果を返す", () => {
  const lines = Object.freeze(["alpha", "beta", "alpha"]);
  const positions = Object.freeze([-1, 2, 3, 0]);
  const expected = [
    new Err("position-out-of-range"),
    new Ok("alpha"),
    new Err("position-out-of-range"),
    new Ok("alpha"),
  ];
  expectResults(renderSelected(lines, positions), expected);
  expectResults(renderSelected(lines, positions), expected);
  expect(lines).toEqual(["alpha", "beta", "alpha"]);
  expect(positions).toEqual([-1, 2, 3, 0]);
});
