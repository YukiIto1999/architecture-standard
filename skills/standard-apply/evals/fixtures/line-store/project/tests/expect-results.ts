import type { Result } from "ts-results-es";
import { expect } from "vitest";

/**
 * Resultの診断情報を比較しない公開の値の照合
 * @param actual - 公開入口から返された要求順の結果
 * @param expected - 契約から固定した要求順の期待値
 * @throws {@link Error} 期待値の欠落
 */
export function expectResults(
  actual: readonly Result<string, string>[],
  expected: readonly Result<string, string>[],
): void {
  expect(actual).toHaveLength(expected.length);
  for (const [index, result] of actual.entries()) {
    const expectedResult = expected[index];
    if (expectedResult === undefined) {
      throw new Error("Expected result is missing");
    }
    expect(result).toBeInstanceOf(expectedResult.constructor);
    if (expectedResult.isOk()) {
      expect(result).toMatchObject({ value: expectedResult.value });
    } else {
      expect(result).toMatchObject({ error: expectedResult.error });
    }
  }
}
