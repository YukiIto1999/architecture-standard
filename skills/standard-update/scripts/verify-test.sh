#!/usr/bin/env bash
set -euo pipefail

STANDARD_ROOT_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --standard-root)
      if [ -n "$STANDARD_ROOT_ARG" ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        printf 'FAIL: --standard-root には空でない path を一度だけ指定すること\nusage: %s [--standard-root ROOT]\n' "${BASH_SOURCE[0]##*/}" >&2
        exit 2
      fi
      STANDARD_ROOT_ARG="$2"
      shift 2
      ;;
    *)
      printf 'FAIL: 不明な引数: %s\nusage: %s [--standard-root ROOT]\n' "$1" "${BASH_SOURCE[0]##*/}" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -n "$STANDARD_ROOT_ARG" ]; then
  STANDARD_ROOT="$(CDPATH= cd -- "$STANDARD_ROOT_ARG" 2>/dev/null && pwd -P)" || {
    printf 'FAIL: --standard-root が存在する directory ではない: %s\n' "$STANDARD_ROOT_ARG" >&2
    exit 2
  }
else
  STANDARD_ROOT="$(git -C "$SCRIPT_DIR/../../.." rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'FAIL: git repository で実行すること\n' >&2
    exit 1
  }
fi
for standard_entry in README.md skills principles concerns structure tools languages process; do
  if [ ! -e "$STANDARD_ROOT/$standard_entry" ]; then
    printf 'FAIL: 標準 root に %s がない: %s\n' "$standard_entry" "$STANDARD_ROOT" >&2
    exit 2
  fi
done
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
      if [ -e "$TEST_ROOT" ]; then
        find "$TEST_ROOT" -type d -exec chmod u+w {} +
        rm -rf -- "$TEST_ROOT"
      fi
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

  mkdir -p "$fixture" || return 1
  cp -a \
    "$STANDARD_ROOT/README.md" \
    "$STANDARD_ROOT/skills" \
    "$STANDARD_ROOT/principles" \
    "$STANDARD_ROOT/concerns" \
    "$STANDARD_ROOT/structure" \
    "$STANDARD_ROOT/tools" \
    "$STANDARD_ROOT/languages" \
    "$STANDARD_ROOT/process" \
    "$fixture/" || return 1
  printf '%s\n' "$fixture"
}

run_driver() {
  local driver="$1"
  local cwd="$2"

  shift 2
  (
    cd "$cwd" || exit 1
    GIT_CEILING_DIRECTORIES="$TEST_ROOT" bash "$driver" "$@"
  ) 2>&1
}

run_verify() {
  local fixture="$1"
  local driver="${2:-$SCRIPT_DIR/verify.sh}"

  run_driver "$driver" "$TEST_ROOT" --standard-root "$fixture"
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
  local driver="${3:-$SCRIPT_DIR/verify.sh}"
  local output

  if output=$(run_verify "$fixture" "$driver"); then
    record_pass "$label"
  else
    record_fail "$label" "$output"
  fi
}

expect_fail() {
  local label="$1"
  local fixture="$2"
  local output
  local expected

  shift 2
  if output=$(run_verify "$fixture"); then
    record_fail "$label" "verify.sh が PASS した"
    return
  fi
  for expected in "$@"; do
    if ! printf '%s\n' "$output" | rg -qF "$expected"; then
      record_fail "$label" "期待した診断がない: $expected
$output"
      return
    fi
  done
  record_pass "$label"
}

expect_rejected_before_checks() {
  local label="$1"
  local expected_status="$2"
  local expected="$3"
  local driver="$4"
  local cwd="$5"
  local output
  local status

  shift 5
  output=$(run_driver "$driver" "$cwd" "$@") && status=0 || status=$?
  if [ "$status" != "$expected_status" ]; then
    record_fail "$label" "終了 status が $expected_status ではない: $status
$output"
  elif ! printf '%s\n' "$output" | rg -qF -- "$expected"; then
    record_fail "$label" "期待した診断がない: $expected
$output"
  elif printf '%s\n' "$output" | rg -qF '=== 1.'; then
    record_fail "$label" "拒否前に検査を開始した
$output"
  else
    record_pass "$label"
  fi
}

