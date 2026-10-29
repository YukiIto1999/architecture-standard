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
# 所有する回帰用一時領域に限定した終了時の後始末
# - 対象: `$TEMP_BASE/architecture-standard-verify-test.*` に一致する既存の `TEST_ROOT`
# - 副作用: 対象内の全ディレクトリへの所有者書き込み権限の付与
# - 副作用: 対象ツリーの再帰削除
# - 戻り値: 対象外か不存在なら 0 で削除時は `rm` の終了 status
# - 失敗: 権限変更失敗時の実行中断
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

# 現行の標準一式を基にした独立した回帰用 root の作成
# - `$1`: `TEST_ROOT` 内に収まる fixture 名
# - 入力: 複製元となる `STANDARD_ROOT` の標準一式
# - 副作用: `$TEST_ROOT/$1` への fixture ツリーの作成
# - 出力: 標準出力への fixture root の path
# - 戻り値: 作成成功時の 0
# - 失敗: directory 作成失敗か複製失敗での戻り値 1
# - 失敗時の状態: 作成途中の fixture の残存
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

# 呼び出し元の作業 directory を変えない Bash driver の隔離実行
# - `$1`: `$2` から参照できる Bash driver の path
# - `$2`: driver 専用 subshell の作業 directory
# - `$3` 以降: driver へ渡す任意の引数
# - 入力: driver へ継承する標準入力
# - 実行環境: `TEST_ROOT` を上限とする Git repository 探索
# - 出力: driver の標準エラー出力を統合した標準出力
# - 戻り値: driver の終了 status
# - 失敗: 作業 directory への移動失敗時の終了 status 1
run_driver() {
  local driver="$1"
  local cwd="$2"

  shift 2
  (
    cd "$cwd" || exit 1
    GIT_CEILING_DIRECTORIES="$TEST_ROOT" bash "$driver" "$@"
  ) 2>&1
}

# fixture root を明示する検査 driver の起動
# - `$1`: `--standard-root` に渡す検査対象の fixture root
# - `$2`: 省略時か空文字列時に `$SCRIPT_DIR/verify.sh` を使う driver の path
# - 作業 directory: `TEST_ROOT` の subshell
# - 入力: driver へ継承する標準入力
# - 出力: driver の標準エラー出力を統合した標準出力
# - 戻り値: `run_driver` の終了 status
run_verify() {
  local fixture="$1"
  local driver="${2:-$SCRIPT_DIR/verify.sh}"

  run_driver "$driver" "$TEST_ROOT" --standard-root "$fixture"
}

# 全体集計へ加算する回帰ケースの成功記録
# - `$1`: 結果行に載せるテスト名
# - 出力: 標準出力への `PASS:` 行
# - 副作用: `passed` の 1 加算
# - 戻り値: 記録後の 0
record_pass() {
  printf 'PASS: %s\n' "$1"
  passed=$((passed + 1))
}

# 後続ケースを継続する回帰ケースの失敗記録
# - `$1`: 結果行に載せるテスト名
# - `$2`: 字下げして表示する失敗理由
# - 出力: 標準出力への失敗理由付きの `FAIL:` 行
# - 副作用: `failed` の 1 加算
# - 戻り値: 失敗の記録後も 0
record_fail() {
  printf 'FAIL: %s\n' "$1"
  printf '%s\n' "$2" | sed 's/^/  /'
  failed=$((failed + 1))
}

# 対象の標準本文を受理する検査実行の合否記録
# - `$1`: 結果行に載せるテスト名
# - `$2`: 検査対象の fixture root
# - `$3`: 省略時か空文字列時に `$SCRIPT_DIR/verify.sh` を使う driver の path
# - 収集: driver の標準エラー出力を統合した標準出力
# - 判定: driver の終了 status 0 による成功
# - 出力: 失敗時に収集結果を添える標準出力への合否記録
# - 副作用: 判定に対応する `passed` か `failed` の 1 加算
# - 戻り値: 判定結果にかかわらない 0
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

