#!/usr/bin/env bash
set -uo pipefail

required_commands=(bash git rg node mktemp mkdir ln timeout sed rm chmod sleep)
for required_command in "${required_commands[@]}"; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'FAIL: missing required command: %s\n' "$required_command" >&2
    exit 1
  fi
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'FAIL: git repository で実行すること\n' >&2
  exit 1
}
cd "$REPO_ROOT" || exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0
PASSED=0

pass() {
  printf 'PASS: %s\n' "$1"
  PASSED=$((PASSED + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" | sed 's/^/  /'
  fi
  FAILED=$((FAILED + 1))
}

expect_text() {
  local label="$1"
  local pattern="$2"
  shift 2
  if rg -q "$pattern" "$@"; then pass "$label"; else fail "$label" "pattern: $pattern"; fi
}

expect_no_text() {
  local label="$1"
  local pattern="$2"
  shift 2
  if rg -q "$pattern" "$@"; then fail "$label" "unexpected pattern: $pattern"; else pass "$label"; fi
}

expect_line() {
  local label="$1"
  local line="$2"
  shift 2
  if rg -qF -x -- "$line" "$@"; then pass "$label"; else fail "$label" "line: $line"; fi
}

printf '=== 1. skill の指示整合 ===\n'
expect_no_text \
  "全領域へ6節を一律要求しない" \
  '^6節で書く。要求・根拠・完了条件・禁止事項・行動・例。$' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "structure の layout 書式を本体で分岐する" \
  'structure:.*layout 書式' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "process の手順書式を本体で分岐する" \
  'process:.*`## 順序`.*`## 確認点`.*`## 範囲外`' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "外部調査を事実または採用判断の変更へ限定する" \
  '外部事実|採用判断' \
  .claude/skills/standard-update/SKILL.md
expect_no_text \
  "apply はチェックリスト全文を応答へ転写しない" \
  'チェックリストとして応答へ転写' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "利用不能な capability の扱いを明記する" \
  '利用できない|利用不能|fallback|代替' \
  .claude/skills/standard-apply/SKILL.md \
  .claude/skills/standard-audit/SKILL.md \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "apply は pending を完了扱いしない" \
  'pending のまま完了と書かない' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "apply は記録 commit の snapshot だけを基準にする" \
  '記録した commit object から読む' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "apply は標準 repository を cwd から分離する" \
  'git -C <standard-root> show' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "apply は監査対象を読む前に基準の前処理を閉じる" \
  '対象 source の意味監査を始めない' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "apply は severity 対応を改変せず固定する" \
  'severity 対応を一字一句そのまま' \
  .claude/skills/standard-apply/SKILL.md
expect_no_text \
  "apply は現行 severity の具体値を重複固定しない" \
  '必須構成と layout の不達は major' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "apply は証拠のない監査 step を実施済みにしない" \
  'tool output または直接の読取証拠がない step を実施済みにしない' \
  .claude/skills/standard-apply/SKILL.md
expect_text \
  "audit は反証を探してから指摘する" \
  '反証として探す' \
  .claude/skills/standard-audit/SKILL.md
expect_no_text \
  "audit skill は git 管理外の docs path を含まない" \
  'docs/' \
  .claude/skills/standard-audit/SKILL.md
expect_line \
  "audit は監査対象と判定 context の allowlist を分ける" \
  '  - 読取前に、指摘を確定できる file を監査対象 allowlist、判定基準を得る root README と領域 README を判定 context allowlist へ分けて固定する。' \
  .claude/skills/standard-audit/SKILL.md
expect_line \
  "audit は closed list の実在数確認でも範囲外を列挙しない" \
  '  - 依頼が閉じた file 一覧を示した場合は、その path を直接読む。path 発見のための wildcard は使わない。実在数や命名の確認でも、allowlist 外を検索、Glob、列挙しない。' \
  .claude/skills/standard-audit/SKILL.md
expect_line \
  "audit は closed list の外にある reference や検査scriptを確認しない" \
  '2. 監査対象と、判定 context にある領域 README、許可された範囲で必要な `.claude/skills/standard-update/references/` だけを読み、下の10軸で照合する。closed list では、reference や検査 script が必要か判断するために一覧外を読まず、許可された file だけで判定する。判定 context は基準としてだけ使い、その file から別の指摘を作らない。`.claude/skills/` は標準の6領域ではなく運用入口なので、領域本文の書式を適用せず、skill 自身の役割、実行可能性、発火境界で判定する。' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は issue を現行版の証拠にしない" \
  '現行 release.*未確認' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "update は外部裁定を独立2源で閉じる" \
  '主張ごとに本文を取得できた独立2源' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は機械修正の正本語を推測しない" \
  '類義語を推測して置き換えない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "skill script を CLAUDE_SKILL_DIR から実行する" \
  'CLAUDE_SKILL_DIR' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "instruction 変更の task eval は影響する task と旧版比較へ限定する" \
  '- SKILL.md の instruction を変更した場合は、skill-creator の評価手順を使う。変更した instruction の入力と観測可能な結果を prompt と expectation が直接使う task だけを `old-skill` と `with-skill` の2条件で隔離実行する。変更された file を監査対象に含むだけの task や、同じ skill を使うだけの task は選ばない。expectation、最終応答、tool event、diff、tracked / ignored status、実行 error、時間、token を比較する。新規 skill で旧版がない場合だけ `without-skill` を比較対象にする。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "eval 定義だけの変更は変更 task の新版だけを実行する" \
  '- `evals/evals.json` だけを変更した場合は、変更した task を `with-skill` で実行する。現行 instruction の不足が失敗として再現した後に instruction を変更し、その段階で `old-skill` と `with-skill` を比較する。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "description 変更だけが full trigger eval を要求する" \
  '- description または `evals/trigger-evals.json` を変更した場合は、`scripts/run-trigger-evals.mjs` で `trigger-evals.json` の全 query を実行する。3 skill を同時に置いた条件で expected skill または非発火を測り、Skill tool の完全な入力、観測中の実行 error、発火先を記録する。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "script と reference だけの変更は model eval を要求しない" \
  '- `scripts/*` または `references/*.md` だけを変更し、SKILL.md と eval を変えない場合は、上の回帰検査だけを行い、model eval は実行しない。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "標準のコード例は説明コメントを生成しない" \
  '3. 差と帰結はコードフェンス外の本文へ置き、コード例へ説明のコメントを足さない。ドキュメントコメント、採らなかった理由、禁止するコメントそのものを示す例では、規律の対象であるコメントだけをコード内に残す。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "標準のコード例は対象言語の全域規律を読む" \
  '1. 例の言語を特定し、その言語の `languages/<language>/conventions.md` を読む。擬似コードなら言語固有の構文を使わない。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "断片での表示省略を実コードの免除にしない" \
  '4. コード例は判定に必要な部分だけを示す断片とする。例の主題でない import、ドキュメントコメント、周辺の宣言は表示を省けるが、実コードで不要であるとは示さない。表示する構文は、意図的な違反を除き、conventions の規律を例の中でも満たす。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "ドキュメントコメントの例は言語の契約記法で書く" \
  '5. ドキュメントコメントを表示する場合は、目的と、宣言が持つ引数・型引数・戻り値・値・副作用・失敗条件の該当項目を、望ましい例と意図的な悪例の両方に記す。引数・型引数・戻り値・値の該当は説明の自明さでなく宣言の署名から決め、引数があれば param、型引数があれば typeParam、非 void の戻り値があれば returns、値を公開するメンバなら value を省かない。conventions が専用のタグまたは節を定める項目はその記法を使い、定めない項目は本文で述べる。別の例の完全な契約で代替しない。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "ドキュメントコメント例の署名とタグを照合する" \
  '編集の直前に、ドキュメントコメントを表示する各宣言の署名と param・typeParam・returns・value を一対一で照合する。その後に、対象言語の現行版で成立し、例の主題でない違反が残っていないことを確認する。' \
  .claude/skills/standard-update/SKILL.md
expect_line \
  "principles の層責務を言語規律の免除理由にしない" \
  '省略した周辺要素は表示上の省略として扱い、実コードで不要であるとは示さない。表示した要素自体は conventions に従う。TSDoc を表示する例は、宣言の署名に対応する契約記法を含めて成立させる。' \
  .claude/skills/standard-update/references/principles.md
expect_line \
  "全 task 三条件 benchmark を release 境界へ限定する" \
  '- release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較と full trigger eval の両方を行う。それ以外は変更面ごとの上記範囲に限定する。instruction と `evals/trigger-evals.json` の変更を組み合わせた場合は、影響 task の2条件比較と full trigger eval をそれぞれ行い、全 task や `without-skill` へ広げない。' \
  .claude/skills/standard-update/SKILL.md
for skill_name in standard-apply standard-audit standard-update; do
  expect_text \
    "$skill_name の description は調査や編集より前の利用場面を示す" \
    '^description: .*調査や編集に着手する前に、この skill を必ず使う' \
    ".claude/skills/$skill_name/SKILL.md"
  expect_no_text \
    "$skill_name の description に内部tool順序を書かない" \
    '^description: .*Read・Grep・Bash・Agent より先に Skill tool' \
    ".claude/skills/$skill_name/SKILL.md"
done
expect_no_text \
  "audit の description は標準の変更依頼と競合しない" \
  '^description: .*標準の変更前' \
  .claude/skills/standard-audit/SKILL.md

printf '\n=== 2. task eval と trigger eval の schema ===\n'
eval_output=$(node <<'NODE' 2>&1
const fs = require("node:fs");
const path = require("node:path");

const skillNames = ["standard-apply", "standard-audit", "standard-update"];
let violations = 0;

function reject(message) {
  console.error(`FAIL: ${message}`);
  violations += 1;
}

for (const skillName of skillNames) {
  const root = path.join(".claude", "skills", skillName);
  const skillPath = path.join(root, "SKILL.md");
  const evalPath = path.join(root, "evals", "evals.json");
  const triggerPath = path.join(root, "evals", "trigger-evals.json");

  const skillSource = fs.readFileSync(skillPath, "utf8");
  const frontmatter = skillSource.match(/^---\n([\s\S]*?)\n---\n/);
  if (!frontmatter) {
    reject(`${skillName}: YAML frontmatter がない`);
  } else {
    const name = frontmatter[1].match(/^name:\s*(.+)$/m)?.[1]?.trim();
    const description = frontmatter[1].match(/^description:\s*(.+)$/m)?.[1]?.trim();
    if (name !== skillName) reject(`${skillName}: frontmatter name が directory と一致しない`);
    if (!name || name.length > 64 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) {
      reject(`${skillName}: name は64文字以下のlowercase/digit/hyphenであること`);
    }
    if (!description || description.length > 1024 || /[<>]/.test(description)) {
      reject(`${skillName}: description は1..1024文字でXML tagを含まないこと`);
    }
  }
  const lineCount = skillSource.endsWith("\n") ? skillSource.slice(0, -1).split("\n").length : skillSource.split("\n").length;
  if (lineCount >= 500) reject(`${skillName}: SKILL.md は500行未満であること`);

  if (!fs.existsSync(evalPath)) {
    reject(`${skillName}: evals/evals.json がない`);
  } else {
    const data = JSON.parse(fs.readFileSync(evalPath, "utf8"));
    if (data.skill_name !== skillName) reject(`${skillName}: skill_name が一致しない`);
    if (!Array.isArray(data.evals) || data.evals.length < 3) {
      reject(`${skillName}: task eval は3件以上必要`);
    } else {
      const ids = new Set();
      for (const item of data.evals) {
        if (!Number.isInteger(item.id) || ids.has(item.id)) reject(`${skillName}: eval id が不正または重複`);
        ids.add(item.id);
        if (typeof item.prompt !== "string" || item.prompt.length < 40) reject(`${skillName}: prompt が短すぎる`);
        if (typeof item.expected_output !== "string" || item.expected_output.length < 20) reject(`${skillName}: expected_output が短すぎる`);
        if (!Array.isArray(item.expectations) || item.expectations.length < 3) reject(`${skillName}: expectations は3件以上必要`);
        if (!Array.isArray(item.files)) reject(`${skillName}: files は配列であること`);
        if (!["haiku", "sonnet", "opus"].includes(item.model)) reject(`${skillName}: model が不正`);
      }
      const models = new Set(data.evals.map((item) => item.model));
      for (const model of ["haiku", "sonnet", "opus"]) {
        if (!models.has(model)) reject(`${skillName}: ${model} の task eval がない`);
      }
    }
  }

  if (!fs.existsSync(triggerPath)) {
    reject(`${skillName}: evals/trigger-evals.json がない`);
  } else {
    const queries = JSON.parse(fs.readFileSync(triggerPath, "utf8"));
    if (!Array.isArray(queries) || queries.length < 20) {
      reject(`${skillName}: trigger eval は20件以上必要`);
    } else {
      const positive = queries.filter((item) => item.should_trigger === true).length;
      const negative = queries.filter((item) => item.should_trigger === false).length;
      if (positive < 8 || negative < 8) reject(`${skillName}: positive/negative は各8件以上必要`);
      for (const item of queries) {
        if (typeof item.query !== "string" || item.query.length < 20) reject(`${skillName}: trigger query が短すぎる`);
        if (typeof item.should_trigger !== "boolean") reject(`${skillName}: should_trigger はbooleanであること`);
        if (Object.hasOwn(item, "expected_skill") && item.expected_skill !== null && !skillNames.includes(item.expected_skill)) {
          reject(`${skillName}: expected_skill が不正`);
        }
      }
    }
  }
}

console.log(`violations: ${violations}`);
process.exit(violations === 0 ? 0 : 1);
NODE
)
if [ "$?" -eq 0 ]; then
  printf '%s\n' "$eval_output"
  pass "3 skill の eval schema が有効"
else
  fail "3 skill の eval schema が無効" "$eval_output"
fi
unexpected_fixture_typo='情報の'"概観"
expect_no_text \
  "task fixture の誤字を evaluator 自身へ露出しない" \
  "$unexpected_fixture_typo" \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator は全 task へ full verifier を強制しない" \
  '^      "検証は repository root から' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は変更と skill 契約が要求する場合だけ検証入口を示す" \
  'task が file を変更し.*skill が検証を要求する場合' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_line \
  "task evaluator は exact path の再発見を要求しない" \
  '      "task の path は現在の作業directoryからの相対pathです。task が exact file path を示した場合は Read で直接読み、repository名を足したり、path の再発見に Glob や path 未指定の Grep を使ったりしないでください。task が探索を必要とし、使用する skill が許す場合だけ Glob と Grep を使います。外部事実の確認が task に必要なら WebSearch と WebFetch を使えます。Bash は許可済みの検証 script と git status/diff だけに使ってください。",' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_line \
  "task evaluator は代替探索も task と skill の許可へ従わせる" \
  '      "ls、find、wc、cat、git log、git rev-parse を Bash で実行しないでください。探索が task と skill で許可される場合だけ Glob または Grep を使い、既知の file は Read で直接読んでください。",' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs

printf '\n=== 3. verifier は依存不足で fail closed ===\n'
make_limited_path() {
  local omitted="$1"
  local target="$2"
  local command_name
  local command_path
  local commands=(bash git rg fd awk sed find wc tr head tail sort diff dirname paste basename cut node)

  mkdir -p "$target" || return 1
  for command_name in "${commands[@]}"; do
    [ "$command_name" = "$omitted" ] && continue
    command_path=$(command -v "$command_name") || return 1
    ln -s "$command_path" "$target/$command_name" || return 1
  done
}

TEMP_BASE="${TMPDIR:-/tmp}"
TEMP_BASE="$(cd "$TEMP_BASE" 2>/dev/null && pwd -P)" || {
  fail "skill-test の一時ディレクトリを作成" "TMPDIR is unavailable"
  printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
  exit 1
}
TEST_ROOT=$(mktemp -d "$TEMP_BASE/architecture-standard-skill-test.XXXXXX") || {
  fail "skill-test の一時ディレクトリを作成" "mktemp -d failed"
  printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
  exit 1
}
case "$TEST_ROOT" in
  "$TEMP_BASE"/architecture-standard-skill-test.*) ;;
  *)
    fail "skill-test の一時ディレクトリを作成" "unsafe temporary directory: $TEST_ROOT"
    exit 1
    ;;