place_package_copy() {
  local root="$1"

  rm -rf -- "$root/skills/standard-update/scripts"
  mkdir -p "$root/skills/standard-update"
  cp -a "$SCRIPT_DIR" "$root/skills/standard-update/scripts"
}

poison_norm() {
  local root="$1"
  local overlap_line='検査用の「これは見出しではない引用でありそのまま重複判定に含まれる」文である。'

  printf '\n%s\n' "$overlap_line" >> "$root/principles/comment/no-code-explanation.md"
  printf '\n%s\n' "$overlap_line" >> "$root/concerns/privacy/minimize-and-expire.md"
  sed -i '0,/^### 根拠$/{s//### __SWAP__/}' "$root/concerns/privacy/minimize-and-expire.md"
  sed -i '0,/^### 完了条件$/{s//### 根拠/}' "$root/concerns/privacy/minimize-and-expire.md"
  sed -i 's/^### __SWAP__$/### 完了条件/' "$root/concerns/privacy/minimize-and-expire.md"
  printf '\n文脈の伝播は [observability](../observability/README.md) の「存在しない規律」に従う。\n' >> "$root/concerns/transaction/single-write-path.md"
  printf '\nZzqxy は、検査用の製品である。\n' >> "$root/concerns/experience/decision-simplicity.md"
  printf '\n二次の読みモデルを許す。\n' >> "$root/concerns/persistence/normalization.md"
}

fixture=$(make_fixture baseline)
expect_pass "現行ツリーを受理する" "$fixture"

fixture=$(make_fixture dynamic-concerns-ledger)
mkdir -p "$fixture/concerns/extra"
cp "$fixture/concerns/privacy/minimize-and-expire.md" "$fixture/concerns/extra/minimize-and-expire.md"
printf '# extra\n\n## 概要\n\n検査用の概念である。\n\n## 規律\n\n- [個人情報は最小化して載せ、期限で消す](./minimize-and-expire.md) — レビュー(検査用)\n' > "$fixture/concerns/extra/README.md"
sed -i '/^| \[accessibility\]/a | [extra](./extra/README.md) | 利用者面 | 台帳から追加した検査用の概念 |' "$fixture/concerns/README.md"
printf '検査用の横断規律は [concerns/extra](../../concerns/extra/README.md) に従う。\n' >> "$fixture/structure/core/domain.md"
expect_pass "concerns の台帳と実ファイルが揃った追加を受理する" "$fixture"


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


fixture=$(make_fixture process-ledger-added-pair)
printf '# extra\n' > "$fixture/process/extra.md"
sed -i '/^| \[migration\]/a | [extra](./extra.md) | 検査用の追加単位 |' "$fixture/process/README.md"
expect_pass "process の台帳と実ファイルが揃った追加を受理する" "$fixture"

fixture=$(make_fixture process-ledger-stray-file)
printf '# extra\n' > "$fixture/process/extra.md"
expect_fail "process の台帳に無い file を検出する" "$fixture" "process の台帳と実ファイルが不一致"

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
cp "$fixture/languages/rust/formation.md" "$fixture/languages/rust/extra.md"
expect_fail "languages ecosystem の台帳に無い file を検出する" "$fixture" "languages/rust の台帳と実ファイルが不一致"

fixture=$(make_fixture languages-top-stray)
printf '# extra\n' > "$fixture/languages/extra.md"
expect_fail "languages 直下の README 以外の file を検出する" "$fixture" "languages 直下に README 以外の file がある"

fixture=$(make_fixture language-discipline-table-missing)
sed -i '/^| connection | 効果を言語の効果型で表す |/d' "$fixture/languages/rust/inspection.md"
expect_fail "languages 本文の規律が対応表から欠落した場合を検査する" "$fixture" "languages/rust の規律対応表に欠落"

