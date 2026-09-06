---
name: standard-conformance
description: architecture-standard に対する対象プロジェクトの適合性を読み取り専用で監査し、設定 drift と規律違反を baseline 差分管理可能な JSON 形式で報告する。修正は行わない。
---

# standard-conformance

対象プロジェクトが `architecture-standard` に適合しているかを読み取り専用で監査する Skill である。
コードの編集は行わず、監査結果と基線（baseline）との差分を報告する。

## 前提

- この Skill の所在（`skills/standard-conformance/SKILL.md`）から二段上の親 directory（`../../`）を `<standard-root>` として固定する。
- 標準本文は手元の `<standard-root>` 配下にある最新の規範文書（`README.md`, `process/audit.md`, `structure/`, `concerns/`, `principles/`, `tools/`）を直接参照する。
- 監査結果は対象プロジェクト側の基線台帳（`docs/conformance-baseline.json`）と照合し、既存の承認済み違反と新規違反を明確に分離する。

## 監査手順

以下の順序で照合を進める。

1. **環境と言語 surface の特定**:
   対象プロジェクトの言語、フレームワーク、ビルドツール、リンター構成を特定する。
2. **設定 drift の監査**:
   静的解析・構文検査ツールの設定を標準の要求と比較する。
   - `BannedSymbols`、`clippy.toml`、`oxlint`、`biome`、`.editorconfig` 等が標準の禁止事項や推奨ルールを充足しているか確認する。
3. **境界と依存方向の照合**:
   `<standard-root>/structure/skeleton.md` の境界と依存方向表に、プロジェクトのディレクトリ構成とモジュール間参照を照合する。
4. **横断的関心事と原則の照合**:
   `<standard-root>/concerns/`（並行処理、回復性、エラー設計等）および `<standard-root>/principles/` の完了条件・禁止事項に照合する。
5. **言語・ツール固有規律の照合**:
   `<standard-root>/tools/` に定義された言語固有の実現規律に照合する。

## 出力仕様

監査結果は以下の JSON 形式で報告する。

```json
{
  "violations": [
    {
      "rule": "<標準ファイルの相対パスと該当見出し>",
      "file": "<プロジェクト内の相対ファイルパス>",
      "line": 42,
      "evidence": "<規律に反している観測事実の一文>",
      "mechanizable": false
    }
  ],
  "baseline": {
    "file": "docs/conformance-baseline.json",
    "status": "matched | new-violations-found | baseline-not-found",
    "newCount": 0,
    "baselineCount": 0,
    "resolvedCount": 0
  }
}
```

## 基線（baseline）の運用規律

1. **対象プロジェクト側での保持**:
   基線は対象プロジェクトの `docs/conformance-baseline.json` に記録する。標準側や dotfiles 側には保持しない。
2. **単調減少の原則**:
   基線に記録された既存違反は許容されるが、新たな違反を追加して基線を肥大化させてはならない。コード修正によって違反が解消された場合、基線から該当項目を削除して単調減少させる。
3. **判定基準**:
   基線に存在しない新規の違反が 1 件でも検出された場合は適合性判定を FAIL とする。既存の基線内違反のみであれば WARN（段階的移行中）として扱う。

## Non-goals

- 指摘の修正やコードの書き換えは行わない（修正は `tdd-implementation` や `code-refactoring`、移行計画は `process/migration.md` に従う）。
- 標準側の本文や規律を編集しない。標準側の矛盾や不足を発見した場合は `standard-feedback` へ渡す。
