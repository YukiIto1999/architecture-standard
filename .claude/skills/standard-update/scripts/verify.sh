#!/usr/bin/env bash
# 標準の更新後に走らせる機械検査。repo の root で実行する。読み取り専用。repo 内に一時ファイルを作らない。
# リンク切れ・単位ごとの必須5節と任意の例・層への製品名漏れ・台帳と実ファイル数の整合・language 規律と検証対応表の整合・principles/concerns の逐語一致・concerns/structure/languages の製品名指しの tools 登録を、すべて pass/fail で確かめる。
set -uo pipefail

required_commands=(git rg fd awk sed find wc tr head tail sort diff dirname paste basename cut node)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'FAIL: missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'FAIL: git repository で実行すること\n' >&2
  exit 1
}
cd "$REPO_ROOT" || exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

markdown_section_file_table_rows() {
  awk -v target="$2" '
    $0 == "## " target { in_section = 1; next }
    in_section && /^##[[:space:]]+/ { in_section = 0 }
    in_section && /^\| \[[^]]+\]\(\.\/[^)]+\.md\) \|/ { count++ }
    END { print count + 0 }
  ' "$1"
}

language_body_discipline_records() {
  local language="$1"
  local file
  local axis

  while IFS= read -r file; do
    axis=$(basename "$file" .md)
    awk -v axis="$axis" '
      function fence_run_length(line, marker, cursor) {
        marker = substr(line, 1, 1)
        if (marker != "`" && marker != "~") return 0
        for (cursor = 1; substr(line, cursor, 1) == marker; cursor++);
        return cursor - 1
      }

      function consume_fence(line, trimmed, marker, run_length, remainder) {
        trimmed = line
        sub(/^[[:space:]]+/, "", trimmed)
        marker = substr(trimmed, 1, 1)
        run_length = fence_run_length(trimmed)

        if (in_fence) {
          if (marker == fence_marker && run_length >= fence_length) {
            remainder = substr(trimmed, run_length + 1)
            if (remainder ~ /^[[:space:]]*$/) {
              in_fence = 0
              fence_marker = ""
              fence_length = 0
            }
          }
          return 1
        }

        if (run_length < 3) return 0
        if (marker == "`" && substr(trimmed, run_length + 1) ~ /`/) return 0
        in_fence = 1
        fence_marker = marker
        fence_length = run_length
        return 1
      }

      consume_fence($0) { next }

      /^## / {
        discipline = substr($0, 4)
        if (discipline == "概要" || discipline == "規則と検証機構の対応" || discipline == "参照") {
          next
        }
        printf "%s | %s\t%s:%d\n", axis, discipline, FILENAME, FNR
      }
    ' "$file"
  done < <(find "languages/$language" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)
}

language_inspection_discipline_records() {
  local language="$1"

  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    function fence_run_length(line, marker, cursor) {
      marker = substr(line, 1, 1)
      if (marker != "`" && marker != "~") return 0
      for (cursor = 1; substr(line, cursor, 1) == marker; cursor++);
      return cursor - 1
    }

    function consume_fence(line, trimmed, marker, run_length, remainder) {
      trimmed = line
      sub(/^[[:space:]]+/, "", trimmed)
      marker = substr(trimmed, 1, 1)
      run_length = fence_run_length(trimmed)

      if (in_fence) {
        if (marker == fence_marker && run_length >= fence_length) {
          remainder = substr(trimmed, run_length + 1)
          if (remainder ~ /^[[:space:]]*$/) {
            in_fence = 0
            fence_marker = ""
            fence_length = 0
          }
        }
        return 1
      }

      if (run_length < 3) return 0
      if (marker == "`" && substr(trimmed, run_length + 1) ~ /`/) return 0
      in_fence = 1
      fence_marker = marker
      fence_length = run_length
      return 1
    }

    consume_fence($0) { next }

    $0 == "## 規則と検証機構の対応" { in_table = 1; next }
    in_table && /^##[[:space:]]+/ { in_table = 0 }
    !in_table || $0 !~ /^\|/ { next }

    {
      split($0, columns, "|")
      axis = trim(columns[2])
      discipline = trim(columns[3])
      if (axis == "" || axis == "実現軸" || axis == "全域" || axis ~ /^-+$/) {
        next
      }
      printf "%s | %s\t%s:%d\n", axis, discipline, FILENAME, FNR
    }
  ' "languages/$language/inspection.md"
}

record_keys() {
  cut -f1 | sed '/^$/d' | sort -u
}

duplicate_record_keys() {
  cut -f1 \
    | sed '/^$/d' \
    | sort \
    | awk '
        previous == $0 && !reported { print; reported = 1; next }
        previous != $0 { previous = $0; reported = 0 }
      '
}

set_difference() {
  local candidates="$1"
  local existing="$2"
  local candidate

  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    if ! rg -qF -x -- "$candidate" <<< "$existing"; then
      printf '%s\n' "$candidate"
    fi
  done <<< "$candidates"
}

print_record_sources() {
  local records="$1"
  local keys="$2"
  local key

  while IFS= read -r key; do
    [ -z "$key" ] && continue
    printf '  %s\n' "$key"
    printf '%s\n' "$records" \
      | awk -F '\t' -v key="$key" '$1 == key { printf "    %s\n", $2 }'
  done <<< "$keys"
}

is_non_product_token() {
  # 採用行に併記される言語名・規格名・機構の一般語だけを除き、製品名の候補は行から毎回導出する。
  case "$1" in
    "ADR"|"API"|"Build"|"C#"|"CI"|"CSS"|"Community"|"Core"|"JSON"|"JSON-RPC"|"Minimal"|"NET"|"OpenAPI"|"Rust"|"S3776"|"SPDX"|"TypeScript"|\
    "analyzer"|"backend"|"client"|"cognitive"|"collector"|"companion"|"complexity"|"cookie"|"core"|"coverage"|"desktop"|"for"|"framing"|"gate"|"generation"|"generator"|"handler"|"library"|"mobile"|"node"|"one-time"|"plugin"|"project"|"provider"|"quality"|"queue"|"record"|"root"|"runtime"|"rust"|"schema"|"script"|"sealed"|"source"|"tests/"|"tools"|"type-aware"|"union"|"up"|"v1"|"v8")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

echo "=== 1. broken .md links(principles/concerns/languages/structure/tools + README) ==="
broken=0
while IFS= read -r f; do
  d=$(dirname "$f")
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    [ -f "$d/$l" ] || { echo "  broken: $f -> $l"; broken=1; }
  done < <(rg -oN '\]\(([^)]+\.md)\)' "$f" -r '$1' 2>/dev/null)
done < <(fd . principles concerns languages structure tools process -e md 2>/dev/null; echo README.md)
if [ "$broken" = 0 ]; then pass "リンク切れなし"; else fail "リンク切れあり(上記 broken 行)"; fi

echo
echo "=== 2. 単位ごとの必須5節(principles/concerns/languages。例は任意) ==="
mapfile -d '' discipline_files < <(
  find principles concerns -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print0
  find languages -mindepth 2 -type f -name '*.md' ! -name 'README.md' -print0
)
sections_out=$(awk -f "$SCRIPT_DIR/discipline-sections.awk" "${discipline_files[@]}" 2>&1)
echo "$sections_out"
section_violations=$(echo "$sections_out" | rg -oP '(?<=violations: )\d+' | tail -1)
if [ "${section_violations:-}" = "0" ]; then
  pass "各規律単位の必須5節が各1回、要求から行動の順で存在"
else
  fail "規律単位の必須節が不正(上記の file:line を確認)"
fi

echo
echo "=== 3. concerns への言語機構/方言の漏れ(あってはならない) ==="
if rg -nP '\b(sqlx|tokio|axum|tower|serde|Dapper|Npgsql|EF Core|zod|valibot|neverthrow|SolidJS|Tailwind|Vite|VSCode|fred|apalis|PGMQ|clap|NSwag|Wolverine|Photino|MAUI|Kobalte|ON CONFLICT|ON DUPLICATE|StreamJsonRpc|vscode-jsonrpc|createResource|createSignal|actor framework|Playwright|TypeScript|compiler API)\b' concerns/*.md; then
  fail "concerns に言語機構/方言が漏れている(中立化するか languages へ移すこと)"
else
  pass "concerns に言語機構/方言の漏れなし"
fi

echo
echo "=== 4. principles への言語/製品/方言の漏れ(あってはならない) ==="
principles_leak=0
if rg -nP '\b(sqlx|tokio|axum|Dapper|Npgsql|EF Core|zod|valibot|SolidJS|ON CONFLICT|ON DUPLICATE)\b' principles/*.md; then
  principles_leak=1
fi

product_count=0
while IFS= read -r product; do
  [ -z "$product" ] && continue
  is_non_product_token "$product" && continue
  product_count=$((product_count + 1))
  product_matches=$(rg --with-filename -nP "(?<![A-Za-z0-9_.#+@/-])\\Q${product}\\E(?![A-Za-z0-9_.#+@/-])" principles/*.md 2>/dev/null || true)
  if [ -n "$product_matches" ]; then
    echo "  台帳由来の製品名: $product"
    while IFS= read -r product_match; do echo "    $product_match"; done <<< "$product_matches"
    principles_leak=1
  fi
done < <(
  rg --no-filename '^採用は、' tools/*.md 2>/dev/null \
    | rg -o '[@A-Za-z][A-Za-z0-9_.#+@/-]*' \
    | sort -u
)
echo "tools の採用行から抽出した製品名: $product_count"
if [ "$principles_leak" = 0 ]; then
  pass "principles に言語/製品/方言の漏れなし"
else
  fail "principles に言語/製品/方言が漏れている(principles は完全に言語非依存)"
fi

echo
echo "=== 5. 概念数の整合(concerns/README.md の台帳 = concerns 実ファイル = root README.md) ==="
concerns_actual=$(find concerns -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
root_claim=$(rg -oP '(?<=概念ごとの規律。)\d+(?=概念)' README.md | head -1)
concerns_readme_rows=$(markdown_section_file_table_rows concerns/README.md 概念)
echo "concerns 実ファイル数: $concerns_actual"
echo "README.md(root) の記載: ${root_claim:-<抽出できず>}"
echo "concerns/README.md の表の行数: $concerns_readme_rows"
if [ -n "$root_claim" ] && [ "$concerns_actual" = "$concerns_readme_rows" ] && [ "$root_claim" = "$concerns_readme_rows" ]; then
  pass "概念数が一致($concerns_actual)"
else
  fail "概念数が不一致(台帳=$concerns_readme_rows, 実ファイル=$concerns_actual, root=${root_claim:-<抽出できず>})"
fi

echo
echo "=== 6. process/tools/languages の単位数 ==="
numeric_ok=1
process_expected=8
process_readme_rows=$(markdown_section_file_table_rows process/README.md 単位)
process_actual=$(find process -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
echo "process: 台帳=$process_readme_rows 実ファイル=$process_actual 期待=$process_expected"
if [ "$process_readme_rows" != "$process_expected" ] || [ "$process_actual" != "$process_expected" ]; then
  fail "process の単位数が不一致(台帳=$process_readme_rows, 実ファイル=$process_actual, 期待=$process_expected)"
  numeric_ok=0
fi

tools_expected=6
tools_readme_rows=$(
  awk '
    $0 == "## 構成" { in_section = 1; next }
    in_section && /^##[[:space:]]+/ { in_section = 0 }
    in_section { print }
  ' tools/README.md \
    | sed -n 's#^| \[\([^]]*\)\](\./\([^)]*\.md\)) |.*#\1\t\2#p'
)
tools_readme_names=$(printf '%s\n' "$tools_readme_rows" | cut -f1)
tools_readme_files=$(printf '%s\n' "$tools_readme_rows" | cut -f2)
tools_readme_count=$(printf '%s\n' "$tools_readme_files" | sed '/^$/d' | wc -l | tr -d ' ')
tools_readme_set=$(printf '%s\n' "$tools_readme_files" | sed '/^$/d' | sort)
tools_catalog=$(printf '%s\n' "$tools_readme_names" | sed '/^$/d' | paste -sd '・' -)
tools_actual_files=$(find tools -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -exec basename {} \; | sort)
tools_actual=$(find tools -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
echo "tools: 台帳=$tools_readme_count 実ファイル=$tools_actual 期待=$tools_expected"
if [ "$tools_actual" != "$tools_expected" ] || [ "$tools_readme_count" != "$tools_expected" ]; then
  fail "tools の分割数が不一致(実ファイル=$tools_actual, 期待=$tools_expected)"
  numeric_ok=0
fi
if [ "$tools_readme_set" != "$tools_actual_files" ]; then
  echo "  tools/README.md の構成表:"
  printf '%s\n' "$tools_readme_set" | sed 's/^/    /'
  echo "  tools/ の実ファイル:"
  printf '%s\n' "$tools_actual_files" | sed 's/^/    /'
  fail "tools/README.md の構成表と実ファイルが不一致"
  numeric_ok=0
fi

if ! rg -qF "$tools_catalog の${tools_expected}分割" README.md; then
  fail "root README.md の tools 6分類が不一致"
  numeric_ok=0
fi
if ! rg -qF "$tools_catalog の${tools_expected}分割" .claude/skills/standard-update/SKILL.md; then
  fail "standard-update/SKILL.md の tools 6分類が不一致"
  numeric_ok=0
fi
tools_reference_line=$(rg -m1 '^[0-9]+分割に置く。' .claude/skills/standard-update/references/tools.md 2>/dev/null || true)
tools_reference_count=$(printf '%s\n' "$tools_reference_line" | sed -n 's/^\([0-9][0-9]*\)分割に置く。.*/\1/p')
tools_reference_catalog=$(printf '%s\n' "$tools_reference_line" | sed -E 's/^[0-9]+分割に置く。//; s/。$//; s/\([^)]*\)//g')
if [ "$tools_reference_count" != "$tools_expected" ] || [ "$tools_reference_catalog" != "$tools_catalog" ]; then
  fail "references/tools.md の tools 6分類が不一致"
  numeric_ok=0
fi

language_dirs_expected=3
language_dirs_actual=$(find languages -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
language_files_expected=8
language_counts=""
languages_ok=1
for language in rust csharp typescript; do
  if [ -d "languages/$language" ]; then
    language_count=$(find "languages/$language" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
  else
    language_count=0
  fi
  language_counts+="$language=$language_count "
  [ "$language_count" = "$language_files_expected" ] || languages_ok=0
done
echo "languages: 言語ディレクトリ=$language_dirs_actual 期待=$language_dirs_expected; $language_counts"
if [ "$language_dirs_actual" != "$language_dirs_expected" ] || [ "$languages_ok" = 0 ]; then
  fail "languages の単位数が不一致(言語数=$language_dirs_actual, $language_counts期待=各$language_files_expected)"
  numeric_ok=0
fi
if [ "$numeric_ok" = 1 ]; then pass "process=8、tools=6、languages=3×8 で一致"; fi

echo
echo "=== 7. languages 本文の規律と inspection 対応表の一対一照合 ==="
language_discipline_tables_ok=1
for language in rust csharp typescript; do
  body_records=$(language_body_discipline_records "$language")
  table_records=$(language_inspection_discipline_records "$language")
  body_keys=$(printf '%s\n' "$body_records" | record_keys)
  table_keys=$(printf '%s\n' "$table_records" | record_keys)
  body_duplicates=$(printf '%s\n' "$body_records" | duplicate_record_keys)
  table_duplicates=$(printf '%s\n' "$table_records" | duplicate_record_keys)
  missing=$(set_difference "$body_keys" "$table_keys")
  extra=$(set_difference "$table_keys" "$body_keys")

  if [ -n "$body_duplicates" ]; then
    print_record_sources "$body_records" "$body_duplicates"
    fail "languages/$language の本文規律名に重複"
    language_discipline_tables_ok=0
  fi
  if [ -n "$table_duplicates" ]; then
    print_record_sources "$table_records" "$table_duplicates"
    fail "languages/$language の規律対応表に重複"
    language_discipline_tables_ok=0
  fi
  if [ -n "$missing" ]; then
    print_record_sources "$body_records" "$missing"
    fail "languages/$language の規律対応表に欠落"
    language_discipline_tables_ok=0
  fi
  if [ -n "$extra" ]; then
    print_record_sources "$table_records" "$extra"
    fail "languages/$language の規律対応表に余分"
    language_discipline_tables_ok=0
  fi
done
if [ "$language_discipline_tables_ok" = 1 ]; then
  pass "languages 3言語の本文規律と inspection 対応表が一対一で一致"
fi

echo
echo "=== 8. skill の概念列挙と concerns/ 実ファイルの突合 ==="
concerns_files=$(find concerns -maxdepth 1 -name '*.md' ! -name 'README.md' -exec basename {} .md \; | sort)
skill_ok=1
for f in ".claude/skills/standard-update/SKILL.md" ".claude/skills/standard-update/references/concerns.md"; do
  if [ ! -f "$f" ]; then echo "  MISSING FILE: $f"; skill_ok=0; continue; fi
  listed=$(rg -oP 'effect・[^。\n]*' "$f" | head -1 | sed 's/・/\n/g' | sort)
  if [ -z "$listed" ]; then echo "  $f: 概念列挙が見つからない"; skill_ok=0; continue; fi
  diff_out=$(diff <(echo "$concerns_files") <(echo "$listed"))
  if [ -n "$diff_out" ]; then
    echo "  $f: concerns/ 実ファイルと不一致"
    while IFS= read -r diff_line; do echo "    $diff_line"; done <<< "$diff_out"
    skill_ok=0
  fi
done
if [ "$skill_ok" = 1 ]; then pass "skill の概念列挙が concerns/ 実ファイルと一致"; else fail "skill の概念列挙が concerns/ 実ファイルと不一致"; fi

echo
echo "=== 9. principles と concerns の逐語一致(18文字連続一致・5文節相当の近似。goal-04 再発防止) ==="
if overlap_out=$(node "$SCRIPT_DIR/verbatim-overlap.mjs" 2>&1); then
  echo "$overlap_out"
  candidates=$(echo "$overlap_out" | rg -oP '(?<=candidates: )\d+' | head -1)
  if [ "${candidates:-}" = "0" ]; then
    pass "逐語一致の候補なし"
  else
    fail "逐語一致の候補あり(上記出力を確認)"
  fi
else
  echo "$overlap_out"
  fail "逐語一致検査を実行できない"
fi

echo
echo "=== 10. concerns・structure・languages の製品名指しが tools のエントリに登録済みか(goal-25・goal-26) ==="
if naming_out=$(node "$SCRIPT_DIR/naming-registry-check.mjs" 2>&1); then
  echo "$naming_out"
  name_violations=$(echo "$naming_out" | rg -oP '(?<=violations: )\d+' | head -1)
  if [ "${name_violations:-}" = "0" ]; then
    pass "製品名指しは全て tools に登録済み"
  else
    fail "tools に未登録の製品名指しあり(上記出力を確認)"
  fi
else
  echo "$naming_out"
  fail "製品名 registry 検査を実行できない"
fi

echo
echo "=== 11. 参照動詞の向き(抽象から具象へは「が定める」) ==="
verb_violations=$(
  {
    rg -n "に従う。" principles concerns --no-heading 2>/dev/null | rg "\]\((\.\./)+(structure|languages|tools|process)" || true
    rg -n "に従う。" structure --no-heading 2>/dev/null | rg "\]\((\.\./)+(languages|tools)" || true
  } | wc -l
)
if [ "${verb_violations:-0}" = "0" ]; then
  pass "抽象から具象への「従う」参照なし"
else
  {
    rg -n "に従う。" principles concerns --no-heading 2>/dev/null | rg "\]\((\.\./)+(structure|languages|tools|process)" || true
    rg -n "に従う。" structure --no-heading 2>/dev/null | rg "\]\((\.\./)+(languages|tools)" || true
  }
  fail "抽象から具象への参照に「従う」が残っている(「が定める」へ)"
fi

echo
if [ "$FAILED" = 0 ]; then
  echo "=== 総合: PASS ==="
else
  echo "=== 総合: FAIL ==="
fi
exit "$FAILED"