# 想定した診断を伴う標準本文の拒否の合否記録
# - `$1`: 結果行に載せるテスト名
# - `$2`: 検査対象の fixture root
# - `$3` 以降: 統合出力内で全件の固定文字列一致を求める任意の診断
# - 収集: 既定の `verify.sh` の標準エラー出力を統合した標準出力
# - 判定: `verify.sh` の非 0 終了
# - 出力: 不一致の理由を添える標準出力への合否記録
# - 副作用: 判定に対応する `passed` か `failed` の 1 加算
# - 戻り値: 判定結果にかかわらない 0
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

# 本文検査の開始前に引数を拒否する driver の合否記録
# - `$1`: 結果行に載せるテスト名
# - `$2`: 期待する終了 status
# - `$3`: 統合出力内で固定文字列一致を求める診断
# - `$4`: 実行する Bash driver の path
# - `$5`: driver 専用 subshell の作業 directory
# - `$6` 以降: driver へ渡す任意の引数
# - 収集: driver の標準エラー出力を統合した標準出力
# - 判定: 期待する終了 status への一致
# - 判定: 統合出力内の検査開始 marker `=== 1.` の不在
# - 出力: 不一致の理由を添える標準出力への合否記録
# - 副作用: 判定に対応する `passed` か `failed` の 1 加算
# - 戻り値: 判定結果にかかわらない 0
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

# 対象 root に属する検査 package の独立した複製
# - `$1`: 既存 package の置換を許す `TEST_ROOT` 配下の fixture root
# - 入力: 複製元となる `SCRIPT_DIR` の script 一式
# - 副作用: `$1/skills/standard-update/scripts` の既存ツリーの置換
# - 戻り値: 複製 command の終了 status
# - 失敗: 削除失敗か directory 作成失敗か複製失敗による実行中断
place_package_copy() {
  local root="$1"

  rm -rf -- "$root/skills/standard-update/scripts"
  mkdir -p "$root/skills/standard-update"
  cp -a "$SCRIPT_DIR" "$root/skills/standard-update/scripts"
}

# package と対象 root の取り違えを検出する標準本文への違反注入
# - `$1`: 本文の変更を許す `TEST_ROOT` 配下の fixture root
# - 副作用: 逐語重複の注入
# - 副作用: 必須節の順序違反の注入
# - 副作用: 存在しない見出し引用の注入
# - 副作用: 未登録製品名の注入
# - 副作用: 統一済み語彙の旧表記の注入
# - 戻り値: 最後の追記 command の終了 status
# - 失敗: 書き込み失敗か置換失敗による実行中断
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
expect_fail "@ で始まる製品名を正規名の境界で検出する" "$fixture" "@typespec/openapi3"

fixture=$(make_fixture product-adoption-declaration)
adoption_entry="$TEST_ROOT/product-adoption-declaration.md"
awk '
  /^採用は、/ {
    print "採用は、Schemathesis と"
    print "ContinuationProduct である。token は説明用の引数名である。"
    print "back-channel logout token の検証の分担は別の採用機構が受け持つ。"
    next
  }
  { print }
' "$fixture/tools/build/schemathesis.md" > "$adoption_entry"
mv -- "$adoption_entry" "$fixture/tools/build/schemathesis.md"
printf '\ntoken を引数名として使う。\n' >> "$fixture/principles/comment/no-code-explanation.md"
expect_pass "採用宣言に続く同一行と次行の説明中の token を製品名にしない" "$fixture"
printf '\nContinuationProduct を原則本文で名指しする。\n' >> "$fixture/principles/comment/no-code-explanation.md"
expect_fail "物理改行をまたぐ採用宣言の製品名の漏れを検出する" "$fixture" "ContinuationProduct"

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

fixture=$(make_fixture tool-entry-withdrawal-missing)
sed -i '/^撤回条件は、/d' "$fixture/languages/rust/sqlx.md"
expect_fail "languages のツール file の撤回条件の欠落を検出する" "$fixture"

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

