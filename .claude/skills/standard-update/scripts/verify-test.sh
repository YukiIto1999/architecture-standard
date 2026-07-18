#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
VERIFY_REL=".claude/skills/standard-update/scripts/verify.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

passed=0
failed=0

make_fixture() {
  local name="$1"
  local fixture="$TEST_ROOT/$name"

  mkdir -p "$fixture/.claude/skills/standard-update"
  cp -a \
    "$REPO_ROOT/README.md" \
    "$REPO_ROOT/principles" \
    "$REPO_ROOT/concerns" \
    "$REPO_ROOT/languages" \
    "$REPO_ROOT/structure" \
    "$REPO_ROOT/tools" \
    "$REPO_ROOT/process" \
    "$fixture/"
  cp -a \
    "$REPO_ROOT/.claude/skills/standard-update/SKILL.md" \
    "$REPO_ROOT/.claude/skills/standard-update/references" \
    "$REPO_ROOT/.claude/skills/standard-update/scripts" \
    "$fixture/.claude/skills/standard-update/"
  git -C "$fixture" init -q
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

fixture=$(make_fixture tools-count)
printf '# extra\n' > "$fixture/tools/extra.md"
expect_fail "tools がREADMEを除いて5分割であることを検査する" "$fixture" "tools の分割数が不一致"

fixture=$(make_fixture languages-count)
cp "$fixture/languages/rust/retention.md" "$fixture/languages/rust/extra.md"
expect_fail "languages が3言語それぞれ8ファイルであることを検査する" "$fixture" "languages の単位数が不一致"

fixture=$(make_fixture product-leak)
printf '\nSchemathesis を原則本文で名指しする。\n' >> "$fixture/principles/comment.md"
expect_fail "tools の採用行から得た製品名の principles 漏れを検出する" "$fixture" "台帳由来の製品名"

fixture=$(make_fixture product-boundary)
printf '\nSchemathesisLike は別の識別子である。\n' >> "$fixture/principles/comment.md"
expect_pass "製品名の部分文字列だけでは違反にしない" "$fixture"

fixture=$(make_fixture product-at-prefix)
printf '\n@typespec/openapi3 を原則本文で名指しする。\n' >> "$fixture/principles/comment.md"
expect_fail "@ で始まる製品名を正規名の境界で検出する" "$fixture" "台帳由来の製品名: @typespec/openapi3"

printf '\nテスト: %d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