esac
cleanup() {
  case "$TEST_ROOT" in
    "$TEMP_BASE"/architecture-standard-skill-test.*)
      [ ! -e "$TEST_ROOT" ] || rm -rf -- "$TEST_ROOT"
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
BASH_PATH=$(command -v bash)

for missing_command in node fd; do
  limited_path="$TEST_ROOT/path-without-$missing_command"
  if ! make_limited_path "$missing_command" "$limited_path"; then
    fail "$missing_command 欠落fixtureを構築" "limited PATH setup failed"
    continue
  fi
  if dependency_output=$(PATH="$limited_path" "$BASH_PATH" "$SCRIPT_DIR/verify.sh" 2>&1); then
    fail "$missing_command がない場合は verifier が失敗する" "verify.sh がPASSした\n$dependency_output"
  elif ! printf '%s\n' "$dependency_output" | rg -qF "missing required command: $missing_command"; then
    fail "$missing_command 欠落を具体的に診断する" "$dependency_output"
  else
    pass "$missing_command 欠落で fail closed"
  fi
done

printf '\n=== 4. verify-test は mktemp 失敗時に何も作らない ===\n'
mktemp_probe=$(timeout 10 "$BASH_PATH" -c '
  mktemp() { return 1; }
  mkdir() { return 91; }
  cp() { return 92; }
  sed() { return 93; }
  rm() { return 94; }
  export -f mktemp mkdir cp sed rm
  bash "$1"
' probe "$SCRIPT_DIR/verify-test.sh" 2>&1)
mktemp_status=$?
if [ "$mktemp_status" -eq 0 ]; then
  fail "mktemp 失敗時は verify-test が失敗する" "$mktemp_probe"
elif ! printf '%s\n' "$mktemp_probe" | rg -qF "一時ディレクトリを作成できない"; then
  fail "mktemp 失敗を具体的に診断する" "$mktemp_probe"
else
  pass "mktemp 失敗で即時終了"
fi

printf '\n=== 5. trigger evaluator は発火とtask完遂を分離する ===\n'
for failure_mode in nonzero malformed result-error; do
  fake_claude="$TEST_ROOT/claude-$failure_mode"
  case "$failure_mode" in
    nonzero)
      printf '%s\n' '#!/usr/bin/env bash' 'exit 7' > "$fake_claude"
      expected_error='exit=7'
      timeout_ms=1000
      ;;
    malformed)
      printf '%s\n' '#!/usr/bin/env bash' 'printf '\''not-json\\n'\''' > "$fake_claude"
      expected_error='malformed stream-json event'
      timeout_ms=1000
      ;;
    result-error)
      printf '%s\n' '#!/usr/bin/env bash' 'printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"injected error"}'\''' > "$fake_claude"
      expected_error='result error: injected error'
      timeout_ms=1000
      ;;
  esac
  chmod +x "$fake_claude" || {
    fail "$failure_mode fixture を構築" "chmod failed"
    continue
  }
  if trigger_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_claude" CLAUDE_EVAL_TIMEOUT_MS="$timeout_ms" node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
    fail "$failure_mode を発火評価の非発火 PASS にしない" "$trigger_output"
  elif ! printf '%s\n' "$trigger_output" | rg -qF "$expected_error"; then
    fail "$failure_mode を具体的に診断する" "$trigger_output"
  else
    pass "$failure_mode は発火評価 error"
  fi
done

fake_malformed_hang="$TEST_ROOT/claude-malformed-hang"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{not-json}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_malformed_hang"
chmod +x "$fake_malformed_hang" || fail "malformed-hang fixture を構築" "chmod failed"
if malformed_hang_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_malformed_hang" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  fail "壊れた stream-json を非発火成功にしない" "$malformed_hang_output"
elif ! printf '%s\n' "$malformed_hang_output" | rg -qF 'malformed stream-json event'; then
  fail "壊れた stream-json を具体的に診断する" "$malformed_hang_output"
else
  pass "壊れた stream-json は観測窓終了後も評価 error"
fi

fake_truncated_hang="$TEST_ROOT/claude-truncated-hang"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s'\'' '\''{"type":"assistant"'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_truncated_hang"
chmod +x "$fake_truncated_hang" || fail "truncated-hang fixture を構築" "chmod failed"
if truncated_hang_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_truncated_hang" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  fail "改行なしの壊れた stream-json を非発火成功にしない" "$truncated_hang_output"
elif ! printf '%s\n' "$truncated_hang_output" | rg -qF 'malformed stream-json event'; then
  fail "改行なしの壊れた stream-json を具体的に診断する" "$truncated_hang_output"
else
  pass "改行なしの壊れた stream-json は評価 error"
fi

fake_observation_window="$TEST_ROOT/claude-observation-window"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_observation_window"
chmod +x "$fake_observation_window" || fail "observation-window fixture を構築" "chmod failed"
if observation_negative_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_observation_window" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  pass "観測窓内に Skill がなければ非発火期待を完遂待ちなしで記録"
else
  fail "観測窓内に Skill がなければ非発火期待を完遂待ちなしで記録" "$observation_negative_output"
fi
if observation_positive_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_observation_window" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "観測窓内に Skill がなければ発火期待を失敗にする" "$observation_positive_output"
elif printf '%s\n' "$observation_positive_output" | rg -qF 'error=timeout'; then
  fail "発火先不一致とtask timeoutを混同しない" "$observation_positive_output"
else
  pass "観測窓内に Skill がなければ発火先不一致"
fi

fake_skill_after_observation="$TEST_ROOT/claude-skill-after-observation"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'process.on("SIGTERM", () => {' \
  '  console.log(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "skill-1", name: "Skill", input: { skill: "standard-apply" } }] } }));' \
  '  setTimeout(() => process.exit(143), 20);' \
  '});' \
  'setInterval(() => {}, 1000);' > "$fake_skill_after_observation"
chmod +x "$fake_skill_after_observation" || fail "skill-after-observation fixture を構築" "chmod failed"
if skill_after_observation_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_skill_after_observation" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "観測窓終了後の Skill を発火成功にしない" "$skill_after_observation_output"
elif printf '%s\n' "$skill_after_observation_output" | rg -q 'selected=standard-apply|"selected_skill": "standard-apply"'; then
  fail "観測窓終了後の Skill を選択結果へ混入しない" "$skill_after_observation_output"
else
  pass "観測窓終了後の Skill は発火結果へ混入しない"
fi

fake_direct_read="$TEST_ROOT/claude-direct-read"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"/tmp/fixture/.claude/skills/standard-apply/SKILL.md"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_direct_read"
chmod +x "$fake_direct_read" || fail "direct Read fixture を構築" "chmod failed"
if direct_read_output=$(CLAUDE_EVAL_COMMAND="$fake_direct_read" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 13 2>&1); then
  pass "対象 SKILL.md の直接 Read を skill 選択として扱わない"
else
  fail "対象 SKILL.md の直接 Read を skill 選択として扱わない" "$direct_read_output"
fi

fake_competing_read="$TEST_ROOT/claude-competing-read"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"README.md"}}]}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_competing_read"
chmod +x "$fake_competing_read" || fail "competing Read fixture を構築" "chmod failed"
if competing_read_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_competing_read" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "発火期待で先に調査toolを選んだ場合は失敗にする" "$competing_read_output"
elif [ "$?" -eq 124 ] || printf '%s\n' "$competing_read_output" | rg -qF 'error=timeout'; then
  fail "先行した調査toolを観測窓終了まで待たない" "$competing_read_output"
else
  pass "発火期待で先行した調査toolを発火先不一致にする"
fi

fake_late_skill="$TEST_ROOT/claude-late-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"README.md"}},{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_late_skill"
chmod +x "$fake_late_skill" || fail "late Skill fixture を構築" "chmod failed"
if late_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_late_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "調査toolの後からSkillを選んでも発火順序を満たさない" "$late_skill_output"
elif ! printf '%s\n' "$late_skill_output" | rg -qF 'Skill selected after competing tool: Read'; then
  fail "遅延したSkill選択を具体的に診断する" "$late_skill_output"
else
  pass "調査toolより後のSkill選択は発火順序違反"
fi

fake_other_skill="$TEST_ROOT/claude-other-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"ja-writing"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_other_skill"
chmod +x "$fake_other_skill" || fail "other Skill fixture を構築" "chmod failed"
if other_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_other_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 13 2>&1); then
  pass "対象外のskillは3 skillの誤発火に数えない"
else
  fail "対象外のskillは3 skillの誤発火に数えない" "$other_skill_output"
fi

fake_exact_skill="$TEST_ROOT/claude-exact-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_exact_skill"
chmod +x "$fake_exact_skill" || fail "exact Skill fixture を構築" "chmod failed"
if exact_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_exact_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "正確な Skill 選択と正常終了を発火として記録"
else
  fail "正確な Skill 選択と正常終了を発火として記録" "$exact_skill_output"
fi

fake_skill_clean_exit="$TEST_ROOT/claude-skill-clean-exit"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' > "$fake_skill_clean_exit"
chmod +x "$fake_skill_clean_exit" || fail "skill clean-exit fixture を構築" "chmod failed"
if skill_clean_exit_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_clean_exit" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 入力の観測とprocess回収成否を分離"
else
  fail "Skill 入力の観測とprocess回収成否を分離" "$skill_clean_exit_output"
fi

fake_skill_permission="$TEST_ROOT/claude-skill-permission"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'skill_allowed=false' \
  'previous=' \
  'for arg in "$@"; do' \
  '  [ "$previous" = "--allowedTools" ] && [ "$arg" = "Skill" ] && skill_allowed=true' \
  '  previous="$arg"' \
  'done' \
  '$skill_allowed || {' \
  '  printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true}'\''' \
  '  exit 1' \
  '}' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_skill_permission"
chmod +x "$fake_skill_permission" || fail "Skill permission fixture を構築" "chmod failed"
if skill_permission_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_permission" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "headless plan mode でも Skill tool を明示許可"
else
  fail "headless plan mode でも Skill tool を明示許可" "$skill_permission_output"
fi

fake_skill_selection_only="$TEST_ROOT/claude-skill-selection-only"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'exit 0' > "$fake_skill_selection_only"
chmod +x "$fake_skill_selection_only" || fail "selection-only fixture を構築" "chmod failed"
if skill_selection_only_output=$(timeout 8 env CLAUDE_EVAL_COMMAND="$fake_skill_selection_only" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択確定後は task 完了を待たず process group を回収"
else
  fail "Skill 選択確定後は task 完了を待たず process group を回収" "$skill_selection_only_output"
fi

fake_skill_then_result_error="$TEST_ROOT/claude-skill-then-result-error"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'sleep 0.1' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"injected after selection"}'\''' > "$fake_skill_then_result_error"
chmod +x "$fake_skill_then_result_error" || fail "selection result-error fixture を構築" "chmod failed"
if skill_then_result_error_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_then_result_error" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後のtask errorを発火評価へ混ぜない"
else
  fail "Skill 選択時点で発火結果を確定する" "$skill_then_result_error_output"
fi

fake_skill_runner_termination_result="$TEST_ROOT/claude-skill-runner-termination-result"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'process.on("SIGTERM", () => {' \
  '  console.log(JSON.stringify({ type: "result", is_error: true }));' \
  '  setTimeout(() => process.exit(143), 100);' \
  '});' \
  'console.log(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "skill-1", name: "Skill", input: { skill: "standard-apply" } }] } }));' \
  'setInterval(() => {}, 1000);' > "$fake_skill_runner_termination_result"
chmod +x "$fake_skill_runner_termination_result" || fail "runner termination result fixture を構築" "chmod failed"
if skill_runner_termination_result_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_skill_runner_termination_result" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後に runner 自身が生じさせた result error は発火失敗にしない"
else
  fail "Skill 選択後に runner 自身が生じさせた result error は発火失敗にしない" "$skill_runner_termination_result_output"
fi

fake_skill_runner_malformed="$TEST_ROOT/claude-skill-runner-malformed"
printf '%s\n' \
  '#!/usr/bin/env node' \
  'process.on("SIGTERM", () => {' \
  '  console.log("not-json");' \
  '  setTimeout(() => process.exit(143), 100);' \
  '});' \
  'console.log(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", id: "skill-1", name: "Skill", input: { skill: "standard-apply" } }] } }));' \
  'setInterval(() => {}, 1000);' > "$fake_skill_runner_malformed"
chmod +x "$fake_skill_runner_malformed" || fail "runner malformed fixture を構築" "chmod failed"
if skill_runner_malformed_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_skill_runner_malformed" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後の壊れた出力は確定済み発火を変えない"
else
  fail "Skill 選択後の壊れた出力は確定済み発火を変えない" "$skill_runner_malformed_output"
fi

fake_partial_skill="$TEST_ROOT/claude-partial-skill"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply-extra"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' > "$fake_partial_skill"
chmod +x "$fake_partial_skill" || fail "partial Skill fixture を構築" "chmod failed"
if partial_skill_output=$(CLAUDE_EVAL_COMMAND="$fake_partial_skill" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "部分一致の skill 名を発火として扱わない" "$partial_skill_output"
elif ! printf '%s\n' "$partial_skill_output" | rg -qF 'Skill tool called with an unrecognized standard skill: standard-apply-extra'; then
  fail "部分一致の skill 名を具体的に診断する" "$partial_skill_output"
else
  pass "部分一致の skill 名は発火評価 error"
fi

fake_skill_exit_error="$TEST_ROOT/claude-skill-exit-error"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'sleep 0.1' \
  'exit 7' > "$fake_skill_exit_error"
chmod +x "$fake_skill_exit_error" || fail "skill abnormal-exit fixture を構築" "chmod failed"
if skill_exit_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_exit_error" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "Skill 選択後のtask終了を発火評価へ混ぜない"
else
  fail "Skill 選択時点で異常終了との観測境界を閉じる" "$skill_exit_output"
fi

fake_skill_exit_143="$TEST_ROOT/claude-skill-exit-143"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 143'\'' TERM' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill-1","name":"Skill","input":{"skill":"standard-apply"}}]}}'\''' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done"}'\''' \
  'sleep 0.3' > "$fake_skill_exit_143"
chmod +x "$fake_skill_exit_143" || fail "skill exit 143 fixture を構築" "chmod failed"
if skill_exit_143_output=$(CLAUDE_EVAL_COMMAND="$fake_skill_exit_143" CLAUDE_EVAL_TIMEOUT_MS=1000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  pass "runner の SIGTERM による exit 143 を発火成功として扱う"
else
  fail "runner の SIGTERM による exit 143 を発火成功として扱う" "$skill_exit_143_output"
fi

printf '\n=== 6. task evaluator は terminal result 後の hook hang を回収する ===\n'
fake_task_harness_probe="$TEST_ROOT/claude-task-harness-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'unexpected='\''情報の'\''"概観"' \
  'leaks=$(rg -lF "$unexpected" . | rg -v '\''^(\./)?principles/README\.md$'\'' || true)' \
  'if rg -q '\''injectedTypo'\'' "$runner" || [ -n "$leaks" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation harness leaked into fixture"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_task_harness_probe"
chmod +x "$fake_task_harness_probe" || fail "task harness probe fixture を構築" "chmod failed"
for eval_configuration in with-skill old-skill without-skill; do
  if task_harness_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_task_harness_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-harness-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-update --eval-id 1 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/task-harness-probe-evals/standard-update/eval-1-haiku/$eval_configuration/result.json"; then
    pass "$eval_configuration のtask fixtureからmutationを隔離"
  else
    fail "$eval_configuration のtask fixtureからmutationを隔離" "$task_harness_probe_output"
  fi
done

fake_eval_scope_probe="$TEST_ROOT/claude-eval-scope-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'scope_diff=$(git diff -- .claude/skills/standard-audit/SKILL.md)' \
  'diff_files=$(git diff --name-only)' \
  'eval_status=$(git status --short --untracked-files=all -- .claude/skills/standard-update/evals)' \
  'eval_ignored_status=$(git status --short --ignored=matching -- .claude/skills/standard-update/evals)' \
  'if [ "$diff_files" != ".claude/skills/standard-audit/SKILL.md" ] || ! rg -qF '\''+- **A 思想の足場**: root `README.md`'\'' <<< "$scope_diff"; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"instruction-only fixture diff missing"}'\''' \
  'elif rg -q '\''evalId === 4|docs/decisions/0011-deliberate-divergences'\'' "$runner" || [ -n "$eval_status" ] || [ -n "$eval_ignored_status" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation scope fixture leaked into runner"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_eval_scope_probe"
chmod +x "$fake_eval_scope_probe" || fail "evaluation scope fixture を構築" "chmod failed"
for eval_configuration in old-skill with-skill; do
  if eval_scope_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_eval_scope_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/eval-scope-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-update --eval-id 4 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/eval-scope-probe-evals/standard-update/eval-4-haiku/$eval_configuration/result.json"; then
    pass "$eval_configuration の評価範囲fixtureをdiffだけで提示"
  else
    eval_scope_result="$TEST_ROOT/eval-scope-probe-evals/standard-update/eval-4-haiku/$eval_configuration/result.json"
    fail "$eval_configuration の評価範囲fixtureをdiffだけで提示" "$eval_scope_probe_output
$(sed -n '1,80p' "$eval_scope_result" 2>/dev/null)"
  fi
done

fake_example_mutation_probe="$TEST_ROOT/claude-example-mutation-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'diff_files=$(git diff --name-only)' \
  'if [ "$diff_files" = "concerns/transaction.md" ] && rg -qF "// 二つ目の失敗を無視して成功を返す" concerns/transaction.md; then' \
  '  : ' \
  'elif [ "$diff_files" = "principles/comment.md" ] && [ "$(rg -cF "/** 素数かどうかを判定する。 */" principles/comment.md)" -eq 2 ] && ! rg -qF "@param candidate" principles/comment.md; then' \
  '  : ' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"example mutation missing or escaped its target"}'\''' \
  '  exit 0' \
  'fi' \
  'if rg -q '\''evalId === [56]|legacyExample|currentExample|defectiveExample'\'' "$runner"; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"example mutation source leaked into fixture"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_example_mutation_probe"
chmod +x "$fake_example_mutation_probe" || fail "example mutation probe fixture を構築" "chmod failed"
for eval_id in 5 6; do
  if example_mutation_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_example_mutation_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/example-mutation-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-update --eval-id "$eval_id" 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/example-mutation-probe-evals/standard-update/eval-$eval_id-sonnet/with-skill/result.json"; then
    pass "eval-$eval_id は対象1ファイルへ欠陥を注入して mutation source を隔離"
  else
    example_mutation_result="$TEST_ROOT/example-mutation-probe-evals/standard-update/eval-$eval_id-sonnet/with-skill/result.json"
    fail "eval-$eval_id の欠陥注入と mutation source 隔離を検査" "$example_mutation_probe_output
$(sed -n '1,80p' "$example_mutation_result" 2>/dev/null)"
  fi
done

fake_task_claude="$TEST_ROOT/claude-task-result"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'wait' > "$fake_task_claude"
if ! chmod +x "$fake_task_claude"; then
  fail "task evaluator fixture を構築" "chmod failed"
elif task_output=$(timeout 4 env CLAUDE_EVAL_COMMAND="$fake_task_claude" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  task_timing="$TEST_ROOT/task-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ ! -f "$task_timing" ]; then
    fail "task evaluator が timing artifact を保存する" "$task_output"
  elif ! node -e 'const value=JSON.parse(require("node:fs").readFileSync(process.argv[1],"utf8")); process.exit(value.terminal_result_received === true && value.terminated_after_result === true ? 0 : 1)' "$task_timing"; then
    fail "terminal result 後の process を回収する" "$(sed -n '1,120p' "$task_timing")"
  else
    pass "terminal result 後の hook hang を成功として回収"
  fi
else
  task_timing="$TEST_ROOT/task-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_timing" ]; then
    task_output="$task_output
$(sed -n '1,120p' "$task_timing")"
  fi
  fail "terminal result 後の hook hang を成功として回収" "$task_output"
fi

fake_task_error="$TEST_ROOT/claude-task-error"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'exit 7' > "$fake_task_error"
chmod +x "$fake_task_error" || fail "task abnormal-exit fixture を構築" "chmod failed"
if task_error_output=$(CLAUDE_EVAL_COMMAND="$fake_task_error" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-error-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  fail "terminal result 直後の異常終了を成功にしない" "$task_error_output"
elif ! printf '%s\n' "$task_error_output" | rg -qF 'unexpected exit after terminal result: status=7'; then
  task_error_timing="$TEST_ROOT/task-error-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_error_timing" ]; then
    task_error_output="$task_error_output
$(sed -n '1,120p' "$task_error_timing")"
  fi
  fail "terminal result 直後の異常終了を診断する" "$task_error_output"
else
  pass "terminal result 直後の異常終了は task eval error"
fi

fake_task_exit_after_timer="$TEST_ROOT/claude-task-exit-after-timer"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 7'\'' TERM' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'sleep 0.3' > "$fake_task_exit_after_timer"
chmod +x "$fake_task_exit_after_timer" || fail "task delayed abnormal-exit fixture を構築" "chmod failed"
if task_exit_after_timer_output=$(CLAUDE_EVAL_COMMAND="$fake_task_exit_after_timer" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-exit-after-timer-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  fail "回収要求と競合した task 異常終了を成功にしない" "$task_exit_after_timer_output"
elif ! printf '%s\n' "$task_exit_after_timer_output" | rg -qF 'unexpected exit after terminal result: status=7'; then
  task_exit_after_timer_timing="$TEST_ROOT/task-exit-after-timer-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_exit_after_timer_timing" ]; then
    task_exit_after_timer_output="$task_exit_after_timer_output
$(sed -n '1,120p' "$task_exit_after_timer_timing")"
  fi
  fail "回収要求と競合した task 異常終了を具体的に診断する" "$task_exit_after_timer_output"
else
  pass "回収要求と競合した task 異常終了は eval error"
fi

fake_task_exit_143="$TEST_ROOT/claude-task-exit-143"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'trap '\''exit 143'\'' TERM' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'sleep 0.3' > "$fake_task_exit_143"
chmod +x "$fake_task_exit_143" || fail "task exit 143 fixture を構築" "chmod failed"
if task_exit_143_output=$(CLAUDE_EVAL_COMMAND="$fake_task_exit_143" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-exit-143-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  pass "runner の SIGTERM による task exit 143 を成功として扱う"
else
  task_exit_143_timing="$TEST_ROOT/task-exit-143-evals/standard-apply/eval-1-haiku/with-skill/timing.json"
  if [ -f "$task_exit_143_timing" ]; then
    task_exit_143_output="$task_exit_143_output
$(sed -n '1,120p' "$task_exit_143_timing")"
  fi
  fail "runner の SIGTERM による task exit 143 を成功として扱う" "$task_exit_143_output"
fi

fake_task_exited_leader="$TEST_ROOT/claude-task-exited-leader"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  '( trap '\'''\'' TERM; sleep 5 ) &' \
  'exit 0' > "$fake_task_exited_leader"
chmod +x "$fake_task_exited_leader" || fail "task exited-leader fixture を構築" "chmod failed"
if task_exited_leader_output=$(timeout 8 env CLAUDE_EVAL_COMMAND="$fake_task_exited_leader" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-exited-leader-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
  pass "terminal result 後に leader が終了しても子孫を回収"
else
  fail "terminal result 後に leader が終了しても子孫を回収" "$task_exited_leader_output"
fi

printf '\nテスト: %d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -eq 0 ]; then
  exit 0
fi
exit 1
