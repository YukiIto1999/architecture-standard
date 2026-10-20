#!/usr/bin/env bash
set -uo pipefail

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

required_commands=(rg fd awk sed find wc tr head tail sort diff dirname paste cut node)
[ -n "$STANDARD_ROOT_ARG" ] || required_commands+=(git)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'FAIL: missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -n "$STANDARD_ROOT_ARG" ]; then
  STANDARD_ROOT="$(CDPATH= cd -- "$STANDARD_ROOT_ARG" 2>/dev/null && pwd -P)" || {
    printf 'FAIL: --standard-root が存在する directory ではない: %s\n' "$STANDARD_ROOT_ARG" >&2
    exit 2
  }
else
  STANDARD_ROOT=$(git -C "$SCRIPT_DIR/../../.." rev-parse --show-toplevel 2>/dev/null) || {
    printf 'FAIL: git repository で実行すること\n' >&2
    exit 1
  }
fi
for standard_entry in README.md principles concerns structure tools languages process; do
  if [ ! -e "$STANDARD_ROOT/$standard_entry" ]; then
    printf 'FAIL: 標準 root に %s がない: %s\n' "$standard_entry" "$STANDARD_ROOT" >&2
    exit 2
  fi
done
cd "$STANDARD_ROOT" || exit 1

FAILED=0

# 検査項目の成功結果の表示
# - `$1`: 成功と判定した検査項目のメッセージ
# - 出力: `PASS:` を付けたメッセージの標準出力
# - 戻り値: echo の終了 status
pass() { echo "PASS: $1"; }

# 総合判定へ反映する検査項目の失敗の記録
# - `$1`: 失敗と判定した検査項目のメッセージ
# - 出力: `FAIL:` を付けたメッセージの標準出力
# - 状態: 総合判定を保持する `FAILED` の 1 への更新
# - 戻り値: メッセージ出力の成否に関係しない終了 status 0
fail() { echo "FAIL: $1"; FAILED=1; }