if output=$(node --input-type=module - "$SCRIPT_DIR" "$TEST_ROOT" <<'NODE'
import { strict as assert, AssertionError } from "node:assert";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const [scripts, temp] = process.argv.slice(2);
const axes = ["formation", "translation", "connection", "coordination", "publication", "inspection", "conventions"];

/**
 * 実際の文書解析 CLI に渡す最小標準ツリーの作成
 * @param {string} name - 一時 root 内で一意の fixture 名
 * @param {Record<string, string[]>} documents - 相対パスをキーとする Markdown の行
 * @returns {string} 作成した標準 root の絶対パス
 * @throws {@link Error} fixture の書込み失敗
 */
function makeMarkdownRoot(name, documents) {
  const root = join(temp, `markdown-${name}`);
  for (const area of ["principles", "concerns", "structure", "tools", "languages", "process"]) {
    mkdirSync(join(root, area), { recursive: true });
  }
  writeFileSync(join(root, "README.md"), "");
  for (const language of ["rust", "csharp", "typescript"]) {
    mkdirSync(join(root, "languages", language));
    for (const axis of axes) writeFileSync(join(root, "languages", language, `${axis}.md`), "");
  }
  for (const [file, lines] of Object.entries(documents)) writeFileSync(join(root, file), lines.join("\n"));
  return root;
}

/**
 * 閉じ記号の判定を誤ると偽の本文を露出する文書の構築
 * @param {string} marker - 三文字か四文字の同じフェンス記号
 * @param {string[]} inside - フェンスの内部だけに現れる検査対象
 * @param {string[]} outside - 有効な閉じ記号の後の実際の本文
 * @returns {string[]} 元の行番号の期待値を計算できる文書の行
 */
function fencedDocument(marker, inside, outside) {
  const other = (marker[0] === "`" ? "~" : "`").repeat(marker.length);
  const close = marker + (marker.length > 3 ? marker[0] : "");
  return [
    ` \t${marker}markdown`,
    ...inside,
    marker.slice(1),
    ...inside,
    other,
    ...inside,
    `${marker}not-a-closer`,
    ...inside,
    ` \t${close} \t\r`,
    ...outside,
  ];
}

/**
 * 最小標準ツリーに対する実際の文書解析 CLI の実行
 * @param {string} script - 選択した package 内の解析 script の名前
 * @param {string} root - 検査する最小標準ツリー
 * @param {number} status - 契約上の終了 status
 * @returns {string} 診断の検証に使う標準出力
 * @throws {@link AssertionError} CLI の起動失敗
 * @throws {@link AssertionError} 終了 status の不一致
 */
function analyze(script, root, status) {
  const run = spawnSync(process.execPath, [join(scripts, script), "--standard-root", root], { encoding: "utf8" });
  assert.ifError(run.error);
  assert.equal(run.status, status, `${script}\n${run.stderr}\n${run.stdout}`);
  return run.stdout;
}

for (const marker of ["```", "~~~", "````", "~~~~"]) {
  const label = `${marker[0] === "`" ? "backtick" : "tilde"}-${marker.length}`;
  const fakeHeading = "囲いの内部だけにある見出し";
  const realHeading = "閉じ記号の後の実見出し";
  const invalidCitation = `[規律](../principles/target.md) の「${fakeHeading}」に従う。`;
  const citationLines = fencedDocument(marker, [
    "[規律](../principles/target.md) の「存在しない引用」に従う。",
  ], [
    `[規律](../principles/target.md) の「${realHeading}」に従う。`,
    invalidCitation,
  ]);
  const headingRoot = makeMarkdownRoot(`${label}-heading`, {
    "principles/target.md": fencedDocument(marker, [`## ${fakeHeading}`], [`## ${realHeading}`]),
    "concerns/source.md": citationLines,
  });
  const headingOutput = analyze("heading-citation-check.mjs", headingRoot, 1);
  assert.match(headingOutput, /^citation violations: 1$/m, label);
  assert.deepEqual(
    [...headingOutput.matchAll(/^concerns\/source\.md:(\d+):/gm)].map((match) => Number(match[1])),
    [citationLines.indexOf(invalidCitation) + 1],
    label,
  );

  const namingLines = fencedDocument(marker, ["HiddenUnregistered である。"], [
    "RegisteredAfterClosure である。",
    "VisibleUnregistered である。",
  ]);
  const namingRoot = makeMarkdownRoot(`${label}-naming`, {
    "tools/catalog.md": fencedDocument(marker, [
      "## FencedRegistryName",
      "採用は、VisibleUnregistered である。",
    ], ["## RegisteredAfterClosure"]),
    "concerns/source.md": namingLines,
  });
  const namingOutput = analyze("naming-registry-check.mjs", namingRoot, 0);
  assert.match(namingOutput, /^violations: 1$/m, label);
  assert.deepEqual(
    [...namingOutput.matchAll(/^([^\t\r\n]+):(\d+)\t([^\t\r\n]+)\t".*"$/gm)].map((match) => ({
      file: match[1], line: Number(match[2]), token: match[3],
    })),
    [{ file: "concerns/source.md", line: namingLines.indexOf("VisibleUnregistered である。") + 1, token: "VisibleUnregistered" }],
    label,
  );

  const hiddenOverlap = "囲いの中の例文は十分に長くても逐語一致検査の対象には含めない。";
  const realOverlap = "閉じたフェンスに続く実際の重複本文は元の行番号で検査する。";
  const fakeOverlapHeading = "コードの例にしか存在しない長い見出しの引用は一致検査の対象";
  const realOverlapHeading = "本文に実在する長い見出しの引用は一致検査の対象外";
  const fakeQuote = `「${fakeOverlapHeading}」`;
  const realQuote = `「${realOverlapHeading}」`;
  const principleLines = fencedDocument(marker, [hiddenOverlap, `## ${fakeOverlapHeading}`], [
    `## ${realOverlapHeading}`, realOverlap, fakeQuote, realQuote,
  ]);
  const concernLines = fencedDocument(marker, [hiddenOverlap], [realOverlap, fakeQuote, realQuote]);
  const overlapRoot = makeMarkdownRoot(`${label}-overlap`, {
    "principles/source.md": principleLines,
    "concerns/source.md": concernLines,
  });
  const overlapOutput = analyze("verbatim-overlap.mjs", overlapRoot, 0);
  assert.match(overlapOutput, /^candidates: 2$/m, label);
  const overlaps = [...overlapOutput.matchAll(/^(\d+)\t([^:\t\r\n]+):(\d+)\t<->\t([^:\t\r\n]+):(\d+)\t"(.*)"$/gm)];
  assert.deepEqual(overlaps.map((match) => ({
    length: Number(match[1]),
    concernFile: match[2],
    concernLine: Number(match[3]),
    principleFile: match[4],
    principleLine: Number(match[5]),
    text: match[6],
  })), [realOverlap, fakeQuote].sort((a, b) => b.length - a.length).map((text) => ({
    length: text.length,
    concernFile: "concerns/source.md",
    concernLine: concernLines.indexOf(text) + 1,
    principleFile: "principles/source.md",
    principleLine: principleLines.indexOf(text) + 1,
    text,
  })), label);

  const unclosedRoot = makeMarkdownRoot(`${label}-unclosed`, {
    "principles/source.md": [marker, hiddenOverlap],
    "concerns/source.md": [marker, hiddenOverlap, "HiddenUnregistered である。", invalidCitation],
  });
  assert.match(analyze("heading-citation-check.mjs", unclosedRoot, 0), /^citation violations: 0$/m, label);
  assert.match(analyze("naming-registry-check.mjs", unclosedRoot, 0), /^violations: 0$/m, label);
  assert.match(analyze("verbatim-overlap.mjs", unclosedRoot, 0), /^candidates: 0$/m, label);
}

const knownCategoryRoot = makeMarkdownRoot("declared-size-and-multiline-adoption", {
  "tools/catalog.md": [
    "# FirstProduct",
    "用途は、検査用である。",
    "採用は、FirstProduct である。",
    "追加の採用は ContinuationProduct である。",
    "back-channel logout token の分担の説明語は ExplanationTerm とする。",
    "判断基準は、検査用である。",
    "撤回条件は、検査の終了である。",
  ],
  "concerns/source.md": [
    "これらは Tiny と Huge である。",
    "取得する機構は ContinuationProduct である。",
    "登録のない機構は UnregisteredProduct である。",
    "採用していない説明語は ExplanationTerm である。",
  ],
});
mkdirSync(join(knownCategoryRoot, "structure/tests"));
writeFileSync(join(knownCategoryRoot, "structure/tests/layout.md"), [
  "## サイズによる配置",
  "Tiny は、プロセス内の検査とする。",
  "Huge は、外部環境の検査とする。",
].join("\n"));
const categoryOutput = analyze("naming-registry-check.mjs", knownCategoryRoot, 0);
assert.match(categoryOutput, /^violations: 2$/m);
assert.deepEqual(
  [...categoryOutput.matchAll(/^([^\t\r\n]+):(\d+)\t([^\t\r\n]+)\t".*"$/gm)].map((match) => ({
    file: match[1], line: Number(match[2]), token: match[3],
  })),
  [
    { file: "concerns/source.md", line: 3, token: "UnregisteredProduct" },
    { file: "concerns/source.md", line: 4, token: "ExplanationTerm" },
  ],
);

const citationSource = [
  "[connection](./connection.md) の「ReferenceOnlyMechanism」は、参照先の規律である。",
  "[connection](./connection.md) の「ReferenceOnlyMechanism」と AdjacentUnregistered は、別の指定である。",
  "[connection](./connection.md) の「QuotedUnregistered」は、存在しない規律名である。",
  "ReferenceOnlyMechanism は、参照でない直接の指定である。",
];
const citedProductRoot = makeMarkdownRoot("product-candidates-beside-rule-citations", {
  "languages/csharp/connection.md": ["## ReferenceOnlyMechanism"],
  "languages/csharp/formation.md": citationSource,
});
const citedProductOutput = analyze("naming-registry-check.mjs", citedProductRoot, 0);
assert.match(citedProductOutput, /^violations: 3$/m);
assert.deepEqual(
  [...citedProductOutput.matchAll(/^([^\t\r\n]+):(\d+)\t([^\t\r\n]+)\t".*"$/gm)].map((match) => ({
    file: match[1], line: Number(match[2]), token: match[3],
  })),
  [
    { file: "languages/csharp/formation.md", line: 2, token: "AdjacentUnregistered" },
    { file: "languages/csharp/formation.md", line: 3, token: "QuotedUnregistered" },
    { file: "languages/csharp/formation.md", line: 4, token: "ReferenceOnlyMechanism" },
  ],
);

const genuineOverlap = "引用の外にある十分に長い本文の一致は検出する。";
const quoteBoundaryRoot = makeMarkdownRoot("quoted-headings-are-not-filename-text", {
  "principles/left-operations.md": [
    "## 原則側の引用見出し",
    "原則は「関心側の引用見出し」に従う。",
    `${genuineOverlap}「関心側の引用見出し」原則の補足`,
  ],
  "concerns/right-operations.md": [
    "## 関心側の引用見出し",
    "関心は「原則側の引用見出し」に従う。",
    `${genuineOverlap}「原則側の引用見出し」関心の補足`,
  ],
});
const quoteBoundaryOutput = analyze("verbatim-overlap.mjs", quoteBoundaryRoot, 0);
assert.match(quoteBoundaryOutput, /^candidates: 1$/m);
assert.equal(quoteBoundaryOutput.includes("\u0000"), false);
assert.deepEqual(
  [...quoteBoundaryOutput.matchAll(/^(\d+)\t([^:\t\r\n]+):(\d+)\t<->\t([^:\t\r\n]+):(\d+)\t"(.*)"$/gm)].map((match) => ({
    concernLine: Number(match[3]), principleLine: Number(match[5]), text: match[6],
  })),
  [{ concernLine: 3, principleLine: 3, text: genuineOverlap }],
);

const referenceSymbol = "shared-consistency-boundary-reference";
const referenceHeading = "参照する規律の十分に長い正式な見出しの名前";
const linkedRequirement = "規範として使うリンクの文言の一致は検出する。";
const referenceBoundaryRoot = makeMarkdownRoot("reference-symbols-are-not-body", {
  [`principles/${referenceSymbol}.md`]: [`## ${referenceHeading}`],
  "principles/left-reference.md": [
    "## 原則側の参照元",
    `集約の約束は [${referenceSymbol}](./${referenceSymbol}.md) の「${referenceHeading}」に従う。`,
    `左の配置は [principles/${referenceSymbol}](./${referenceSymbol}.md) を基準にする。`,
    `左の参照先は [${referenceHeading}](./${referenceSymbol}.md) にある。`,
    `参照前にある短い本文断片[${referenceSymbol}](./${referenceSymbol}.md)参照後にある短い本文断片`,
    `${genuineOverlap}[${referenceSymbol}](./${referenceSymbol}.md)原則の補足`,
    `[${linkedRequirement}](./${referenceSymbol}.md)原則の補足`,
  ],
  "concerns/right-reference.md": [
    "## 関心側の参照元",
    `確定の単位は [${referenceSymbol}](../principles/${referenceSymbol}.md) の「${referenceHeading}」に委ねる。`,
    `右の配置は [principles/${referenceSymbol}](../principles/${referenceSymbol}.md) に合わせる。`,
    `右の参照先は [${referenceHeading}](../principles/${referenceSymbol}.md) を指す。`,
    `参照前にある短い本文断片[${referenceSymbol}](../principles/${referenceSymbol}.md)参照後にある短い本文断片`,
    `${genuineOverlap}[${referenceSymbol}](../principles/${referenceSymbol}.md)関心の補足`,
    `[${linkedRequirement}](../principles/${referenceSymbol}.md)関心の補足`,
  ],
});
const referenceBoundaryOutput = analyze("verbatim-overlap.mjs", referenceBoundaryRoot, 0);
assert.match(referenceBoundaryOutput, /^candidates: 2$/m);
assert.equal(referenceBoundaryOutput.includes("\u0000"), false);
assert.deepEqual(
  [...referenceBoundaryOutput.matchAll(/^(\d+)\t([^:\t\r\n]+):(\d+)\t<->\t([^:\t\r\n]+):(\d+)\t"(.*)"$/gm)].map((match) => ({
    concernLine: Number(match[3]), principleLine: Number(match[5]), text: match[6],
  })).sort((left, right) => left.concernLine - right.concernLine),
  [
    { concernLine: 6, principleLine: 6, text: genuineOverlap },
    { concernLine: 7, principleLine: 7, text: linkedRequirement },
  ],
);
NODE
); then
  record_pass "文書解析 CLI がフェンスの境界と元の診断行番号を共有する"
