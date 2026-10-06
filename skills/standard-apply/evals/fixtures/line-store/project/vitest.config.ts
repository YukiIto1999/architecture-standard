import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    environment: "node",
    maxWorkers: 1,
    fileParallelism: false,
    testTimeout: 5_000,
    passWithNoTests: false,
    coverage: {
      provider: "v8",
      include: ["src/**/*.ts"],
      reporter: ["json-summary", "text"],
      reportsDirectory: "reports/coverage",
      thresholds: { branches: 100, lines: 100 },
    },
  },
});