fixture=$(make_fixture language-discipline-table-extra)
sed -i '/^## 参照$/i | connection | 存在しない規律 | 検査用の対応 |\n' "$fixture/languages/csharp/inspection.md"
expect_fail "languages 本文にない規律が対応表へ混入した場合を検査する" "$fixture" "languages/csharp の規律対応表に余分"

fixture=$(make_fixture language-discipline-table-duplicate)
sed -i '/^| valibot | unknown で受けて一度だけ parse する |/p' "$fixture/languages/typescript/inspection.md"
expect_fail "languages 規律の対応表への重複登録を検査する" "$fixture" "languages/typescript の規律対応表に重複"

fixture=$(make_fixture language-discipline-body-fence)
sed -i '/^## 参照$/i ````text\n## fence 内の規律ではない見出し\n````\n' "$fixture/languages/rust/connection.md"
expect_pass "languages 本文の fenced code 内にある H2 を規律として扱わない" "$fixture"

fixture=$(make_fixture language-discipline-table-fence)
sed -i '/^## 規則と検証機構の対応$/a ~~~~text\n| connection | fence 内の規律ではない行 | 検査対象外 |\n## fence 内の H2\n~~~~' "$fixture/languages/csharp/inspection.md"
expect_pass "languages 対応表の fenced code 内にある pipe と H2 を無視して後続の実表を読む" "$fixture"

fixture=$(make_fixture tool-entry-h2-not-unit)
printf '\n## 検査用の用途\n\n用途は、検査で使う追加の用途である。\n採用は、Rust は sqlx である。\n判断基準は、検査で使うことである。\n撤回条件は、検査が終わることである。\n' >> "$fixture/languages/rust/sqlx.md"
expect_pass "languages のツール file で5節マーカーを持たない H2 を規律に数えない" "$fixture"

fixture=$(make_fixture tool-rule-sections-broken)
printf '\n## 検査用の壊れた規律\n\n### 要求\n\n検査用の要求である。\n' >> "$fixture/languages/rust/sqlx.md"
expect_fail "languages のツール file の規律単位の必須節欠落を検出する" "$fixture" "必須節が不正"

fixture=$(make_fixture tool-rule-move)
printf '\n## 検査用の移設規律\n\n### 要求\n\n検査用の要求である。\n\n### 根拠\n\n検査用の根拠である。\n\n### 完了条件\n\n検査用の完了条件である。\n\n### 禁止事項\n\n検査用の禁止である。\n\n### 行動\n\n検査用の行動である。\n' >> "$fixture/languages/rust/sqlx.md"
sed -i '/^## 参照$/i | sqlx | 検査用の移設規律 | 検査用の対応 |\n' "$fixture/languages/rust/inspection.md"
expect_pass "languages のツール file の規律と対応表の stem 行を一対一で照合する" "$fixture"

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
expect_pass "大きな languages 規律集合を同一集合として照合する" "$fixture"

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
printf '\n保存の形は [persistence](../persistence/append-only-facts.md) の「業務事実を保持期間の間は追記で残す」に従う。\n' >> "$fixture/concerns/transaction/single-write-path.md"
expect_pass "link 先の見出しと一致する鉤括弧引用を受理する" "$fixture"

fixture=$(make_fixture heading-citation-same-file)
printf '\n同じ file の「業務事実を保持期間の間は追記で残す」と [data](../../principles/data/README.md) に従う。\n' >> "$fixture/concerns/persistence/append-only-facts.md"
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
sed -i '/^撤回条件は、/d' "$fixture/languages/rust/sqlx.md"
expect_fail "languages のツール file の entry 4行の欠落を検出する" "$fixture" "entry の4行を欠くツール file あり"