else
  record_fail "文書解析 CLI がフェンスの境界と元の診断行番号を共有する" "$output"
fi

package_driver="$SCRIPT_DIR/skill-package-check.sh"
expect_rejected_before_checks "package checker は存在しない root を別の root へ置き換えない" 2 "$TEST_ROOT/missing-root" "$package_driver" "$valid_cwd" --standard-root "$TEST_ROOT/missing-root"
expect_rejected_before_checks "package checker は未知の引数を拒否する" 2 "--unknown" "$package_driver" "$valid_cwd" --unknown
expect_rejected_before_checks "verify-test は存在しない root を別の root へ置き換えない" 2 "$TEST_ROOT/missing-root" "$SCRIPT_DIR/verify-test.sh" "$valid_cwd" --standard-root "$TEST_ROOT/missing-root"
expect_rejected_before_checks "verify-test は root の重複を拒否する" 2 "--standard-root" "$SCRIPT_DIR/verify-test.sh" "$valid_cwd" --standard-root "$valid_cwd" --standard-root "$valid_cwd"

detached_scripts="$TEST_ROOT/detached-package/scripts"
mkdir -p "$detached_scripts"
cp -a "$SCRIPT_DIR/." "$detached_scripts/"
expect_pass "Git のない package から指定した標準 root の Skill を検査できる" "$valid_cwd" "$detached_scripts/skill-package-check.sh"
fixture=$(make_fixture package-missing-skill)
rm -- "$fixture/skills/standard-apply/SKILL.md"
if output=$(run_driver "$detached_scripts/skill-package-check.sh" "$valid_cwd" --standard-root "$fixture"); then
  record_fail "指定した標準 root の Skill 欠落を検出する" "$output"
