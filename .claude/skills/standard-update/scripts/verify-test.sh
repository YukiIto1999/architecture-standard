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
mkdir -p "$fixture/concerns/extra"
cp "$fixture/concerns/privacy/minimize-and-expire.md" "$fixture/concerns/extra/minimize-and-expire.md"
printf '# extra\n\n## 概要\n\n検査用の概念である。\n\n## 規律\n\n- [個人情報は最小化して載せ、期限で消す](./minimize-and-expire.md) — レビュー(検査用)\n' > "$fixture/concerns/extra/README.md"
sed -i '/^| \[accessibility\]/a | [extra](./extra/README.md) | 台帳から追加した検査用の概念 |' "$fixture/concerns/README.md"
sed -i 's/24概念/25概念/' "$fixture/README.md"
sed -i 's/・accessibility。/・accessibility・extra。/' \
  "$fixture/.claude/skills/standard-update/SKILL.md" \
  "$fixture/.claude/skills/standard-update/references/concerns.md"
printf '検査用の横断規律は [concerns/extra](../../concerns/extra/README.md) に従う。\n' >> "$fixture/structure/core/domain.md"
expect_pass "concerns の期待数を台帳から導出する" "$fixture"

fixture=$(make_fixture concept-three-way-mismatch)
sed -i 's/24概念/23概念/' "$fixture/README.md"
expect_fail "concerns の台帳・実ファイル・root 記載を三者照合する" "$fixture" "概念数が不一致"

fixture=$(make_fixture concept-table-scope)
printf '\n## 補助表\n\n| ファイル | 用途 |\n|---|---|\n| [effect](./effect/README.md) | 既存概念への補助参照 |\n' >> "$fixture/concerns/README.md"
expect_pass "concerns の概念台帳以外のファイル表を数えない" "$fixture"

fixture=$(make_fixture section-order)
sed -i '0,/^### 根拠$/{s//### __SWAP__/}' "$fixture/concerns/privacy/minimize-and-expire.md"
sed -i '0,/^### 完了条件$/{s//### 根拠/}' "$fixture/concerns/privacy/minimize-and-expire.md"
sed -i 's/^### __SWAP__$/### 完了条件/' "$fixture/concerns/privacy/minimize-and-expire.md"
expect_fail "規律単位内の必須節の順序違反を検出する" "$fixture" "必須節が不正"

fixture=$(make_fixture section-local-counts)
sed -i '0,/^### 根拠$/{s//### 完了条件/}' "$fixture/concerns/privacy/minimize-and-expire.md"
sed -i '0,/^### 完了条件$/{s//### 根拠/}' "$fixture/concerns/performance/measure-before-compare.md"
expect_fail "層合計が均衡していても規律単位内の重複と欠落を検出する" "$fixture" "必須節が不正"

fixture=$(make_fixture section-exclusion-scope)
printf '\n## 概要\n\nprinciples では全ての第2見出しが規律単位である。\n' >> "$fixture/principles/comment/no-code-explanation.md"
expect_fail "非単位節の除外を該当する領域だけに限定する" "$fixture" "必須節が不正"

fixture=$(make_fixture process-count)
printf '# extra\n' > "$fixture/process/extra.md"
sed -i '/^| \[migration\]/a | [extra](./extra.md) | 検査用の追加単位 |' "$fixture/process/README.md"
expect_fail "process の台帳と実ファイルが10単位であることを検査する" "$fixture" "process の単位数が不一致"

fixture=$(make_fixture process-table-scope)
printf '\n## 補助表\n\n| ファイル | 用途 |\n|---|---|\n| [audit](./audit.md) | 既存単位への補助参照 |\n' >> "$fixture/process/README.md"
expect_pass "process の単位台帳以外のファイル表を数えない" "$fixture"

fixture=$(make_fixture tools-division-valid)
expect_pass "tools の区分と台帳の一致を受理する" "$fixture"

fixture=$(make_fixture tools-top-stray)
printf '# extra\n' > "$fixture/tools/extra.md"
expect_fail "tools 直下の README 以外の file を検出する" "$fixture" "tools 直下に README 以外の file がある"

fixture=$(make_fixture tools-division-missing)
rm -r -- "$fixture/tools/services"
expect_fail "tools の区分の欠落を検出する" "$fixture" "tools の区分が不一致"

fixture=$(make_fixture tools-ledger-missing-row)
sed -i '/\[nx\.md\](\.\/nx\.md)/d' "$fixture/tools/build/README.md"
expect_fail "区分 README の台帳から行が欠けた場合を検出する" "$fixture" "tools/build の台帳と実ファイルが不一致"

fixture=$(make_fixture tools-ledger-stray-file)
printf '# extra\n用途は、検査用である。\n採用は、Extra である。\n' > "$fixture/tools/platforms/extra.md"
expect_fail "台帳に無いツール file を検出する" "$fixture" "tools/platforms の台帳と実ファイルが不一致"

