#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'FAIL: git repository で実行すること\n' >&2
  exit 1
}
VERIFY_REL=".claude/skills/standard-update/scripts/verify.sh"
TEMP_BASE="${TMPDIR:-/tmp}"
TEMP_BASE="$(cd "$TEMP_BASE" 2>/dev/null && pwd -P)" || {
  printf 'FAIL: 一時ディレクトリを作成できない\n' >&2
  exit 1
}
TEST_ROOT="$(mktemp -d "$TEMP_BASE/architecture-standard-verify-test.XXXXXX")" || {
  printf 'FAIL: 一時ディレクトリを作成できない\n' >&2
  exit 1
}
case "$TEST_ROOT" in
  "$TEMP_BASE"/architecture-standard-verify-test.*) ;;
  *)
    printf 'FAIL: 安全でない一時ディレクトリ: %s\n' "$TEST_ROOT" >&2
    exit 1
    ;;
esac
cleanup() {
  case "$TEST_ROOT" in
    "$TEMP_BASE"/architecture-standard-verify-test.*)
      [ ! -e "$TEST_ROOT" ] || rm -rf -- "$TEST_ROOT"
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

passed=0
failed=0

make_fixture() {
  local name="$1"
  local fixture="$TEST_ROOT/$name"

  mkdir -p "$fixture/.claude/skills/standard-update" || return 1
  cp -a \
    "$REPO_ROOT/README.md" \
    "$REPO_ROOT/principles" \
    "$REPO_ROOT/concerns" \
    "$REPO_ROOT/languages" \
    "$REPO_ROOT/structure" \
    "$REPO_ROOT/tools" \
    "$REPO_ROOT/process" \
    "$fixture/" || return 1
  cp -a \
    "$REPO_ROOT/.claude/skills/standard-update/SKILL.md" \
    "$REPO_ROOT/.claude/skills/standard-update/references" \
    "$REPO_ROOT/.claude/skills/standard-update/scripts" \
    "$fixture/.claude/skills/standard-update/" || return 1
  git -C "$fixture" init --quiet || return 1
  printf '%s\n' "$fixture"
}

run_verify() {
  local fixture="$1"
  (
    cd "$fixture" || exit 1
    bash "$VERIFY_REL"
  ) 2>&1
}

record_pass() {
  printf 'PASS: %s\n' "$1"
  passed=$((passed + 1))
}

record_fail() {
  printf 'FAIL: %s\n' "$1"
  printf '%s\n' "$2" | sed 's/^/  /'
  failed=$((failed + 1))
}

expect_pass() {
  local label="$1"
  local fixture="$2"
  local output

  if output=$(run_verify "$fixture"); then
    record_pass "$label"
  else
    record_fail "$label" "$output"
  fi
}

expect_fail() {
  local label="$1"
  local fixture="$2"
  local expected="$3"
  local output

  if output=$(run_verify "$fixture"); then
    record_fail "$label" "verify.sh が PASS した"
  elif ! printf '%s\n' "$output" | rg -qF "$expected"; then
    record_fail "$label" "期待した診断がない: $expected
$output"
  else
    record_pass "$label"
  fi
}

fixture=$(make_fixture baseline)
expect_pass "現行ツリーを受理する" "$fixture"

fixture=$(make_fixture dynamic-concerns-ledger)
cp "$fixture/concerns/privacy.md" "$fixture/concerns/extra.md"
sed -i '/^| \[experience\]/a | [extra](./extra.md) | 台帳から追加した検査用の概念 |' "$fixture/concerns/README.md"
sed -i 's/17概念/18概念/' "$fixture/README.md"
sed -i 's/・experience。/・experience・extra。/' \
  "$fixture/.claude/skills/standard-update/SKILL.md" \
  "$fixture/.claude/skills/standard-update/references/concerns.md"
expect_pass "concerns の期待数を台帳から導出する" "$fixture"

fixture=$(make_fixture concept-three-way-mismatch)
sed -i 's/17概念/16概念/' "$fixture/README.md"
expect_fail "concerns の台帳・実ファイル・root 記載を三者照合する" "$fixture" "概念数が不一致"

fixture=$(make_fixture concept-table-scope)
printf '\n## 補助表\n\n| ファイル | 用途 |\n|---|---|\n| [effect](./effect.md) | 既存概念への補助参照 |\n' >> "$fixture/concerns/README.md"
expect_pass "concerns の概念台帳以外のファイル表を数えない" "$fixture"