# 同階層以上の見出しまでの表からの一列の抽出
# - `$1`: Markdown の入力 file
# - `$2`: 節を開く見出しの正規表現
# - `$3`: 1 から数える列の位置
# - 出力: 表の区切り行に続く各行の前後空白を除いた列値
# - 戻り値: 入力 file の読込失敗を含む awk の終了 status
markdown_table_cells() {
  awk -v heading="$2" -v column="$3" '
    # 節の終了境界の比較に使う ATX 見出しの深さの取得
    # - `line`: 先頭の `#` に続く本文を持つ見出し行
    # - 戻り値: 先頭に連続する `#` の個数
    function heading_level(line) { return match(line, /[^#]/) - 1 }

    # 表の照合値からの周辺空白の除去
    # - `value`: 前後の空白を除くセル値
    # - 戻り値: 前後の空白を除いたセル値
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    $0 ~ heading { in_section = 1; level = heading_level($0); in_body = 0; next }
    in_section && /^#+[[:space:]]/ && heading_level($0) <= level { in_section = 0 }
    !in_section { next }
    /^\|[-:|[:space:]]+$/ { in_body = 1; next }
    in_body && /^\|/ { split($0, cells, "|"); print trim(cells[column + 1]); next }
    { in_body = 0 }
  ' "$1"
}

# 台帳件数の比較に使う非空行数の集計
# - 標準入力: 改行区切りの集計対象
# - 出力: 空白のみの行を含む非空行の件数
# - 戻り値: 集計 pipeline の終了 status
count_lines() {
  sed '/^$/d' | wc -l | tr -d ' '
}

# inspection 対応表との照合に使う本文規律レコードの抽出
# - `$1`: `languages/` 直下の走査対象の言語 directory 名
# - 前提: 標準 root を作業 directory とする呼出し
# - 入力: 言語 directory 直下の README.md を除く Markdown file
# - 抽出対象: code fence 外に `### 要求` を持つ `##` 規律見出し
# - 除外: `概要`・`規則と検証機構の対応`・`参照` の見出し
# - 出力: `軸名 | 規律名<TAB>file:行番号` 形式の規律レコード
# - 戻り値: 対象 file がない場合の終了 status 0
# - 戻り値: 対象 file がある場合の最後の awk 呼出しの終了 status
# - 失敗: 探索失敗や途中の awk 失敗の非集約
language_body_discipline_records() {
  local language="$1"
  local file
  local axis

  while IFS= read -r file; do
    axis=${file##*/}
    axis=${axis%.md}
    awk -v axis="$axis" '
      # code fence 候補の先頭記号数の取得
      # - `line`: 先頭の fence 記号列を測る文字列
      # - ローカル `marker`: 先頭記号の作業領域
      # - ローカル `cursor`: 記号列の走査位置
      # - 戻り値: 先頭に連続する backtick か tilde の個数
      function fence_run_length(line, marker, cursor) {
        marker = substr(line, 1, 1)
        if (marker != "`" && marker != "~") return 0
        for (cursor = 1; substr(line, cursor, 1) == marker; cursor++);
        return cursor - 1
      }

      # 本文規律の抽出から除外する code fence 行の判定
      # - `line`: fence 状態を適用する Markdown 行
      # - ローカル `trimmed`: 行頭空白を除く作業領域
      # - ローカル `marker`: 判定対象の先頭記号
      # - ローカル `run_length`: 先頭記号の連続数
      # - ローカル `remainder`: 閉じ fence 候補の記号列に続く文字列
      # - 入力状態: `in_fence`・`fence_marker`・`fence_length` に保持する現在の fence 境界
      # - 状態: fence 開始時の境界状態の設定
      # - 状態: fence 終了時の境界状態の消去
      # - 戻り値: fence 境界行か fence 内の行の場合の 1
      # - 戻り値: fence 外の通常行の場合の 0
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

      # 次の見出しへ持ち越さない規律候補の破棄
      # - 状態: 未出力レコードを保持する `pending` の空文字への初期化
      function flush_pending() {
        pending = ""
      }

      /^## / {
        flush_pending()
        discipline = substr($0, 4)
        if (discipline == "概要" || discipline == "規則と検証機構の対応" || discipline == "参照") {
          next
        }
        pending = sprintf("%s | %s\t%s:%d", axis, discipline, FILENAME, FNR)
        next
      }

      /^### 要求[[:space:]]*$/ && pending != "" {
        print pending
        pending = ""
      }
    ' "$file"
  done < <(find "languages/$language" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)
}

# 本文規律との照合に使う inspection 対応表レコードの抽出
# - `$1`: `languages/` 直下の対象の言語 directory 名
# - 前提: 標準 root を作業 directory とする呼出し
# - 入力: `languages/$1/inspection.md`
# - 抽出対象: code fence 外の `規則と検証機構の対応` 節の表
# - 出力: `軸名 | 規律名<TAB>file:行番号` 形式の規律レコード
# - 戻り値: 入力 file の読込失敗を含む awk の終了 status
language_inspection_discipline_records() {
  local language="$1"

  awk '
    # 対応表の照合値からの周辺空白の除去
    # - `value`: 前後の空白を除くセル値
    # - 戻り値: 前後の空白を除いたセル値
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    # code fence 候補の先頭記号数の取得
    # - `line`: 先頭の fence 記号列を測る文字列
    # - ローカル `marker`: 先頭記号の作業領域
    # - ローカル `cursor`: 記号列の走査位置
    # - 戻り値: 先頭に連続する backtick か tilde の個数
    function fence_run_length(line, marker, cursor) {
      marker = substr(line, 1, 1)
      if (marker != "`" && marker != "~") return 0
      for (cursor = 1; substr(line, cursor, 1) == marker; cursor++);
      return cursor - 1
    }

    # 対応表の抽出から除外する code fence 行の判定
    # - `line`: fence 状態を適用する Markdown 行
    # - ローカル `trimmed`: 行頭空白を除く作業領域
    # - ローカル `marker`: 判定対象の先頭記号
    # - ローカル `run_length`: 先頭記号の連続数
    # - ローカル `remainder`: 閉じ fence 候補の記号列に続く文字列
    # - 入力状態: `in_fence`・`fence_marker`・`fence_length` に保持する現在の fence 境界
    # - 状態: fence 開始時の境界状態の設定
    # - 状態: fence 終了時の境界状態の消去
    # - 戻り値: fence 境界行か fence 内の行の場合の 1
    # - 戻り値: fence 外の通常行の場合の 0
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
      if (axis == "" || axis == "ファイル" || axis ~ /^-+$/) {
        next
      }
      printf "%s | %s\t%s:%d\n", axis, discipline, FILENAME, FNR
    }
  ' "languages/$language/inspection.md"
}

# 規律レコード間の集合比較に使う一意なキー一覧の抽出
# - 標準入力: 第1列を照合キーとするタブ区切りの規律レコード
# - 出力: 重複を除いた非空キーのソート済み一覧
# - 戻り値: 抽出 pipeline の終了 status
record_keys() {
  cut -f1 | sed '/^$/d' | sort -u
}

# 出典診断の対象にする重複規律キーの抽出
# - 標準入力: 第1列を照合キーとするタブ区切りの規律レコード
# - 出力: 複数回出現する非空キーを各1回並べたソート済み一覧
# - 戻り値: 抽出 pipeline の終了 status
duplicate_record_keys() {
  cut -f1 \
    | sed '/^$/d' \
    | sort \
    | awk '
        previous == $0 && !reported { print; reported = 1; next }
        previous != $0 { previous = $0; reported = 0 }
      '
}

# 対応表の欠落や余分な規律を示す差分候補の抽出
# - `$1`: 改行区切りの差分候補
# - `$2`: 改行区切りの除外対象
# - 出力: 除外対象に同一行がない非空候補の入力順の一覧
# - 戻り値: 最終反復の終了 status
# - 戻り値: 候補がない場合の終了 status 0
set_difference() {
  local candidates="$1"
  local existing="$2"
  local candidate existing_key
  local -A existing_keys=()

  while IFS= read -r existing_key; do
    [ -z "$existing_key" ] && continue
    existing_keys["$existing_key"]=1
  done <<< "$existing"
  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    if [ -z "${existing_keys["$candidate"]+present}" ]; then
      printf '%s\n' "$candidate"
    fi
  done <<< "$candidates"
}

# 規律キーごとの診断用出典一覧の表示
# - `$1`: `キー<TAB>file:行番号` 形式の改行区切りの規律レコード
# - `$2`: 表示対象の改行区切りの照合キー
# - 出力: 非空キーごとの字下げ済み出典一覧の標準出力
# - 戻り値: 最終反復の終了 status
# - 戻り値: 表示対象がない場合の終了 status 0
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

# 製品名漏出検査の対象外トークンの判定
# - `$1`: 採用宣言から抽出した製品名候補のトークン
# - 戻り値: 除外リストへの完全一致時の終了 status 0
# - 戻り値: 除外リストへの不一致時の終了 status 1
is_non_product_token() {
  case "$1" in
    "API"|"HTTP"|"Build"|"C#"|"CI"|"CSS"|"Core"|"JSON"|"JSON-RPC"|"Minimal"|"NET"|"OpenAPI"|"Rust"|"SPDX"|"TypeScript"|\
    "analyzer"|"backend"|"client"|"ID"|"collector"|"commit"|"tree"|"companion"|"cookie"|"core"|"coverage"|"desktop"|"for"|"framing"|"generation"|"generator"|"handler"|"library"|"mobile"|"node"|"one-time"|"package"|"plugin"|"project"|"provider"|"queue"|"record"|"repository"|"root"|"runtime"|"rust"|"schema"|"script"|"sealed"|"source"|"tests/"|"tools"|"type-aware"|"union"|"up"|"v1"|"v8")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

echo "=== 1. broken links(principles/concerns/structure/tools/languages/process + README。file と directory の両方) ==="
broken=0
mapfile -d '' -t linked_files < <(fd . principles concerns structure tools languages process -e md --print0 2>/dev/null; printf 'README.md\0')
while IFS= read -r -d '' f && IFS= read -r l; do
  d=${f%/*}
  [ "$d" != "$f" ] || d=.
  l=${l%%#*}
  [ -z "$l" ] && continue
  [ -e "$d/$l" ] || { echo "  broken: $f -> $l"; broken=1; }
done < <(rg --with-filename --no-heading --no-column --null -oN '\]\((\.[^)]*)\)' -r '$1' -- "${linked_files[@]}" 2>/dev/null)
if [ "$broken" = 0 ]; then pass "リンク切れなし"; else fail "リンク切れあり(上記 broken 行)"; fi

echo
echo "=== 2. 単位ごとの必須5節(principles/concerns/言語 ecosystem。例は任意) ==="
mapfile -d '' discipline_files < <(
  find principles concerns -mindepth 2 -maxdepth 2 -type f -name '*.md' ! -name 'README.md' -print0
  find languages/rust languages/csharp languages/typescript tools/build tools/platforms tools/services -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print0
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
if rg -nP '\b(sqlx|tokio|axum|tower|serde|Dapper|Npgsql|EF Core|zod|valibot|ts-results-es|SolidJS|Tailwind|Vite|VSCode|fred|apalis|PGMQ|clap|NSwag|Wolverine|Photino|MAUI|Kobalte|ON CONFLICT|ON DUPLICATE|StreamJsonRpc|vscode-jsonrpc|createResource|createSignal|actor framework|Playwright|TypeScript|compiler API)\b' concerns; then
  fail "concerns に言語機構/方言が漏れている(中立化するか languages へ移すこと)"
else
  pass "concerns に言語機構/方言の漏れなし"
fi

echo
echo "=== 4. principles への言語/製品/方言の漏れ(あってはならない) ==="
principles_leak=0
if rg -nP '\b(sqlx|tokio|axum|Dapper|Npgsql|EF Core|zod|valibot|SolidJS|ON CONFLICT|ON DUPLICATE)\b' principles; then
  principles_leak=1
fi

if ! product_names=$(node "$SCRIPT_DIR/naming-registry-check.mjs" --standard-root "$STANDARD_ROOT" --products); then
  fail "採用の正本から製品名を取得できない"
  principles_leak=1
fi
product_count=0
product_patterns=()
while IFS= read -r product; do
  [ -z "$product" ] && continue
  is_non_product_token "$product" && continue
  product_count=$((product_count + 1))
  product_patterns+=("(?<![A-Za-z0-9_.#+@/-])\\Q${product}\\E(?![A-Za-z0-9_.#+@/-])")
done <<< "$product_names"
if [ "${#product_patterns[@]}" -gt 0 ]; then
  if product_matches=$(rg --with-filename -nP -f <(printf '%s\n' "${product_patterns[@]}") principles); then
    echo "  台帳由来の製品名を含む行:"
    while IFS= read -r product_match; do echo "    $product_match"; done <<< "$product_matches"
    principles_leak=1
  else
    product_search_status=$?
    if [ "$product_search_status" -ne 1 ]; then
      fail "採用の正本から得た製品名を照合できない"
      principles_leak=1
    fi
  fi
fi
echo "tools と languages の採用宣言から抽出した製品名: $product_count"
if [ "$principles_leak" = 0 ]; then
  pass "principles に言語/製品/方言の漏れなし"
else
  fail "principles に言語/製品/方言が漏れている(principles は完全に言語非依存)"
fi

echo
echo "=== 5. concerns の台帳と実ファイル ==="
concerns_actual=$(find concerns -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
concerns_readme_rows=$(markdown_table_cells concerns/README.md '^## 概念$' 1 | count_lines)
echo "concerns: 台帳=$concerns_readme_rows 実ファイル=$concerns_actual"
if [ "$concerns_actual" != "$concerns_readme_rows" ]; then
  fail "概念数が不一致(台帳=$concerns_readme_rows, 実ファイル=$concerns_actual)"
else
  pass "concerns の台帳と実ファイルが一致"
fi


echo
echo "=== 6. process/tools/languages の台帳と実ファイル ==="
numeric_ok=1
process_declared=$(markdown_table_cells process/README.md '^## 単位$' 1 | sed -E 's#^\[[^]]*\]\(\./([^)]*)\)$#\1#' | sort)
process_actual=$(find process -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -printf '%f\n' | sort)
echo "process: 台帳=$(count_lines <<< "$process_declared") 実ファイル=$(count_lines <<< "$process_actual")"
if [ "$process_declared" != "$process_actual" ]; then
  echo "  process の台帳:"
  printf '%s\n' "$process_declared" | sed 's/^/    /'
  echo "  process の実ファイル:"
  printf '%s\n' "$process_actual" | sed 's/^/    /'
  fail "process の台帳と実ファイルが不一致"
  numeric_ok=0
fi

tools_ok=1
tools_top_actual=$(find tools -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
tools_dirs_actual=$(find tools -mindepth 1 -maxdepth 1 -type d | sed 's#^tools/##' | sort | paste -sd ' ' -)
echo "tools: 直下file=$tools_top_actual 区分=[$tools_dirs_actual]"
if [ "$tools_top_actual" != "0" ]; then
  fail "tools 直下に README 以外の file がある(区分のフォルダへ置く)"
  tools_ok=0
fi
if [ "$tools_dirs_actual" != "build platforms services" ]; then
  fail "tools の区分が不一致([$tools_dirs_actual])"
  tools_ok=0
fi
for division in build platforms services; do
  division_declared=$(rg -oN '\]\(\./([^)#]+\.md)\)' "tools/$division/README.md" -r '$1' 2>/dev/null | sort -u)
  division_actual=$(find "tools/$division" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -printf '%f\n' | sort -u)
  if [ "$division_declared" != "$division_actual" ]; then
    echo "  tools/$division の台帳:"
    printf '%s\n' "$division_declared" | sed 's/^/    /'
    echo "  tools/$division の実ファイル:"
    printf '%s\n' "$division_actual" | sed 's/^/    /'
    fail "tools/$division の台帳と実ファイルが不一致"
    tools_ok=0
  fi
done
if [ "$tools_ok" = 0 ]; then numeric_ok=0; fi

languages_top_actual=$(find languages -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
language_dirs_actual=$(find languages -mindepth 1 -maxdepth 1 -type d | sed 's#^languages/##' | sort | paste -sd ' ' -)
language_files_expected=7
language_counts=""
languages_ok=1
if [ "$languages_top_actual" != "0" ]; then
  fail "languages 直下に README 以外の file がある(言語 ecosystem のフォルダへ置く)"
  languages_ok=0
fi
if [ "$language_dirs_actual" != "csharp rust typescript" ]; then
  fail "languages の言語 ecosystem が不一致([$language_dirs_actual])"
  languages_ok=0
fi
for language in rust csharp typescript; do
  language_count=0
  for axis in formation translation connection coordination publication inspection conventions; do
    [ -f "languages/$language/$axis.md" ] && language_count=$((language_count+1))
  done
  language_counts+="$language=$language_count "
  [ "$language_count" = "$language_files_expected" ] || languages_ok=0
  language_declared=$(rg -oN '\]\(\./([^)#]+\.md)\)' "languages/$language/README.md" -r '$1' 2>/dev/null | sort -u)
  language_actual=$(find "languages/$language" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -printf '%f\n' | sort -u)
  if [ "$language_declared" != "$language_actual" ]; then
    echo "  languages/$language の台帳:"
    printf '%s\n' "$language_declared" | sed 's/^/    /'
    echo "  languages/$language の実ファイル:"
    printf '%s\n' "$language_actual" | sed 's/^/    /'
    fail "languages/$language の台帳と実ファイルが不一致"
    languages_ok=0
  fi
done
echo "languages: 直下file=$languages_top_actual 言語=[$language_dirs_actual]; $language_counts"
if [ "$languages_ok" = 0 ]; then
  numeric_ok=0
fi
if [ "$numeric_ok" = 1 ]; then pass "process・tools・languages の台帳と実ファイルが一致"; fi

echo
echo "=== 7. 言語 ecosystem 本文の規律と inspection 対応表の一対一照合 ==="
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
  pass "言語 ecosystem 3言語の本文規律と inspection 対応表が一対一で一致"
fi

echo
echo "=== 9. principles と concerns の逐語一致(18文字連続一致・5文節相当の近似。goal-04 再発防止) ==="
if overlap_out=$(node "$SCRIPT_DIR/verbatim-overlap.mjs" --standard-root "$STANDARD_ROOT" 2>&1); then
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
echo "=== 10. concerns・structure・languages の製品名指しが採用エントリに登録済みか(goal-25・goal-26) ==="
if naming_out=$(node "$SCRIPT_DIR/naming-registry-check.mjs" --standard-root "$STANDARD_ROOT" 2>&1); then
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
    rg -n "に従う。" principles concerns --no-heading 2>/dev/null | rg "\]\((\.\./)+(structure|tools|languages|process)" || true
    rg -n "に従う。" structure --no-heading 2>/dev/null | rg "\]\((\.\./)+(tools|languages)" || true
  } | wc -l
)
if [ "${verb_violations:-0}" = "0" ]; then
  pass "抽象から具象への「従う」参照なし"
else
  {
    rg -n "に従う。" principles concerns --no-heading 2>/dev/null | rg "\]\((\.\./)+(structure|tools|languages|process)" || true
    rg -n "に従う。" structure --no-heading 2>/dev/null | rg "\]\((\.\./)+(tools|languages)" || true
  }
  fail "抽象から具象への参照に「従う」が残っている(「が定める」へ)"
fi

echo
echo "=== 12. structure の台帳が本文ファイルを file 粒度で網羅しているか ==="
ledger_declared=$(
  for spec in "structure/README.md:structure" \
              "structure/surfaces/README.md:structure/surfaces" \
              "structure/runtimes/README.md:structure/runtimes"; do
    ledger="${spec%%:*}"; base="${spec##*:}"
    rg '^\|' "$ledger" | awk -F'|' -v base="$base" '
      NR==1 { for (i=2; i<NF+1; i++) { c=$i; gsub(/^ +| +$/,"",c); if (c=="ファイル") fc=i }
              if (!fc) { print "NOFILECOL" > "/dev/stderr"; exit 1 } next }
      NR==2 { next }
      {
        key=$2; sub(/.*\[/,"",key); sub(/\].*/,"",key)
        decl=$fc; gsub(/^ +| +$/,"",decl)
        if (decl ~ /README/) next
        dir = (key=="skeleton") ? base : base "/" key
        n=split(decl, parts, "・")
        for (j=1; j<=n; j++) { s=parts[j]; gsub(/^ +| +$/,"",s); print dir "/" s }
      }'
  done | sort -u
)
ledger_actual=$(find structure -name '*.md' ! -name 'README.md' | sed 's/\.md$//' | sort -u)
ledger_diff=$(comm -3 <(printf '%s\n' "$ledger_declared") <(printf '%s\n' "$ledger_actual"))
structure_body=$(printf '%s\n' "$ledger_actual" | wc -l | tr -d ' ')
echo "structure 本文ファイル数: $structure_body"
if [ -z "$ledger_diff" ]; then
  pass "structure の台帳が本文ファイルと file 粒度で一致($structure_body)"
