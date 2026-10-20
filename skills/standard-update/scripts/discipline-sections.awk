BEGIN {
  required[1] = "要求"
  required[2] = "根拠"
  required[3] = "完了条件"
  required[4] = "禁止事項"
  required[5] = "行動"
}

# 次の規律単位に備えた必須節の集計状態の初期化
# - ローカル `i`: 必須節の集計位置
# - 状態 `counts`: 必須5節の出現回数の 0 への初期化
# - 状態 `observed`: 必須節の出現順の空文字への初期化
# - 状態 `marker_seen`: 必須節の検出有無の 0 への初期化
function clear_section(    i) {
  for (i = 1; i <= 5; i++) counts[i] = 0
  observed = ""
  marker_seen = 0
}

# 必須節のない entry を規律単位から除外する file 分類
# - `file`: 軸 file の除外を判定する標準 root 相対 path
# - ローカル `base`: 軸 file の除外判定に使う basename
# - 戻り値: 採用を所有する tool file であることの真偽
function is_tool_file(file,    base) {
  if (file !~ /(^|\/)(tools\/(build|platforms|services)|languages\/(rust|csharp|typescript))\/[^/]+\.md$/) return 0
  base = file
  sub(/^.*\//, "", base)
  sub(/\.md$/, "", base)
  return !(base ~ /^(formation|translation|connection|coordination|publication|inspection|conventions)$/)
}

# 必須5節の検査対象から除外する案内見出しの判定
# - `title`: `##` の接頭辞から分離した末尾空白のない節見出し
# - `file`: 節を所有する検査対象 file の path
# - 戻り値: file の配置に応じた除外見出しであることの真偽
function is_non_unit(title, file) {
  if (file ~ /(^|\/)concerns\/[^/]+\.md$/) {
    return title == "概要" || title == "参照"
  }
  if (file ~ /(^|\/)languages\/(rust|csharp|typescript)\/[^/]+\.md$/) {
    if (title == "概要" || title == "参照") return 1
    return title == "規則と検証機構の対応" && \
      file ~ /(^|\/)languages\/(rust|csharp|typescript)\/inspection\.md$/
  }
  return 0
}

# 確定した規律単位の必須節の検査結果の集計
# - ローカル `i`: 必須節の検査位置
# - ローカル `counts_text`: 必須節ごとの件数の診断文字列
# - ローカル `expected_order`: 要求から行動までの正規の必須節順序
# - ローカル `valid`: 必須節の件数と順序が規定どおりであることの真偽
# - 入力状態: `has_section`・`non_unit`・`section_qualified`・`marker_seen` による検査対象の識別
# - 入力状態: `counts`・`observed` に保持する必須節の出現状況
# - 入力状態: `required` に保持する必須節名
# - 入力状態: `section_file`・`section_line`・`section_title` に保持する節の出典
# - 対象外: 未開始の節か案内見出し
# - 対象外: 必須節が未検出の採用 file の節
# - 状態: 検査対象の節数を保持する `units` の加算
# - 状態: 不正な節数を保持する `violations` の加算
# - 出力: 不正な節の出典を含む必須節診断の標準出力
function flush_section(    i, counts_text, expected_order, valid) {
  if (!has_section || non_unit) return
  if (section_qualified && !marker_seen) return

  units++
  expected_order = "要求 > 根拠 > 完了条件 > 禁止事項 > 行動"
  valid = observed == expected_order
  counts_text = ""
  for (i = 1; i <= 5; i++) {
    if (counts[i] != 1) valid = 0
    counts_text = counts_text (i == 1 ? "" : ", ") required[i] "=" counts[i]
  }

  if (!valid) {
    violations++
    printf "%s:%d: ## %s: 必須節が不正(%s, 順序=%s)\n", \
      section_file, section_line, section_title, counts_text, \
      observed == "" ? "<なし>" : observed
  }
}

FNR == 1 {
  flush_section()
  has_section = 0
  in_fence = 0
}

{
  trimmed = $0
  sub(/^[[:space:]]+/, "", trimmed)
  if (trimmed ~ /^```/ || trimmed ~ /^~~~/) {
    in_fence = !in_fence
    next
  }
  if (in_fence) next
}

/^##[[:space:]]+/ {
  flush_section()
  clear_section()
  section_file = FILENAME
  section_line = FNR
  section_title = $0
  sub(/^##[[:space:]]+/, "", section_title)
  sub(/[[:space:]]+$/, "", section_title)
  non_unit = is_non_unit(section_title, section_file)
  section_qualified = is_tool_file(section_file)
  has_section = 1
  next
}

/^###[[:space:]]+/ && has_section && !non_unit {
  subsection = $0
  sub(/^###[[:space:]]+/, "", subsection)
  sub(/[[:space:]]+$/, "", subsection)
  for (i = 1; i <= 5; i++) {
    if (subsection == required[i]) {
      counts[i]++
      marker_seen = 1
      observed = observed (observed == "" ? "" : " > ") subsection
      break
    }
  }
}

END {
  flush_section()
  printf "units: %d\nviolations: %d\n", units, violations
}
