BEGIN {
  required[1] = "要求"
  required[2] = "根拠"
  required[3] = "完了条件"
  required[4] = "禁止事項"
  required[5] = "行動"
}

function clear_section(    i) {
  for (i = 1; i <= 5; i++) counts[i] = 0
  observed = ""
  marker_seen = 0
}

# ツール file(ecosystem 直下の軸 file 以外)では、5節マーカーを一つも持たない H2 は
# 採用エントリであり規律単位に数えない。軸 file では全 H2(免除以外)が単位。
function is_tool_file(file,    base) {
  if (file !~ /(^|\/)tools\/(rust|csharp|typescript|build|platforms|services)\/[^/]+\.md$/) return 0
  base = file
  sub(/^.*\//, "", base)
  sub(/\.md$/, "", base)
  return !(base ~ /^(formation|translation|connection|coordination|publication|inspection|conventions)$/)
}

function is_non_unit(title, file) {
  if (file ~ /(^|\/)concerns\/[^/]+\.md$/) {
    return title == "概要" || title == "参照"
  }
  if (file ~ /(^|\/)tools\/(rust|csharp|typescript)\/[^/]+\.md$/) {
    if (title == "概要" || title == "参照") return 1
    return title == "規則と検証機構の対応" && \
      file ~ /(^|\/)tools\/(rust|csharp|typescript)\/inspection\.md$/
  }
  return 0
}

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