elif ! printf '%s\n' "$output" | rg -qF 'standard-apply'; then
  record_fail "欠落した Skill を特定する" "$output"
else
  record_pass "指定した標準 root の Skill 欠落を検出する"
fi
fixture=$(make_fixture package-wrong-name)
sed -i 's/^name: standard-apply$/name: wrong-name/' "$fixture/skills/standard-apply/SKILL.md"
if output=$(run_driver "$package_driver" "$valid_cwd" --standard-root "$fixture"); then
  record_fail "frontmatter の name と Skill 名の不一致を拒否する" "$output"
else
  record_pass "frontmatter の name と Skill 名の不一致を拒否する"
fi

BASH_PATH=$(command -v bash)
for missing_command in node fd; do
  limited_path="$TEST_ROOT/path-without-$missing_command"
  mkdir -p "$limited_path"
  for command_name in bash git rg fd awk sed find wc tr head tail sort diff dirname paste basename cut node; do
    [ "$command_name" = "$missing_command" ] && continue
    ln -s "$(command -v "$command_name")" "$limited_path/$command_name"
  done
  status=0
  output=$(PATH="$limited_path" "$BASH_PATH" "$SCRIPT_DIR/verify.sh" --standard-root "$valid_cwd" 2>&1) || status=$?
  if [ "$status" -eq 1 ] && printf '%s\n' "$output" | rg -qF "$missing_command"; then
    record_pass "$missing_command 欠落で verifier が fail closed となる"
  else
    record_fail "$missing_command 欠落で verifier が fail closed となる" "status=$status
$output"
  fi
done

mktemp_status=0
output=$(MKTEMP_FAILURE_PROBE="$TEST_ROOT/mktemp-followup" timeout 10 "$BASH_PATH" -c '
  mktemp() { return 1; }
  mkdir() { printf "mkdir\n" >> "$MKTEMP_FAILURE_PROBE"; return 91; }
  cp() { printf "cp\n" >> "$MKTEMP_FAILURE_PROBE"; return 92; }
  rm() { printf "rm\n" >> "$MKTEMP_FAILURE_PROBE"; return 94; }
  export -f mktemp mkdir cp rm
  bash "$1" --standard-root "$2"
' probe "$SCRIPT_DIR/verify-test.sh" "$valid_cwd" 2>&1) || mktemp_status=$?
if [ "$mktemp_status" -eq 1 ] && [ ! -e "$TEST_ROOT/mktemp-followup" ]; then
  record_pass "mktemp 失敗時に作成・コピー・削除を行わず終了する"
else
  record_fail "mktemp 失敗時に作成・コピー・削除を行わず終了する" "status=$mktemp_status
$output"
fi
printf '\nテスト: %d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
  exit 0
fi
exit 1