fixture=$(make_fixture package-poisoned-norm)
poison_norm "$fixture"
place_package_copy "$fixture"
package_verify="$fixture/skills/standard-update/scripts/verify.sh"
fixture=$(make_fixture package-clean-target)
expect_pass ".git のない package が同梱する別の標準本文を読まず対象 root だけを検査する" "$fixture" "$package_verify"

fixture=$(make_fixture target-scripts-not-selected)
poison_norm "$fixture"
stub_scripts="$fixture/skills/standard-update/scripts"
mkdir -p "$stub_scripts"
printf 'exit 0\n' > "$stub_scripts/verify.sh"
printf 'console.log("candidates: 0");\n' > "$stub_scripts/verbatim-overlap.mjs"
printf 'console.log("violations: 0");\n' > "$stub_scripts/naming-registry-check.mjs"
printf 'console.log("citation violations: 0");\n' > "$stub_scripts/heading-citation-check.mjs"
printf 'BEGIN { print "violations: 0" }\n' > "$stub_scripts/discipline-sections.awk"
expect_fail "対象 root が置いた検査 script ではなく選択した package の script を実行する" "$fixture" \
  "逐語一致の候補あり" "tools に未登録の製品名指しあり" "正本の見出しに無い規律名" "規律単位の必須節が不正"

fixture=$(make_fixture package-without-git)
place_package_copy "$fixture"
valid_cwd=$(make_fixture rejected-root-cwd)
package_verify="$fixture/skills/standard-update/scripts/verify.sh"
expect_rejected_before_checks "root 省略時は package に Git repository がなければ別の標準を探さず失敗する" 1 "git repository で実行すること" "$package_verify" "$valid_cwd"
poison_norm "$fixture"
git -C "$fixture" init --quiet
if output=$(run_driver "$package_verify" "$valid_cwd"); then
  record_fail "root 省略時は package を含む repository を検査する" "verify.sh が PASS した"
elif ! printf '%s\n' "$output" | rg -qF "逐語一致の候補あり"; then
  record_fail "root 省略時は package を含む repository を検査する" "期待した診断がない: 逐語一致の候補あり
$output"
else
  record_pass "root 省略時は作業 directory ではなく package を含む repository を検査する"
fi

verify_driver="$SCRIPT_DIR/verify.sh"
empty_root="$TEST_ROOT/not-a-standard-root"
mkdir -p "$empty_root"
printf 'file\n' > "$TEST_ROOT/not-a-directory"
expect_rejected_before_checks "存在しない --standard-root を作業 directory へ置き換えない" 2 "存在する directory ではない" "$verify_driver" "$valid_cwd" --standard-root "$TEST_ROOT/missing-root"
expect_rejected_before_checks "file を --standard-root として受理しない" 2 "存在する directory ではない" "$verify_driver" "$valid_cwd" --standard-root "$TEST_ROOT/not-a-directory"
expect_rejected_before_checks "標準本文を持たない directory を --standard-root として受理しない" 2 "標準 root に README.md がない" "$verify_driver" "$valid_cwd" --standard-root "$empty_root"
expect_rejected_before_checks "--standard-root の値の欠落を拒否する" 2 "空でない path を一度だけ" "$verify_driver" "$valid_cwd" --standard-root
expect_rejected_before_checks "--standard-root の空の値を拒否する" 2 "空でない path を一度だけ" "$verify_driver" "$valid_cwd" --standard-root ""
expect_rejected_before_checks "--standard-root の重複を拒否する" 2 "空でない path を一度だけ" "$verify_driver" "$valid_cwd" --standard-root "$valid_cwd" --standard-root "$valid_cwd"
expect_rejected_before_checks "未知の引数を拒否する" 2 "不明な引数: --unknown" "$verify_driver" "$valid_cwd" --unknown
expect_rejected_before_checks "= 形の --standard-root を未知の引数として拒否する" 2 "不明な引数: --standard-root=$valid_cwd" "$verify_driver" "$valid_cwd" "--standard-root=$valid_cwd"

printf '\nテスト: %d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
