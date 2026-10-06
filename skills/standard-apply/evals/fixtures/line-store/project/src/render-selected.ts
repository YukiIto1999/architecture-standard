import { Err, Ok, type Result } from "ts-results-es";
import { LineStore } from "./line-store.js";

/**
 * 要求した論理位置の行を要求順に返す選択
 * @param lines - 追加順と重複を保持する入力の行
 * @param positions - 0を起点とする整数の論理位置
 * @returns 範囲外をposition-out-of-rangeとする各要求の結果
 */
export function renderSelected(
  lines: readonly string[],
  positions: readonly number[],
): Result<string, "position-out-of-range">[] {
  const store = new LineStore();
  for (const line of lines) {
    store.append(line);
  }
  return positions.map((position) => {
    const line = store.lines[position];
    return line === undefined ? new Err("position-out-of-range" as const) : new Ok(line);
  });
}