fixture=$(make_fixture section-order)
sed -i '0,/^### 根拠$/{s//### __SWAP__/}' "$fixture/concerns/privacy.md"
sed -i '0,/^### 完了条件$/{s//### 根拠/}' "$fixture/concerns/privacy.md"
sed -i 's/^### __SWAP__$/### 完了条件/' "$fixture/concerns/privacy.md"
expect_fail "規律単位内の必須節の順序違反を検出する" "$fixture" "必須節が不正"

fixture=$(make_fixture section-local-counts)
sed -i '0,/^### 根拠$/{s//### 完了条件/}' "$fixture/concerns/privacy.md"
sed -i '0,/^### 完了条件$/{s//### 根拠/}' "$fixture/concerns/performance.md"
expect_fail "層合計が均衡していても規律単位内の重複と欠落を検出する" "$fixture" "必須節が不正"

fixture=$(make_fixture section-exclusion-scope)
printf '\n## 概要\n\nprinciples では全ての第2見出しが規律単位である。\n' >> "$fixture/principles/comment.md"
expect_fail "非単位節の除外を該当する領域だけに限定する" "$fixture" "必須節が不正"

fixture=$(make_fixture process-count)
printf '# extra\n' > "$fixture/process/extra.md"
sed -i '/^| \[migration\]/a | [extra](./extra.md) | 検査用の追加単位 |' "$fixture/process/README.md"
expect_fail "process の台帳と実ファイルが7単位であることを検査する" "$fixture" "process の単位数が不一致"

fixture=$(make_fixture process-table-scope)
printf '\n## 補助表\n\n| ファイル | 用途 |\n|---|---|\n| [audit](./audit.md) | 既存単位への補助参照 |\n' >> "$fixture/process/README.md"
expect_pass "process の単位台帳以外のファイル表を数えない" "$fixture"

fixture=$(make_fixture tools-count-valid)
expect_pass "tools がREADMEを除いて6分割であることを受理する" "$fixture"

fixture=$(make_fixture tools-count-extra)
printf '# extra\n' > "$fixture/tools/extra.md"
expect_fail "tools がREADMEを除いて6分割であることを検査する" "$fixture" "tools の分割数が不一致(実ファイル=7, 期待=6)"

fixture=$(make_fixture tools-count-missing)
rm -- "$fixture/tools/build.md"
expect_fail "tools の build 単位の欠落を検査する" "$fixture" "tools の分割数が不一致(実ファイル=5, 期待=6)"

fixture=$(make_fixture tools-readme-build-row-missing)
sed -i '/^| \[build\](\.\/build\.md)/d' "$fixture/tools/README.md"
expect_fail "tools README の構成表から build 行が欠落した場合を検査する" "$fixture" "tools/README.md の構成表と実ファイルが不一致"

fixture=$(make_fixture tools-root-catalog-mismatch)
sed -i 's/language・stack・build・inspection・services・platforms の6分割/language・stack・inspection・services・platforms の5分割/' "$fixture/README.md"
expect_fail "root README の tools 6分類を構成表と照合する" "$fixture" "root README.md の tools 6分類が不一致"

fixture=$(make_fixture tools-skill-catalog-mismatch)
sed -i 's/language・stack・build・inspection・services・platforms の6分割/language・stack・inspection・services・platforms の5分割/' \
  "$fixture/.claude/skills/standard-update/SKILL.md"
expect_fail "standard-update skill の tools 6分類を構成表と照合する" "$fixture" "standard-update/SKILL.md の tools 6分類が不一致"

fixture=$(make_fixture tools-reference-catalog-mismatch)
sed -i 's/^6分割に置く。/5分割に置く。/' "$fixture/.claude/skills/standard-update/references/tools.md"
expect_fail "standard-update tools reference の tools 6分類を構成表と照合する" "$fixture" "references/tools.md の tools 6分類が不一致"

fixture=$(make_fixture languages-count)
cp "$fixture/languages/rust/retention.md" "$fixture/languages/rust/extra.md"
expect_fail "languages が3言語それぞれ8ファイルであることを検査する" "$fixture" "languages の単位数が不一致"