else
  echo "左=台帳のみ / 右=実ファイルのみ"
  printf '%s\n' "$ledger_diff"
  fail "structure の台帳が本文ファイルと一致していない"
fi

echo "=== 13. 規律名指しの鉤括弧引用が正本の見出しと一致するか ==="
if citation_out=$(node "$SCRIPT_DIR/heading-citation-check.mjs" --standard-root "$STANDARD_ROOT" 2>&1); then
  echo "$citation_out"
  pass "link 行の鉤括弧引用が全て link 先の見出しと一致"
else
  echo "$citation_out"
  fail "正本の見出しに無い規律名の名指しあり"
fi

echo
echo "=== 14. 統一済み語彙の旧表記が残っていないか ==="
if rg -nP '真実の所在|詰め替え|二次の読みモデル|期限の正本|単方向|コンテキストの自己完結|明快さ|境界面|ドメインモデル|value object|ドメインの型|domain の型|業務の型|なぜを決定の記録に残す' principles concerns structure tools languages process README.md; then
  fail "統一済み語彙の旧表記が残っている(正へ揃える)"
else
  pass "統一済み語彙の旧表記なし"
fi

echo
echo "=== 15. principles/concerns の各概念フォルダに下位の消費者がいるか ==="
# 根拠: concerns/README「file を分ける単位は、structure と tools が独立に名指して従う契約である」と
# principles/README「原則の file を分ける単位は、下位の層の file が名指して参照する単位である」。
# root README の検証割当(file または領域の名指し)とは別の検査であり、領域単位の照合を否定しない。
orphan_files=""
for consumer_area in principles concerns; do
  while IFS= read -r body_dir; do
    body_key=${body_dir##*/}
    body_key="$consumer_area/$body_key/"
    if ! rg -q -F "$body_key" process structure tools languages 2>/dev/null; then
      orphan_files="$orphan_files $body_key"
    fi
  done < <(find "$consumer_area" -mindepth 1 -maxdepth 1 -type d)
done
if [ -z "$orphan_files" ]; then
  pass "principles/concerns の全 file を下位の層が参照"
else
  echo "未参照:$orphan_files"
  fail "下位の層から参照されない file あり"
fi

echo
echo "=== 16. 概念フォルダの規律台帳(README の行 = 実 file = file 先頭の規律 H2。各行は検証手段を持つ) ==="
ledger_ok=1
for concept_dir in principles/*/ concerns/*/; do
  readme="${concept_dir}README.md"
  if [ ! -f "$readme" ]; then echo "  $concept_dir: README.md がない"; ledger_ok=0; continue; fi
  ledger_records=$(rg -oN '^- \[([^]]+)\]\(\./([^)]+)\.md\) — (機械|機械\+レビュー|レビュー)\(.+\)$' "$readme" -r '$2'$'\t''$1' | sort)
  mapfile -d '' -t rule_files < <(find "$concept_dir" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print0)
  actual_records=""
  if [ "${#rule_files[@]}" -gt 0 ]; then
    actual_records=$(awk '
      /^## .+$/ && !(FILENAME in headings) { headings[FILENAME] = substr($0, 4) }
      END {
        for (file = 1; file < ARGC; file++) {
          base = ARGV[file]
          sub(/^.*\//, "", base)
          sub(/\.md$/, "", base)
          printf "%s\t%s\n", base, headings[ARGV[file]]
        }
      }
    ' "${rule_files[@]}" | sort)
  fi
  if [ "$ledger_records" != "$actual_records" ]; then
    echo "  $concept_dir: 台帳と実 file/規律名が不一致"
    diff <(echo "$ledger_records") <(echo "$actual_records") | sed 's/^/    /'
    ledger_ok=0
  fi
done
if [ "$ledger_ok" = 1 ]; then
  pass "概念フォルダの台帳・実 file・規律 H2 が一致"
else
  fail "概念フォルダの台帳が不一致(上記 diff)"
fi

echo
echo "=== 17. ツール file の entry 書式(用途・採用・判断基準・撤回条件の4項目) ==="
entry_ok=1
mapfile -d '' -t tool_files < <(find tools languages -mindepth 2 -maxdepth 2 -type f -name '*.md' -print0)
entry_out=""
if [ "${#tool_files[@]}" -gt 0 ]; then
  if ! entry_out=$(awk '
    BEGIN {
      prefixes[1] = "用途は、"
      prefixes[2] = "採用は、"
      prefixes[3] = "判断基準は、"
      prefixes[4] = "撤回条件は、"
    }
    {
      for (item = 1; item <= 4; item++) {
        if (index($0, prefixes[item]) == 1) present[FILENAME, item] = 1
      }
    }
    END {
      for (file = 1; file < ARGC; file++) {
        base = ARGV[file]
        sub(/^.*\//, "", base)
        sub(/\.md$/, "", base)
        if (base ~ /^(README|formation|translation|connection|coordination|publication|inspection|conventions)$/) continue
        for (item = 1; item <= 4; item++) {
          if (!present[ARGV[file], item]) printf "  %s: 「%s」で始まる行がない\n", ARGV[file], prefixes[item]
        }
      }
    }
  ' "${tool_files[@]}"); then
    entry_ok=0
  fi
fi
if [ -n "$entry_out" ]; then
  printf '%s\n' "$entry_out"
  entry_ok=0
fi
if [ "$entry_ok" = 1 ]; then
  pass "全ツール file が entry の4項目を持つ"
else
  fail "entry の4項目を欠くツール file あり"
fi

echo
echo
if [ "$FAILED" = 0 ]; then
  echo "=== 総合: PASS ==="
else
  echo "=== 総合: FAIL ==="
fi
exit "$FAILED"
