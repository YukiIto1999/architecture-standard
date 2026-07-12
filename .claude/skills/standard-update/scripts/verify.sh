#!/usr/bin/env bash
# 標準の更新後に走らせる機械検査。repo の root で実行する。読み取り専用。repo 内に一時ファイルを作らない。
# リンク切れ・6節の均衡・概念層への言語漏れ・概念数の整合・principles/concerns の逐語一致・concerns/structure/languages の製品名指しの tools 登録を、すべて pass/fail で確かめる。
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

echo "=== 1. broken .md links(principles/concerns/languages/structure/tools + README) ==="
broken=0
while IFS= read -r f; do
  d=$(dirname "$f")
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    [ -f "$d/$l" ] || { echo "  broken: $f -> $l"; broken=1; }
  done < <(rg -oN '\]\(([^)]+\.md)\)' "$f" -r '$1' 2>/dev/null)
done < <(fd . principles concerns languages structure tools -e md 2>/dev/null; echo README.md)
if [ "$broken" = 0 ]; then pass "リンク切れなし"; else fail "リンク切れあり(上記 broken 行)"; fi

echo
echo "=== 2. 6節の均衡(concerns/principles/languages。各 ### の数が層内で一致するはず) ==="
balance_ok=1
for dir in concerns principles languages; do
  [ -d "$dir" ] || continue
  first=""
  line="$dir: "
  for s in 要求 根拠 完了条件 禁止事項 行動; do
    c=$(rg -c -g '*.md' "^### $s" "$dir" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
    line+="$s=$c "
    [ -z "$first" ] && first="$c"
    [ "$c" = "$first" ] || balance_ok=0
  done
  echo "$line"
done
if [ "$balance_ok" = 1 ]; then pass "5節が各層内で均衡"; else fail "5節の数が層内で不一致"; fi

echo
echo "=== 3. concerns への言語機構/方言の漏れ(あってはならない) ==="
if rg -nP '\b(sqlx|tokio|axum|tower|serde|Dapper|Npgsql|EF Core|zod|valibot|neverthrow|SolidJS|Tailwind|Vite|VSCode|fred|apalis|PGMQ|clap|NSwag|Wolverine|Photino|MAUI|Kobalte|ON CONFLICT|ON DUPLICATE|StreamJsonRpc|vscode-jsonrpc|createResource|createSignal|actor framework)\b' concerns/*.md; then
  fail "concerns に言語機構/方言が漏れている(中立化するか languages へ移すこと)"
else
  pass "concerns に言語機構/方言の漏れなし"
fi

echo
echo "=== 4. principles への言語/製品/方言の漏れ(あってはならない) ==="
if rg -nP '\b(sqlx|tokio|axum|Dapper|Npgsql|EF Core|zod|valibot|SolidJS|ON CONFLICT|ON DUPLICATE)\b' principles/*.md; then
  fail "principles に言語/製品/方言が漏れている(principles は完全に言語非依存)"
else
  pass "principles に言語/製品/方言の漏れなし"
fi

echo
echo "=== 5. 概念数の整合(concerns 実ファイル数 = 17 = concerns/README.md の表) ==="
# 概念数の正は 17(goal-21 で privacy・performance を新設)。
# root README.md の概念数表記の更新は goal-19 以降が所有するため、ここでは固定値と照合し、root の表記は情報として出す。
expected_concepts=17
concerns_actual=$(find concerns -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
root_claim=$(rg -oP '(?<=概念ごとの規律。)\d+(?=概念)' README.md | head -1)
concerns_readme_rows=$(rg -c '^\| \[' concerns/README.md 2>/dev/null || echo 0)
echo "concerns 実ファイル数: $concerns_actual"
echo "README.md(root) の記載(参考): ${root_claim:-<抽出できず>}"
echo "concerns/README.md の表の行数: $concerns_readme_rows"
if [ "$concerns_actual" = "$expected_concepts" ] && [ "$concerns_readme_rows" = "$expected_concepts" ]; then
  pass "概念数が一致($concerns_actual)"
else
  fail "概念数が不一致(実ファイル=$concerns_actual, 期待=$expected_concepts, concerns/README.md=$concerns_readme_rows)"
fi

echo
echo "=== 6. skill の概念列挙と concerns/ 実ファイルの突合 ==="
concerns_files=$(find concerns -maxdepth 1 -name '*.md' ! -name 'README.md' -exec basename {} .md \; | sort)
skill_ok=1
for f in ".claude/skills/standard-update/SKILL.md" ".claude/skills/standard-update/references/concerns.md"; do
  if [ ! -f "$f" ]; then echo "  MISSING FILE: $f"; skill_ok=0; continue; fi
  listed=$(rg -oP 'effect・[^。\n]*' "$f" | head -1 | sed 's/・/\n/g' | sort)
  if [ -z "$listed" ]; then echo "  $f: 概念列挙が見つからない"; skill_ok=0; continue; fi
  diff_out=$(diff <(echo "$concerns_files") <(echo "$listed"))
  if [ -n "$diff_out" ]; then
    echo "  $f: concerns/ 実ファイルと不一致"
    echo "$diff_out" | sed 's/^/    /'
    skill_ok=0
  fi
done
if [ "$skill_ok" = 1 ]; then pass "skill の概念列挙が concerns/ 実ファイルと一致"; else fail "skill の概念列挙が concerns/ 実ファイルと不一致"; fi

echo
echo "=== 7. principles と concerns の逐語一致(18文字連続一致・5文節相当の近似。goal-04 再発防止) ==="
if ! command -v node >/dev/null 2>&1; then
  echo "(node が見つからないため skip)"
else
  overlap_out=$(node "$SCRIPT_DIR/verbatim-overlap.mjs" 2>&1)
  echo "$overlap_out"
  candidates=$(echo "$overlap_out" | rg -oP '(?<=candidates: )\d+' | head -1)
  if [ "${candidates:-}" = "0" ]; then
    pass "逐語一致の候補なし"
  else
    fail "逐語一致の候補あり(上記出力を確認)"
  fi
fi

echo
echo "=== 8. concerns・structure・languages の製品名指しが tools のエントリに登録済みか(goal-25・goal-26) ==="
if ! command -v node >/dev/null 2>&1; then
  echo "(node が見つからないため skip)"
else
  naming_out=$(node "$SCRIPT_DIR/naming-registry-check.mjs" 2>&1)
  echo "$naming_out"
  name_violations=$(echo "$naming_out" | rg -oP '(?<=violations: )\d+' | head -1)
  if [ "${name_violations:-}" = "0" ]; then
    pass "製品名指しは全て tools に登録済み"
  else
    fail "tools に未登録の製品名指しあり(上記出力を確認)"
  fi
fi

echo
if [ "$FAILED" = 0 ]; then
  echo "=== 総合: PASS ==="
else
  echo "=== 総合: FAIL ==="
fi
exit "$FAILED"