fixture=$(make_fixture language-discipline-table-missing)
sed -i '/^| connection | 効果を言語の効果型で表す |/d' "$fixture/languages/rust/inspection.md"
expect_fail "language 本文の規律が対応表から欠落した場合を検査する" "$fixture" "languages/rust の規律対応表に欠落"

fixture=$(make_fixture language-discipline-table-extra)
sed -i '/^## 参照$/i | connection | 存在しない規律 | 検査用の対応 |\n' "$fixture/languages/csharp/inspection.md"
expect_fail "language 本文にない規律が対応表へ混入した場合を検査する" "$fixture" "languages/csharp の規律対応表に余分"

fixture=$(make_fixture language-discipline-table-duplicate)
sed -i '/^| translation | unknown で受けて一度だけ parse する |/p' "$fixture/languages/typescript/inspection.md"
expect_fail "language 規律の対応表への重複登録を検査する" "$fixture" "languages/typescript の規律対応表に重複"

fixture=$(make_fixture language-discipline-body-fence)
sed -i '/^## 参照$/i ````text\n## fence 内の規律ではない見出し\n````\n' "$fixture/languages/rust/connection.md"
expect_pass "language 本文の fenced code 内にある H2 を規律として扱わない" "$fixture"

fixture=$(make_fixture language-discipline-table-fence)
sed -i '/^## 規則と検証機構の対応$/a ~~~~text\n| connection | fence 内の規律ではない行 | 検査対象外 |\n## fence 内の H2\n~~~~' "$fixture/languages/csharp/inspection.md"
expect_pass "language 対応表の fenced code 内にある pipe と H2 を無視して後続の実表を読む" "$fixture"

fixture=$(make_fixture language-discipline-large-set)
large_body="$fixture/language-discipline-large-body"
large_table="$fixture/language-discipline-large-table"
large_inspection="$fixture/languages/typescript/inspection.md.new"
padding=$(head -c 2048 /dev/zero | tr '\0' x)
: > "$large_body"
: > "$large_table"
for ((index = 1; index <= 100; index++)); do
  printf -v discipline_number '%03d' "$index"
  discipline="大規模規律-${discipline_number}-${padding}"
  printf '\n## %s\n\n### 要求\n\n検査用。\n\n### 根拠\n\n検査用。\n\n### 完了条件\n\n検査用。\n\n### 禁止事項\n\n検査用。\n\n### 行動\n\n検査用。\n' "$discipline" >> "$large_body"
  printf '| translation | %s | 検査用 |\n' "$discipline" >> "$large_table"
done
while IFS= read -r line || [ -n "$line" ]; do
  printf '%s\n' "$line"
done < "$large_body" >> "$fixture/languages/typescript/translation.md"
awk -v rows="$large_table" '
  $0 == "## 参照" {
    while ((getline row < rows) > 0) print row
    close(rows)
    print ""
  }
  { print }
' "$fixture/languages/typescript/inspection.md" > "$large_inspection"
mv -- "$large_inspection" "$fixture/languages/typescript/inspection.md"
expect_pass "大きな language 規律集合を同一集合として照合する" "$fixture"

fixture=$(make_fixture concerns-product-leakage)
printf '\nPlaywright で表示を計測する。\n' >> "$fixture/concerns/experience.md"
expect_fail "concerns への検査製品の混入を検出する" "$fixture" "concerns に言語機構/方言が漏れている"

fixture=$(make_fixture product-leak)
printf '\nSchemathesis を原則本文で名指しする。\n' >> "$fixture/principles/comment.md"
expect_fail "tools の採用行から得た製品名の principles 漏れを検出する" "$fixture" "台帳由来の製品名"

fixture=$(make_fixture product-boundary)
printf '\nSchemathesisLike は別の識別子である。\n' >> "$fixture/principles/comment.md"
expect_pass "製品名の部分文字列だけでは違反にしない" "$fixture"

fixture=$(make_fixture product-at-prefix)
printf '\n@typespec/openapi3 を原則本文で名指しする。\n' >> "$fixture/principles/comment.md"
expect_fail "@ で始まる製品名を正規名の境界で検出する" "$fixture" "台帳由来の製品名: @typespec/openapi3"

fixture=$(make_fixture product-build-registry)
printf '\nNx は、task graph の orchestrator である。\n' >> "$fixture/structure/tests/layout.md"
expect_pass "build の採用名を tools registry に含める" "$fixture"

printf '\nテスト: %d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