fixture=$(make_fixture languages-count)
cp "$fixture/tools/rust/formation.md" "$fixture/tools/rust/extra.md"
expect_fail "ecosystem の台帳に無い file を検出する" "$fixture" "tools/rust の台帳と実ファイルが不一致"

fixture=$(make_fixture language-discipline-table-missing)
sed -i '/^| connection | 効果を言語の効果型で表す |/d' "$fixture/tools/rust/inspection.md"
expect_fail "language 本文の規律が対応表から欠落した場合を検査する" "$fixture" "tools/rust の規律対応表に欠落"

fixture=$(make_fixture language-discipline-table-extra)
sed -i '/^## 参照$/i | connection | 存在しない規律 | 検査用の対応 |\n' "$fixture/tools/csharp/inspection.md"
expect_fail "language 本文にない規律が対応表へ混入した場合を検査する" "$fixture" "tools/csharp の規律対応表に余分"

fixture=$(make_fixture language-discipline-table-duplicate)
sed -i '/^| valibot | unknown で受けて一度だけ parse する |/p' "$fixture/tools/typescript/inspection.md"
expect_fail "language 規律の対応表への重複登録を検査する" "$fixture" "tools/typescript の規律対応表に重複"

fixture=$(make_fixture language-discipline-body-fence)
sed -i '/^## 参照$/i ````text\n## fence 内の規律ではない見出し\n````\n' "$fixture/tools/rust/connection.md"
expect_pass "language 本文の fenced code 内にある H2 を規律として扱わない" "$fixture"

fixture=$(make_fixture language-discipline-table-fence)
sed -i '/^## 規則と検証機構の対応$/a ~~~~text\n| connection | fence 内の規律ではない行 | 検査対象外 |\n## fence 内の H2\n~~~~' "$fixture/tools/csharp/inspection.md"
expect_pass "language 対応表の fenced code 内にある pipe と H2 を無視して後続の実表を読む" "$fixture"

fixture=$(make_fixture tool-entry-h2-not-unit)
printf '\n## 検査用の用途\n\n用途は、検査で使う追加の用途である。\n採用は、Rust は sqlx である。\n判断基準は、検査で使うことである。\n撤回条件は、検査が終わることである。\n' >> "$fixture/tools/rust/sqlx.md"
expect_pass "5節マーカーを持たないツール file の H2 を規律に数えない" "$fixture"

fixture=$(make_fixture tool-rule-sections-broken)
printf '\n## 検査用の壊れた規律\n\n### 要求\n\n検査用の要求である。\n' >> "$fixture/tools/rust/sqlx.md"
expect_fail "ツール file の規律単位の必須節欠落を検出する" "$fixture" "必須節が不正"

fixture=$(make_fixture tool-rule-move)
printf '\n## 検査用の移設規律\n\n### 要求\n\n検査用の要求である。\n\n### 根拠\n\n検査用の根拠である。\n\n### 完了条件\n\n検査用の完了条件である。\n\n### 禁止事項\n\n検査用の禁止である。\n\n### 行動\n\n検査用の行動である。\n' >> "$fixture/tools/rust/sqlx.md"
sed -i '/^## 参照$/i | sqlx | 検査用の移設規律 | 検査用の対応 |\n' "$fixture/tools/rust/inspection.md"
expect_pass "ツール file の規律と対応表のツール stem 行を一対一で照合する" "$fixture"

fixture=$(make_fixture language-discipline-large-set)
large_body="$fixture/language-discipline-large-body"
large_table="$fixture/language-discipline-large-table"
large_inspection="$fixture/tools/typescript/inspection.md.new"
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
done < "$large_body" >> "$fixture/tools/typescript/translation.md"
awk -v rows="$large_table" '
  $0 == "## 参照" {
    while ((getline row < rows) > 0) print row
    close(rows)
    print ""
  }
  { print }
' "$fixture/tools/typescript/inspection.md" > "$large_inspection"
mv -- "$large_inspection" "$fixture/tools/typescript/inspection.md"
expect_pass "大きな language 規律集合を同一集合として照合する" "$fixture"

fixture=$(make_fixture concerns-product-leakage)
printf '\nPlaywright で表示を計測する。\n' >> "$fixture/concerns/experience/decision-simplicity.md"
expect_fail "concerns への検査製品の混入を検出する" "$fixture" "concerns に言語機構/方言が漏れている"

fixture=$(make_fixture product-leak)
printf '\nSchemathesis を原則本文で名指しする。\n' >> "$fixture/principles/comment/no-code-explanation.md"
expect_fail "tools の採用行から得た製品名の principles 漏れを検出する" "$fixture" "台帳由来の製品名"

fixture=$(make_fixture product-boundary)
printf '\nSchemathesisLike は別の識別子である。\n' >> "$fixture/principles/comment/no-code-explanation.md"
expect_pass "製品名の部分文字列だけでは違反にしない" "$fixture"

fixture=$(make_fixture product-at-prefix)
printf '\n@typespec/openapi3 を原則本文で名指しする。\n' >> "$fixture/principles/comment/no-code-explanation.md"
expect_fail "@ で始まる製品名を正規名の境界で検出する" "$fixture" "台帳由来の製品名: @typespec/openapi3"

fixture=$(make_fixture product-build-registry)
printf '\nNx は、task graph の orchestrator である。\n' >> "$fixture/structure/tests/layout.md"
expect_pass "build の採用名を tools registry に含める" "$fixture"

fixture=$(make_fixture structure-ledger-stray-file)
cp "$fixture/structure/core/domain.md" "$fixture/structure/core/stray.md"
expect_fail "台帳に無い structure 本文ファイルを検出する" "$fixture" "structure/core/stray"

fixture=$(make_fixture structure-ledger-missing-entry)
sed -i 's/| layout・methods・doubles |/| layout・methods |/' "$fixture/structure/README.md"
expect_fail "台帳から落ちた structure 本文ファイルを検出する" "$fixture" "structure/tests/doubles"

fixture=$(make_fixture structure-ledger-subdirectory)
cp "$fixture/structure/surfaces/viewer/state.md" "$fixture/structure/surfaces/server/state.md"
expect_fail "surface 単位の台帳の欠落を検出する" "$fixture" "structure/surfaces/server/state"

fixture=$(make_fixture structure-ledger-added-pair)
cp "$fixture/structure/core/domain.md" "$fixture/structure/core/policy.md"
sed -i 's/| layout・domain・application・infrastructure・composition |/| layout・domain・application・infrastructure・composition・policy |/' "$fixture/structure/README.md"
expect_pass "台帳と本文ファイルを揃えた追加を受理する" "$fixture"

fixture=$(make_fixture heading-citation-valid)
printf '\n保存の形は [persistence](../persistence/append-only-facts.md) の「事実を追記する形で残す」に従う。\n' >> "$fixture/concerns/transaction/single-write-path.md"
expect_pass "link 先の見出しと一致する鉤括弧引用を受理する" "$fixture"

fixture=$(make_fixture heading-citation-same-file)
printf '\n同じ file の「事実を追記する形で残す」と [data](../../principles/data/README.md) に従う。\n' >> "$fixture/concerns/persistence/append-only-facts.md"
expect_pass "同一 file 内の見出し引用を受理する" "$fixture"

fixture=$(make_fixture heading-citation-drift)
printf '\n文脈の伝播は [observability](../observability/README.md) の「存在しない規律」に従う。\n' >> "$fixture/concerns/transaction/single-write-path.md"
expect_fail "link 先の見出しに無い規律名の名指しを検出する" "$fixture" "正本の見出しに無い規律名"

fixture=$(make_fixture overlap-nonheading-quote)
overlap_line='検査用の「これは見出しではない引用でありそのまま重複判定に含まれる」文である。'
printf '\n%s\n' "$overlap_line" >> "$fixture/principles/comment/no-code-explanation.md"
printf '\n%s\n' "$overlap_line" >> "$fixture/concerns/privacy/minimize-and-expire.md"
expect_fail "見出しでない鉤括弧引用の逐語一致は検出する" "$fixture" "逐語一致の候補あり"

fixture=$(make_fixture vocabulary-legacy-term)
printf '\n二次の読みモデルを許す。\n' >> "$fixture/concerns/persistence/normalization.md"
expect_fail "統一済み語彙の旧表記を検出する" "$fixture" "統一済み語彙の旧表記"

fixture=$(make_fixture orphan-principle)
mkdir -p "$fixture/principles/orphan"
printf '# orphan\n' > "$fixture/principles/orphan/README.md"
expect_fail "下位の層から参照されない principles file を検出する" "$fixture" "下位の層から参照されない file"

fixture=$(make_fixture concept-ledger-missing-row)
sed -i '/minimize-and-expire/d' "$fixture/concerns/privacy/README.md"
expect_fail "概念台帳から欠けた規律 file を検出する" "$fixture" "概念フォルダの台帳が不一致"

fixture=$(make_fixture concept-ledger-name-drift)
sed -i 's/- \[個人情報は最小化して載せ、期限で消す\]/- [別の名の規律]/' "$fixture/concerns/privacy/README.md"
expect_fail "概念台帳の規律名と file の H2 の乖離を検出する" "$fixture" "概念フォルダの台帳が不一致"

fixture=$(make_fixture concept-ledger-missing-verification)
sed -i 's/^- \[個人情報は最小化して載せ、期限で消す\](\.\/minimize-and-expire\.md).*$/- [個人情報は最小化して載せ、期限で消す](.\/minimize-and-expire.md)/' "$fixture/concerns/privacy/README.md"
expect_fail "検証手段を欠く台帳行を検出する" "$fixture" "概念フォルダの台帳が不一致"

fixture=$(make_fixture tool-entry-line-missing)
sed -i '/^撤回条件は、/d' "$fixture/tools/rust/sqlx.md"
expect_fail "ツール file の entry 4行の欠落を検出する" "$fixture" "entry の4行を欠くツール file あり"

printf '\nテスト: %d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
