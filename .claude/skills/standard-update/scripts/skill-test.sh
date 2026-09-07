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

skill_root() {
  # 全 skill を .claude/skills へ揃えない。dotfiles の plugin loader は repository root の skills/ だけを走査するため、配布する skill はそこが正本になる
  case "$1" in
    standard-apply|standard-conformance|standard-feedback) printf 'skills/%s' "$1" ;;
    *) printf '.claude/skills/%s' "$1" ;;
  esac
}

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

expect_eval_prompt_no_text() {
  local label="$1"
  local eval_id="$2"
  local pattern="$3"
  local eval_file="$4"
  if node -e '
    const fs = require("node:fs");
    const [file, id, pattern] = process.argv.slice(1);
    const item = JSON.parse(fs.readFileSync(file, "utf8")).evals.find((entry) => String(entry.id) === id);
    if (!item) process.exit(2);
    process.exit(new RegExp(pattern).test(item.prompt) ? 1 : 0);
  ' "$eval_file" "$eval_id" "$pattern"; then
    pass "$label"
  else
    fail "$label" "eval $eval_id prompt に含めない: $pattern"
  fi
}

expect_eval_prompt_text() {
  local label="$1"
  local eval_id="$2"
  local pattern="$3"
  local eval_file="$4"
  if node -e '
    const fs = require("node:fs");
    const [file, id, pattern] = process.argv.slice(1);
    const item = JSON.parse(fs.readFileSync(file, "utf8")).evals.find((entry) => String(entry.id) === id);
    if (!item) process.exit(2);
    process.exit(new RegExp(pattern).test(item.prompt) ? 0 : 1);
  ' "$eval_file" "$eval_id" "$pattern"; then
    pass "$label"
  else
    fail "$label" "eval $eval_id prompt に含める: $pattern"
  fi
}

printf '=== 1. skill の指示整合 ===\n'
expect_no_text \
  "全領域へ6節を一律要求しない" \
  '^6節で書く。要求・根拠・完了条件・禁止事項・行動・例。$' \
  .claude/skills/standard-update/SKILL.md \
  .claude/skills/standard-update/references/verification-duplication.md \
  .claude/skills/standard-update/references/evaluation.md
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
  skills/standard-apply/SKILL.md \
  skills/standard-apply/references/target-scoping.md \
  skills/standard-apply/references/change-contract.md \
  skills/standard-apply/references/recovery.md \
  skills/standard-apply/references/audit-review.md
expect_text \
  "利用不能な capability の扱いを明記する" \
  '利用できない|利用不能|fallback|代替' \
  skills/standard-apply/SKILL.md \
  .claude/skills/standard-audit/SKILL.md \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "apply は pending を完了扱いしない" \
  'pending のまま完了と書かない' \
  skills/standard-apply/references/audit-review.md
expect_text \
  "apply は現在の標準本文を基準にする" \
  '標準本文は常に `<standard-root>` にある現在の規範文書' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は標準の過去版を基準にしない" \
  '標準の過去版を Git 履歴から掘り出して判断基準に' \
  skills/standard-apply/SKILL.md
expect_no_text \
  "apply は準拠 commit を基準へ戻さない" \
  'standard_commit|準拠 commit|準拠 ADR|準拠基準|recorded-commit' \
  skills/standard-apply/SKILL.md \
  skills/standard-apply/references/target-scoping.md \
  skills/standard-apply/references/change-contract.md \
  skills/standard-apply/references/recovery.md \
  skills/standard-apply/references/audit-review.md
expect_text \
  "apply は標準rootをskillの所在から固定する" \
  '二段上の親 directory' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は監査対象を読む前に基準の前処理を閉じる" \
  '対象 source の意味監査を始めない' \
  skills/standard-apply/references/audit-review.md
expect_text \
  "apply は severity 対応を改変せず固定する" \
  'severity 対応を一字一句そのまま' \
  skills/standard-apply/references/audit-review.md
expect_no_text \
  "apply は現行 severity の具体値を重複固定しない" \
  '必須構成と layout の不達は major' \
  skills/standard-apply/SKILL.md \
  skills/standard-apply/references/target-scoping.md \
  skills/standard-apply/references/change-contract.md \
  skills/standard-apply/references/recovery.md \
  skills/standard-apply/references/audit-review.md
expect_text \
  "apply は証拠のない監査 step を実施済みにしない" \
  'tool output または直接の読取証拠がない step を実施済みにしない' \
  skills/standard-apply/references/audit-review.md
expect_text \
  "audit は反証を探してから指摘する" \
  '反証として探す' \
  .claude/skills/standard-audit/SKILL.md
expect_no_text \
  "audit skill は git 管理外の docs path を含まない" \
  'docs/' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は監査対象と判定 context の allowlist を分ける" \
  '監査対象 allowlist.*判定 context allowlist' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は closed list の実在数確認でも範囲外を列挙しない" \
  '実在数や命名の確認でも、allowlist 外を検索、Glob、列挙しない' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は closed list の外にある reference や検査scriptを確認しない" \
  'reference や検査 script が必要か判断するために一覧外を読まず' \
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
  "apply は変更前に観測結果と必須条件を変更契約へ固定する" \
  '設計案または編集を作る前に、次を一つの変更契約として固定する' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は追加要素を変更契約へ追跡する" \
  '追加する型・抽象・設定・依存・fallback は、変更契約のいずれかの条件へ直接結びつくものだけ' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply の最小化は必須条件を削らない" \
  '受入条件、標準の必須規律、安全、互換性、必要な検証を削らず' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は隣接課題を変更へ取り込まない" \
  '隣接課題は、変更契約の成立、安全、互換性を左右する場合だけ未確定条件へ含める' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は現在modeの完了条件で止める" \
  '現在のモードで変更契約に対して実測できる条件を確かめ、未実装・未実行の条件を分けて報告した時点で止める' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は標準参照の節約を対象projectの調査不足へ転用しない" \
  'ここまでの参照制限は標準本文に適用する' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は新要素の前に変更不要と削除を判定する" \
  '変更不要、不要な既存要素の削除' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は最初の十分な段で止める" \
  '満たした最初の段で止める' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は必須条件Unknownの段を十分としない" \
  '必須条件の一つでも Unknown なら、その段を満たすと判定しない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は未確定段を暫定として選択保留する" \
  '最も早く成立しうる段として暫定記録し、未確認契約が閉じるまで段の選択を保留する' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は後段を不要という否定にも触れない" \
  '「新しい依存は不要」「独自実装は不要」「後続の段は検討しない」のような否定文も、後段への言及なので書かない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は前段を退けた根拠を記録する" \
  'それより前の各段では満たせない変更契約の条件を記録' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は設計依頼で未要求の成果物を作らない" \
  'ADR、設計書、報告 file への記録を依頼されていなければ file を作らず' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はexact path指定時のGlobを完了扱いしない" \
  'Glob を使った場合は参照規律を満たしていない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はexact file指定時に対象projectのGlobを手段から外す" \
  'exact file path がある.*その file を Read で直接読む.*対象 project への Glob' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は入口をtool call前に一つ選ぶ" \
  '対象 project へ最初の tool call を行う前に、次の入口を一つだけ選ぶ' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はexact file作業で関連確認にもGlobしない" \
  'project ADR、caller、state、test の確認にも Glob を使わない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はproject契約ADRを回収語の限定Grepで発見する" \
  'authority 型または受入語のうち最も固有な一語を選び、その exact token の一回の Grep' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は設計前にADRとtestの追跡gateを閉じる" \
  '設計本文を書く前に、受入条件の意味を持つ project ADR と既存 test の追跡を gate として閉じる' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はexact pathをdirectory列挙で再発見しない" \
  '対象 project への Glob、fd、directory 一覧、`git ls-files`' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はexact pathの直読を最初の対象project操作にする" \
  '最初の対象 project 読取または探索は、表の操作でなければならない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はexact sourceの意味設計を閉じた経路で調べる" \
  'exact source path を与えられ、受入条件に completion、state、success または failure がある設計は、次の対象 project 操作だけを記載順に行う' \
  skills/standard-apply/references/target-scoping.md
expect_text \
  "apply はexact source経路のORと全域Grepを禁止する" \
  '`\|` を含む OR pattern、project root 全域の Grep、Glob、別名 manifest の試行を使わない' \
  skills/standard-apply/references/target-scoping.md
expect_text \
  "apply はpath未指定Globを標準探索としても使わない" \
  'path 未指定の Glob は標準と対象 project の双方へ一致しうるため、標準側だけの探索としても使わない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はdirectory入口のsystem-wide作業だけ一度の限定Globを許す" \
  'system-wide な recovery または audit を要求する場合に限り、開始点の発見に Glob を一回だけ許す' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はdirectory入口のGlob patternをproject rootへ固定する" \
  'pattern は `<target-project-root>/\*\*/\*` の一つに固定' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はdirectory入口で候補名を複数回試さない" \
  '既知名の存在確認、top-level確認、source用とtest用の分割によって複数回実行しない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はroot-only recoveryの最初のGlobを一意にする" \
  '最初の対象 project 探索を文字どおり `<target-project-root>/\*\*/\*` の一回にする' \
  skills/standard-apply/SKILL.md
expect_text \
  "recovery eval はGlob回数とpatternを採点する" \
  'Glob は target-project/\*\*/\* の一回だけ' \
  skills/standard-apply/evals/evals.json
expect_text \
  "apply はroot recoveryでADRより先に一回のGlobを行う" \
  '`docs/decisions/` へ限定した project ADR の Grep もこの Glob より後に行う' \
  skills/standard-apply/references/recovery.md
expect_text \
  "recovery eval はADRをGlob由来の読取候補にしない" \
  'docs/decisions.*Glob 由来の読取候補から除く' \
  skills/standard-apply/evals/evals.json
expect_text \
  "apply はADRのGrep失敗時に列挙へfallbackしない" \
  'Grep が失敗した場合も find、Glob、directory 一覧へ切り替えず' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は未確定の失敗契約を疑似コードで潰さない" \
  '成功と同じ戻り値へ畳む疑似コードを書かない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は未確定の失敗契約があればcode fenceを出さない" \
  '未確定の必須失敗契約が一つでも残る設計では.*code fence を最終応答へ置かない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は検証の観測条件を具体化する" \
  '対象入力または setup、観測する値、合格となる期待結果' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は構造再生をrecoveryから始める" \
  '構造再生の複合依頼は recovery を読み取り専用で先に完了' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はrecoveryの根拠状態と決定状態を分離する" \
  '主張 / 根拠状態 / locator または導出 / 意図状態 / 変更先状態 / 未解決境界' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は意図と変更先を別の列へ置く" \
  '意図状態を `Intended`、明示的に決定した変更先を述べる主張だけは変更先状態を `Target`' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は一主張が意図と変更先を兼ねたら行を分ける" \
  '現在の意図と将来の変更先を同時に述べる場合は二行へ分ける' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は受入語のauthorityと既存testまで追う" \
  'Accepted な契約、state authority、writer、caller、既存 test を一段ずつ追い' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はtask終了とdomain completionを同一視しない" \
  'future または task の終了と、domain の terminal state または永続化された authority の更新を同じ completion とみなさない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はjoinだけでdomain completionを満たしたとしない" \
  '「全 job の完了後に返る」「completion の受入条件を満たす」と書かない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はdomain authorityの検証caseを省かない" \
  '`並行度 / task 回収 / domain authority` の三 case を必ず別々に置く' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はpermitを親で待ってからspawnしない" \
  '親が permit を取得してから task を spawn する構造へ変えない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はpermit待ちをjob task内の取消優先に保つ" \
  '`JoinSet` に束ねた job task 内で取消優先の permit 待ちを行うことを必須構造' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は既存testを公開callerと結果から探す" \
  '一段上の公開 caller の exact symbol を一回だけ、manifest または明示契約から確認した test root で Grep' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はtest rootを慣例から推測しない" \
  'test root を確認できなければ慣例から推測せず Unknown にする' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はAcceptedをOR検索して全ADRを読まない" \
  '`Status: Accepted\|<受入語>\|<authority型>` の OR 検索で全 Accepted ADR を候補にしない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は公開symbolから契約ADRとauthorityを順に追う" \
  '対象 source の公開 symbol と同じ exact token を `docs/decisions/` で一回 Grep.*ADR が authority 型を名指しする場合だけ、その exact 型名を source root で一回 Grep' \
  skills/standard-apply/references/target-scoping.md
expect_text \
  "apply はstandard rootをrev-parseで再発見しない" \
  '`pwd` や `git rev-parse` で standard root を再発見しない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply の設計応答は将来のartifact指示を足さない" \
  '依頼が設計だけなら、将来の ADR、file 作成、cleanup、別変更の指示も削除する' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply はcallerとstateのOR検索でtestを広げない" \
  'caller、状態、型の OR 検索や対象 project root 全域の Grep で無関係な test を候補にしない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は内部関数名だけで公開callerのtest不在を判定しない" \
  '変更対象の内部関数名だけを検索語にして公開 caller の test を不在と判定しない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は外部cancellationをsibling取消と分ける" \
  'caller からの cancellation または deadline を子へ伝播する契約を別々の必須条件' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は未観測関数へ既存責務を発明しない" \
  '未観測の関数または module に、state authority の更新、失敗翻訳、cleanup などの責務を割り当てない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は全recovery行へ根拠状態を一つ要求する" \
  '根拠状態 cell は `Known`、`Derived`、`Observed`、`Assumed`、`Unknown` の語だけ' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はsourceの現在値をObservedにする" \
  'source、test、設定、実行結果として現在そうである主張を `Observed`' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はユーザーの仮説をKnownにしない" \
  'ユーザー入力でも、質問、提案、仮説、記憶、不確かさを伴う説明、調査してほしい候補は `Known` にせず' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はユーザー仮説をAssumedの独立行に残す" \
  'ユーザーが示した仮説は、その仮説自体を `Assumed` の独立した行に残す' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はGlob未発見をproject全体の不存在へ広げない" \
  'Glob が返した非 hidden の候補内で未発見だったことまでであり.*project 全体に存在しない' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は未観測範囲が残る到達可能性をUnknownにする" \
  '未定義の symbol、除外した artifact、未観測の呼出元または実装が一つでも残る場合.*project 全体での定義または到達可能性が `Unknown`' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はrecovery表の未解決境界列を省略しない" \
  '回収表は `主張 / 根拠状態 / locator または導出 / 意図状態 / 変更先状態 / 未解決境界` の六列を省略しない' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は一回のGlob範囲をproject全域と呼ばない" \
  '対象範囲を `target-project 全域` または `全 file` と表記せず' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はdecision軸の対象外とUnknownを分ける" \
  '主張がその軸を扱わない場合は `対象外`、扱うが根拠がない場合は `Unknown`' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はrecoveryの根拠状態を混合しない" \
  '一つの根拠状態欄へ `Known \+ Observed` のように複数値を書かない' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply はrecoveryの診断をDerivedへ分類する" \
  '診断は、根拠行から導いた `Derived` の独立した行' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は最終応答前に複合evidence cellを分割する" \
  '五つの許可語との完全一致でない cell が一つでもあれば、注記を他列へ移すか行を分割するまで完了しない' \
  skills/standard-apply/references/recovery.md
expect_text \
  "apply は表外の要約でもUnknownを網羅否定へ変えない" \
  '表で Unknown とした範囲を、表外で「実装のどこにもない」「実現されていない」「writer は存在しない」と断定しない' \
  skills/standard-apply/references/recovery.md
expect_text \
  "audit は指摘をevidenceと規範と帰結で絞る" \
  '観測した evidence、違反する規範または明示契約、準拠と違反を分ける帰結' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は10軸を指摘quotaにしない" \
  '10軸を指摘数や出力見出しの quota にしない' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は未要求の修正設計を追加しない" \
  '依頼されていない修正案、目標構造、移行手順、新しい抽象を追加しない' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "audit は該当なしの空節を出力しない" \
  '該当項目がなければ、その見出し自体を省き、`なし`、`該当なし`' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "apply は判断に使う直接参照だけを読む" \
  'その判断を変えうる直接の参照先だけを読み、答えを得た参照経路はそこで止める' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は既知のexact pathを再発見しない" \
  'exact file path を与えられた作業では、project ADR、caller、state、test の確認にも Glob を使わない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はprocessの無条件linkを必須条件として読む" \
  'process が現在のモードの順序または確認点として無条件に `従う` と定める link は、変更契約の必須条件として読む' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はconcern間linkを変更契約なしに再帰しない" \
  '読んだ concern から別 concern への link も無条件に再帰しない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はprocess stepの消込と条件付きlink全読取を混同しない" \
  'process の全 step を消し込むことと、条件付き link を全て読むことを混同しない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はdirectory linkから同階層を列挙しない" \
  'directory への link は同階層の列挙を許可しない' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply はdirectory READMEを一度だけ台帳にする" \
  'その directory の `README.md` を台帳として一度だけ読み、一つに絞る' \
  skills/standard-apply/SKILL.md
expect_text \
  "apply は未観測の契約を補って設計しない" \
  '具体的な独自型や失敗値を発明せず、必要な契約変更と確認対象を未確定の必須条件として残す' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は受入条件にない標準の安全条件を削らない" \
  '受入条件にないことを理由に標準の安全条件を削ったり、既存契約を維持できると仮定したりしない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply の設計は未観測の分岐や隣接migrationへ広げない" \
  '未観測の契約に依存する分岐や、隣接する migration の設計へ広げない' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "apply は最終応答から変更契約に不要な要素を除く" \
  '失われないものは応答から除く' \
  skills/standard-apply/references/change-contract.md
expect_text \
  "update は所有者候補の確定前にreferenceを読まない" \
  '開始時は `references/` を読まない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は明示pathを再発見しない" \
  '明示された path を Glob や path 未指定の Grep で再発見せず' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は所有者が未確定のときだけroot READMEを読む" \
  '具体的な正本 file へ一意に対応しない場合だけ root `README.md` を先に読み' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は一つの主張につき領域referenceを一つにする" \
  '分解した一つの主張につき、対応する .* を一つだけ読む' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update はreferenceの判断と停止条件を記録する" \
  '各 reference を読む前に、その reference が変えうる判断を一つ記録する。答えを得たらその参照経路を止め' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は意味変更時に下位実現を照合する" \
  '裁定が既存規律の意味を変える場合' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は台帳と既知の逆参照から下位実現を絞る" \
  '具体的な直接参照、領域の `README.md` 台帳、既知の逆参照から実現軸を一つずつ絞り' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は下位実現をrepository全域の一致検索で発見しない" \
  'repository 全域の一致検索で発見しない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update はmethodsの段4を三言語のinspectionへ直接照合する" \
  '`tools/README.md`、`tools/rust/inspection.md`、`tools/csharp/inspection.md`、`tools/typescript/inspection.md` を、この順に exact path の Read' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update は別metricの非採用と重複排除を混同しない" \
  '二つの metric を別の性質と明記しながら、重複、二重測定、または一本化を理由に片方を無効化している記述は上位判定と矛盾する' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update は未採用metricの品質判断を発明しない" \
  '非採用理由は「他方は標準の必須検証へ割り当てられていない」とだけ書く' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethodsの段4でprinciplesへ参照を広げない" \
  'この経路では開始から最終報告まで Glob と Grep、`principles/verification.md`、`references/structure.md`、script directory の列挙を使わない' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethods編集後もGrepで自己監査しない" \
  '編集後は `structure/tests/methods.md` と、編集した場合だけその exact inspection file を Read し直し、用語の存在確認にも Grep を使わない' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update は固定経路のreview差分をexact pathだけで作る" \
  '`git diff -- structure/tests/methods.md` を一回実行し、inspection file も編集した場合だけ同じ command の末尾にその exact path を加える' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update は固定経路でも独立reviewを免除しない" \
  '最終の standard-audit / 独立 reviewer は免除しない' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update は固定経路のfallback reviewで探索を増やさない" \
  'subagent が利用できない場合は、同じ既読証拠だけで自己照合し、Grep、Glob、Bash、追加の Read を呼ばない' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethods本文に同一性の全境界を要求する" \
  '不一致・適用不能・一方だけ不合格なら両方を残すこと、反例未発見だけでは同一にしないこと、実装欠陥・更新漏れだけでは別性質にしないことを全て明記する' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update は変更artifactを変更契約へ追跡する" \
  '変更する file、規律、reference、script、eval は、この変更契約へ直接結びつくものだけ' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は概念の存在だけで充足済みにしない" \
  '同じ語や趣旨があるだけでは充足済みとしない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は入力の主張を未採用の候補として扱う" \
  '入力の主張は未採用の候補であり、標準が要求すべき決定として扱わない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は候補を照合前に上位領域へ昇格させない" \
  '候補を一般化できることだけを理由に上位領域へ昇格させず' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は同じ主張を持つ既存規範を所有者候補として固定する" \
  '候補と同じ主張またはほぼ同じ主張を要求する規範文があれば、その箇所を最初の所有者候補にする' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は配置規則で既存規範の誤配置を訂正できる" \
  'root `README.md` の配置規則と知識の変更理由から誤配置を立証できる場合' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は既存規範の曖昧さを別領域への追加で解決しない" \
  '同じ主張を別領域へ追加して解決しない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は文章refactorと意味拡張と新設を分ける" \
  '充足済みで無変更、意味を保った文章のリファクタリング、既存規律の意味の拡張、新設' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は既存規律の裁定だけ規範文referenceへ送る" \
  '既存規律がある場合だけ `references/normative-quality.md`' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "規範文referenceは標準本文の欠落を補完しない" \
  '標準本文の欠落を補う規範として使わない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文referenceは無変更前の判定表を要求する" \
  '^## 無変更ゲート$' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "update は最初の十分な文章変更で止める" \
  '^### 4\. 最初の十分な変更で止める$' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は選択段より後を不採用としても比較しない" \
  '後の段は「不採用」「不要」「比較していない」と書くことも、その理由を示すこともしない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は選択段より後を内部でも判定しない" \
  '選んだ段より後は判定も記録もしない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は新資源を能力不足の場合だけ作る" \
  '既存の所有者と実行入口に置けない場合だけ' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は文章・接続・新規意味の段を排他的にする" \
  '段2は規範命題の文章だけ、段3は規範命題を変えない接続だけ、段4は新しい規範上の意味を含む変更として排他的に分類する' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は一変更へ段番号を一つだけ記録する" \
  '複数の段番号を記録しない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は段4を意味不変へ読み替えない" \
  '段4を選んだ変更は、編集後に「既存規律の意味を変えていない」または「下位実現は確認対象外」と読み替えない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は同じ性質の定義不足を段4にする" \
  '比較集合を各検証の自己申告でなく割り当て先の要求と禁止事項の全範囲から導くこと、その集合が非空であること.*合否述語の双方向の含意がなければ、その判定条件の追加は段4' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は同じ性質を同じ要求へ置換して済ませない" \
  '「同じ性質」を「同じ要求」「同じ禁止事項」「同じ目的」へ置き換えるだけでは.*段2として採用しない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update はdriftだけを別性質の根拠にしない" \
  '実装欠陥または更新漏れによる判定不一致だけを、別の性質である根拠にしない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "update は検証手段の割当をmethodsへ直接routeする" \
  '検証手段を「同じ性質」とみなして重複排除する言語非依存の判定基準を追加または変更し、特定言語の実現 file 自体の変更を依頼していない場合に限り' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update のmethods固定経路は明示された下位targetを奪わない" \
  '特定の `tools/\*/inspection.md`、tool、または複数の明示 target への変更依頼は、主張と所有者を分けて一般経路で扱う' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethods意味変更で矛盾する下位実現だけ同期する" \
  '下位実現との矛盾を確認した場合だけ、矛盾する exact inspection file も同じ変更契約で同期する' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethodsのowner判定をrootとlayoutで閉じる" \
  '`README.md`、`structure/tests/methods.md`、`structure/tests/layout.md` を、この順に exact path の Read' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethodsの三つの読取証拠なしに編集しない" \
  '三つの Read が tool evidence に揃う前に reference または編集へ進まない' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はlayout未読を後追いで正当化しない" \
  'layout を未読のまま reference を読んだ場合は、後から補って編集を続けず、この経路を未完了として止める' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethods三fileをGlobせず直接読む" \
  'exact path の Read で直接読む' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "update はmethods所有者確定後に全域Grepしない" \
  '所有者確定後の重複検索や repository-wide な自己監査を行わない' \
  .claude/skills/standard-update/references/verification-duplication.md
expect_text \
  "規範文の裁定は弱い読みと強い読みで反証する" \
  '弱い読みと強い読みを具体例で作る' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は周辺必須項目を削る読みを退ける" \
  '周辺の必須項目を一つでも不要に読める解釈' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は適用集合の一致を先に要求する" \
  '各判定が割り当てられた要求と禁止事項を特定し、それらが要求する全適用対象・入力集合を比較領域にする' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は自己申告の空集合を比較領域にしない" \
  '検証が自己申告する集合や、実装済みの case だけから比較領域を作らない.*非空の集合を標準本文から定められなければ、同じ性質とは判定しない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は交差部分だけを比較領域にしない" \
  '両集合の交差部分だけを選んで共通集合と呼ばない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は合否述語の双方向含意を要求する" \
  '一方の合格が他方の合格を含意し、かつ逆方向も成り立つ' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は反例未発見を同一性の根拠にしない" \
  '反例をまだ見つけていないことだけを、同じ性質の根拠にしない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は診断軸を必要十分条件へ昇格しない" \
  '診断で使った候補軸を、そのまま.*必要十分条件へ変えない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の重複判定は軸の同一性定義を破棄する" \
  '全軸が一致すれば同じ.*一軸でも異なれば別.*破棄する' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の重複判定は同じ分類内の反例をEdit前に作る" \
  '同じ表の行、分類名、item または label に属するが、片方にしか適用できない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "methods は一致した適用集合と双方向含意で同じ性質を判定する" \
  '同じ規範命題へ割り当てられ、そこから導いた非空の適用対象・入力集合が一致し、その集合の全要素で一方の合格が他方の合格を含意し、かつ逆方向も成り立つ' \
  structure/tests/methods.md
expect_text \
  "methods は自己申告の空集合を同じ性質にしない" \
  '各検証の自己申告から採らず、割り当て先である標準の要求と禁止事項が要求する全範囲から導く.*非空の集合を標準本文から定められなければ、同じ性質とは判定しない' \
  structure/tests/methods.md
expect_text \
  "methods は比較不能な検証を別の性質として残す" \
  '適用対象・入力集合が一致しない、一方が適用不能になる.*別の性質として両方を残す' \
  structure/tests/methods.md
expect_text \
  "methods は反例未発見だけで同じ性質にしない" \
  '反例をまだ見つけていないことだけを、同じ性質の根拠にしない' \
  structure/tests/methods.md
expect_text \
  "typescript は別metricを重複として無効化しない" \
  'cyclomatic complexity は cognitive complexity と別の性質であり、重複検証ではない.*必須の検証へ割り当てていないため' \
  tools/typescript/inspection.md
expect_text \
  "規範文の裁定はdriftを別性質の証拠にしない" \
  '欠陥または更新漏れで誤判定することは、別の性質の証拠にしない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は同一性の区分を標準本文に要求する" \
  '何が同じなら同じ単位か、少なくとも何が異なれば別の単位か' \
  .claude/skills/standard-update/references/normative-quality.md
expect_eval_prompt_no_text \
  "無変更evalは不要な一次資料調査を指示しない" \
  3 \
  '一次資料' \
  .claude/skills/standard-update/evals/evals.json
expect_eval_prompt_no_text \
  "意味拡張evalは裁定名をpromptで与えない" \
  8 \
  '意味の拡張|意味を拡張|充足済みとせず' \
  .claude/skills/standard-update/evals/evals.json
expect_text \
  "文章refactor evalは同一性条件の自己充足を問う" \
  '二つの判定を同じ性質とみなす条件を標準本文だけから一意に導けるか' \
  .claude/skills/standard-update/evals/evals.json
expect_text \
  "規範文の裁定は標準本文だけで意味を閉じる" \
  'この手順の定義を、標準本文の欠落を補う規範として使わない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の無変更ゲートは語の一致を証拠にしない" \
  '語が一致すること、既存文が多くの項目を列挙すること' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は要求から判定手段までを追跡する" \
  '違反を検出する型、静的検査、実行テスト、計測または人手条件' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は既存の判断単位を先に読む" \
  '同じ節の表・完了条件・禁止事項・行動、意味を決める直接の参照先を一つの判断単位として読む' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "規範文の裁定は一般化だけで上位所有者へ移さない" \
  'より広く書けることだけで上位領域へ移さない' \
  .claude/skills/standard-update/references/normative-quality.md
expect_text \
  "skill script を CLAUDE_SKILL_DIR から実行する" \
  'CLAUDE_SKILL_DIR' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "instruction 変更の task eval は影響する task と旧版比較へ限定する" \
  '変更した instruction の入力と観測可能な結果を prompt と expectation が直接使う task だけ' \
  .claude/skills/standard-update/references/evaluation.md
expect_text \
  "eval 定義だけの変更は変更 task の新版だけを実行する" \
  '`evals/evals.json` だけを変更した場合は、変更した task を `with-skill`' \
  .claude/skills/standard-update/references/evaluation.md
expect_text \
  "description 変更だけが full trigger eval を要求する" \
  'description または `evals/trigger-evals.json` を変更した場合.*全 query' \
  .claude/skills/standard-update/references/evaluation.md
expect_text \
  "script と reference だけの変更は model eval を要求しない" \
  '`scripts/\*` または `references/\*\.md` だけを変更し.*model eval は実行しない' \
  .claude/skills/standard-update/references/evaluation.md
expect_text \
  "標準のコード例は説明コメントを生成しない" \
  '差と帰結はコードフェンス外の本文へ置き、コード例へ説明のコメントを足さない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "標準のコード例は対象言語の全域規律を読む" \
  '例の言語を特定し、その言語の `tools/<language>/conventions.md` を読む' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "断片での表示省略を実コードの免除にしない" \
  '表示を省けるが、実コードで不要であるとは示さない' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "ドキュメントコメントの例は言語の契約記法で書く" \
  'ドキュメントコメントを表示する場合は、目的と、宣言が持つ引数・型引数・戻り値' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "ドキュメントコメント例の署名とタグを照合する" \
  '各宣言の署名と param・typeParam・returns・value を一対一で照合する' \
  .claude/skills/standard-update/SKILL.md
expect_text \
  "principles の層責務を言語規律の免除理由にしない" \
  '表示した要素自体は conventions に従う' \
  .claude/skills/standard-update/references/principles.md
expect_text \
  "全 task 三条件 benchmark を release 境界へ限定する" \
  'release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較' \
  .claude/skills/standard-update/references/evaluation.md
for skill_name in standard-apply standard-audit standard-conformance standard-feedback standard-update; do
  expect_text \
    "$skill_name の description は調査や編集より前の利用場面を示す" \
    '^description: .*調査や編集に着手する前に、この skill を必ず使う' \
    "$(skill_root "$skill_name")/SKILL.md"
  expect_no_text \
    "$skill_name の description に内部tool順序を書かない" \
    '^description: .*Read・Grep・Bash・Agent より先に Skill tool' \
    "$(skill_root "$skill_name")/SKILL.md"
done
expect_no_text \
  "audit の description は標準の変更依頼と競合しない" \
  '^description: .*標準の変更前' \
  .claude/skills/standard-audit/SKILL.md
expect_text \
  "skill 変更の実作業はproduct検査を完了条件にする" \
  'bash "\$\{CLAUDE_SKILL_DIR:-\.claude/skills/standard-update\}/scripts/skill-package-check\.sh"' \
  .claude/skills/standard-update/SKILL.md
expect_no_text \
  "skill 変更の実作業は外側の評価oracleを完了条件にしない" \
  'bash "\$\{CLAUDE_SKILL_DIR:-\.claude/skills/standard-update\}/scripts/skill-test\.sh"' \
  .claude/skills/standard-update/SKILL.md \
  .claude/skills/standard-update/references/verification-duplication.md \
  .claude/skills/standard-update/references/evaluation.md
expect_text \
  "Ponytail の一次資料を出典記録へ残す" \
  'Source: https://github\.com/DietrichGebert/ponytail/blob/main/skills/ponytail/SKILL\.md' \
  skills/standard-apply/references/provenance.md
expect_text \
  "Ponytail のlicenseを出典記録へ残す" \
  'License: MIT \(https://raw\.githubusercontent\.com/DietrichGebert/ponytail/main/LICENSE\)' \
  skills/standard-apply/references/provenance.md
expect_text \
  "Ponytail 由来の採用を出典記録へ残す" \
  '^\- Adopted:' \
  skills/standard-apply/references/provenance.md
expect_text \
  "Ponytail 由来の不採用を出典記録へ残す" \
  '^\- Rejected:' \
  skills/standard-apply/references/provenance.md
expect_text \
  "出典記録を実行時参照から外す" \
  '実行時には読まない' \
  skills/standard-apply/SKILL.md

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

printf '\n=== 2. task eval と trigger eval の schema ===\n'
eval_output=$(bash "$SCRIPT_DIR/skill-package-check.sh" 2>&1)
if [ "$?" -eq 0 ]; then
  printf '%s\n' "$eval_output"
  pass "5 skill の package 構造と eval schema が有効"
else
  fail "5 skill の package 構造または eval schema が無効" "$eval_output"
fi
package_fixture="$TEST_ROOT/package-missing-evals"
mkdir -p "$package_fixture" || fail "package checker fixture を構築" "mkdir failed"
cp -a .claude skills "$package_fixture/" || fail "package checker fixture を構築" "copy failed"
git -C "$package_fixture" init --quiet || fail "package checker fixture を構築" "git init failed"
rm -rf -- "$package_fixture/skills/standard-apply/evals"
if package_missing_output=$(cd "$package_fixture" && bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "通常実行ではskillのeval一式欠落を拒否する" "$package_missing_output"
elif ! printf '%s\n' "$package_missing_output" | rg -qF 'standard-apply: evals directory がない'; then
  fail "eval一式欠落を具体的に診断する" "$package_missing_output"
else
  pass "通常実行ではskillのeval一式欠落を拒否する"
fi
if package_isolated_output=$(cd "$package_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=with-skill bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  pass "隔離評価では選択skillの隠したevalだけを許可する"
else
  fail "隔離評価では選択skillの隠したevalだけを許可する" "$package_isolated_output"
fi
if package_partial_context=$(cd "$package_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "不完全な隔離contextでeval欠落を許可しない" "$package_partial_context"
else
  pass "不完全な隔離contextでeval欠落を許可しない"
fi
package_without_fixture="$TEST_ROOT/package-without-skill"
mkdir -p "$package_without_fixture" || fail "without-skill package fixture を構築" "mkdir failed"
cp -a .claude skills "$package_without_fixture/" || fail "without-skill package fixture を構築" "copy failed"
git -C "$package_without_fixture" init --quiet || fail "without-skill package fixture を構築" "git init failed"
rm -rf -- "$package_without_fixture/skills/standard-apply"
if package_without_output=$(cd "$package_without_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=without-skill bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  pass "without-skill隔離評価では選択packageだけの不存在を許可する"
else
  fail "without-skill隔離評価では選択packageだけの不存在を許可する" "$package_without_output"
fi
package_partial_fixture="$TEST_ROOT/package-partial-without-skill"
mkdir -p "$package_partial_fixture" || fail "partial without-skill package fixture を構築" "mkdir failed"
cp -a .claude skills "$package_partial_fixture/" || fail "partial without-skill package fixture を構築" "copy failed"
git -C "$package_partial_fixture" init --quiet || fail "partial without-skill package fixture を構築" "git init failed"
rm -f -- "$package_partial_fixture/skills/standard-apply/SKILL.md"
if package_partial_output=$(cd "$package_partial_fixture" && SKILL_EVAL_ISOLATED_SKILL=standard-apply SKILL_EVAL_CONFIGURATION=without-skill bash .claude/skills/standard-update/scripts/skill-package-check.sh 2>&1); then
  fail "without-skill隔離評価では選択packageの部分残存を拒否する" "$package_partial_output"
else
  pass "without-skill隔離評価では選択packageの部分残存を拒否する"
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
expect_no_text \
  "task evaluator はexact path routingをoracleとして注入しない" \
  'task または使用する skill が exact file path を固定した場合は Read で直接読み' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator はsnapshotのexact diff解法をoracleとして注入しない" \
  '根拠に使う exact file path だけを git diff の引数にし' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はrouting判断をtaskと対象skillへ委ねる" \
  'どれを使うかは task と、with-skill または old-skill では対象 skill の指示から判断' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はskillの最初の対象project操作を共通promptで上書きしない" \
  '対象 skill が最初の対象 project 操作または閉じた参照経路を定める場合は、他の対象 project 操作より優先' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は固定patternの試行錯誤を許さない" \
  'exact path、exact token、Glob pattern、回数を固定した場合は、その値を変えた試行や候補探索を前後に追加しない' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は一時的な ENOTEMPTY を再試行してfixtureを回収する" \
  'rmSync\(fixtureRoot, \{ recursive: true, force: true, maxRetries: [1-9][0-9]*, retryDelay: [1-9][0-9]* \}\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はsubagentなしの自己監査fallbackを明示する" \
  'skill が独立 reviewer を明示的に要求する場合だけ.*scoped self-audit' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はfallbackで閉じた経路を広げない" \
  '閉じた経路が tool または file を制限する場合は fallback でもその範囲を広げない' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator は実行中のskillから評価oracleを隠す" \
  'hideCurrentSkillEvaluationOracles\(fixtureRoot, skillName\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はfixtureからskill assertion oracleを隠す" \
  '"standard-update", "scripts", "skill-test.sh"' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task evaluator はagentへskill-test実行を許可しない" \
  'Bash\(bash \.claude/skills/standard-update/scripts/skill-test\.sh\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はagentへproduct検査の実行を許可する" \
  'Bash\(bash \.claude/skills/standard-update/scripts/skill-package-check\.sh\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はproduct検査へ選択skillを明示する" \
  'env\.SKILL_EVAL_ISOLATED_SKILL = skillName' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はproduct検査へ比較条件を明示する" \
  'env\.SKILL_EVAL_CONFIGURATION = configuration' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_line \
  "task evaluator は全skillのfixtureからmutation sourceを除く" \
  '    scrubFixtureMutationSource(fixtureRoot);' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "recovery eval はcallerをfixtureへ持つ" \
  'writeFileSync\(path.join\(targetRoot, "app", "api.rs"\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "recovery eval はstateをfixtureへ持つ" \
  'writeFileSync\(path.join\(targetRoot, "app", "state.rs"\)' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "recovery fixture はtest rootをmanifestで明示する" \
  'source root は `app/`、test root は `tests/`' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_eval_prompt_text \
  "recovery eval はユーザー仮説をKnownから分離して測る" \
  5 \
  'worker\.rs.*JobStatus.*writer.*仮説.*確認済みの仕様ではありません' \
  skills/standard-apply/evals/evals.json
expect_text \
  "recovery eval はユーザー仮説をAssumedとして採点する" \
  '根拠付き仮説を Assumed とし、Known、Observed、Intended のいずれにも読み替えない' \
  skills/standard-apply/evals/evals.json
expect_text \
  "task evaluator は履歴をsanitizeしてからfixtureを作る" \
  'initializeSanitizedRepository\(fixtureRoot\);' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task evaluator はclone元のGit objectを破棄する" \
  'rmSync\(path.join\(fixtureRoot, "\.git"\).*maxRetries:' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_text \
  "task fixture のADRは現在の標準本文を基準にする" \
  '準拠の基準は、常に現在の標準本文である。' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_no_text \
  "task fixture は標準の commit を記録しない" \
  'standard_commit' \
  .claude/skills/standard-update/scripts/run-task-evals.mjs
expect_line \
  "task evaluator はAgent toolを明示的に禁止する" \
  '      "Agent",' \
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

expect_text \
  "trigger evaluator はtaskを実行せずroutingだけを測る" \
  'これは Skill の発火先だけを測る隔離評価です。依頼そのものは実行しないでください' \
  .claude/skills/standard-update/scripts/run-trigger-evals.mjs

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
  if trigger_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_claude" CLAUDE_EVAL_TIMEOUT_MS="$timeout_ms" node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
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
if malformed_hang_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_malformed_hang" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
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
if truncated_hang_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_truncated_hang" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
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
if observation_negative_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_observation_window" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 12 2>&1); then
  pass "観測窓内に Skill がなければ非発火期待を完遂待ちなしで記録"
else
  fail "観測窓内に Skill がなければ非発火期待を完遂待ちなしで記録" "$observation_negative_output"
fi
if observation_positive_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_observation_window" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
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
if skill_after_observation_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_skill_after_observation" CLAUDE_EVAL_TIMEOUT_MS=50 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
  fail "観測窓終了後の Skill を発火成功にしない" "$skill_after_observation_output"
elif printf '%s\n' "$skill_after_observation_output" | rg -q 'selected=standard-apply|"selected_skill": "standard-apply"'; then
  fail "観測窓終了後の Skill を選択結果へ混入しない" "$skill_after_observation_output"
else
  pass "観測窓終了後の Skill は発火結果へ混入しない"
fi

fake_direct_read="$TEST_ROOT/claude-direct-read"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' '\''{"type":"assistant","message":{"content":[{"type":"tool_use","id":"read-1","name":"Read","input":{"file_path":"/tmp/fixture/skills/standard-apply/SKILL.md"}}]}}'\''' \
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
if competing_read_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_competing_read" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
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
  pass "対象外のskillは5 skillの誤発火に数えない"
else
  fail "対象外のskillは5 skillの誤発火に数えない" "$other_skill_output"
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
if skill_runner_termination_result_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_skill_runner_termination_result" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
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
if skill_runner_malformed_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_skill_runner_malformed" CLAUDE_EVAL_TIMEOUT_MS=5000 node "$SCRIPT_DIR/run-trigger-evals.mjs" standard-apply 0 2>&1); then
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
  'trigger_runner=.claude/skills/standard-update/scripts/run-trigger-evals.mjs' \
  'skill_oracle=.claude/skills/standard-update/scripts/skill-test.sh' \
  'product_check=.claude/skills/standard-update/scripts/skill-package-check.sh' \
  'if [ "$SKILL_EVAL_ISOLATED_SKILL" = standard-apply ]; then skill_root=skills/standard-apply; else skill_root=.claude/skills/$SKILL_EVAL_ISOLATED_SKILL; fi' \
  'eval_root=$skill_root/evals' \
  'task_oracle=$eval_root/evals.json' \
  'trigger_oracle=$eval_root/trigger-evals.json' \
  'unexpected='\''情報の'\''"概観"' \
  'leaks=$(rg -lF "$unexpected" . | rg -v '\''^(\./)?principles/README\.md$'\'' || true)' \
  'if git show HEAD^:"$task_oracle" >/dev/null 2>&1 || git show HEAD^:"$trigger_oracle" >/dev/null 2>&1 || git show HEAD^:"$runner" >/dev/null 2>&1 || git show HEAD^:"$trigger_runner" >/dev/null 2>&1 || git show HEAD^:"$skill_oracle" >/dev/null 2>&1; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation oracle or mutation is reachable from history"}'\''' \
  'elif [ "$SKILL_EVAL_CONFIGURATION" = without-skill ] && [ -e "$skill_root" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"selected skill package remains in without-skill fixture"}'\''' \
  'elif [ -e "$eval_root" ] || [ -e "$runner" ] || [ -e "$trigger_runner" ] || [ -e "$skill_oracle" ] || [ -n "$leaks" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"evaluation harness leaked into fixture"}'\''' \
  'elif [ -e "$product_check" ] && ! bash "$product_check" >/dev/null; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"product checker rejected isolated fixture"}'\''' \
  'elif [ "$SKILL_EVAL_ISOLATED_SKILL" = standard-update ] && [ "$SKILL_EVAL_CONFIGURATION" = with-skill ] && [ ! -e "$product_check" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"with-skill fixture lacks product checker"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_task_harness_probe"
chmod +x "$fake_task_harness_probe" || fail "task harness probe fixture を構築" "chmod failed"
for probe_skill in standard-apply standard-audit standard-conformance standard-feedback standard-update; do
  for eval_configuration in with-skill old-skill without-skill; do
    if task_harness_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_task_harness_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-harness-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill "$probe_skill" --eval-id 1 2>&1) \
      && ! rg -q '"is_error": true' "$TEST_ROOT/task-harness-probe-evals/$probe_skill/eval-1-haiku/$eval_configuration/result.json"; then
      pass "$probe_skill/$eval_configuration のtask fixtureからmutationを隔離"
    else
      fail "$probe_skill/$eval_configuration のtask fixtureからmutationを隔離" "$task_harness_probe_output"
    fi
  done
done

fake_audit_mutation_probe="$TEST_ROOT/claude-audit-mutation-probe"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'runner=.claude/skills/standard-update/scripts/run-task-evals.mjs' \
  'expected='\''要求された機能範囲、受入条件、必須規律、安全性、互換性、必要な検証は妥協なく作り切ります。'\''' \
  'injected='\''要求された範囲は、必要な品質を適切に満たします。'\''' \
  'diff_files=$(git diff --name-only)' \
  'eval_status=$(git status --short --untracked-files=all -- .claude/skills/standard-audit/evals)' \
  'if [ "$diff_files" != "principles/README.md" ] || ! rg -qF "$injected" principles/README.md; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"audit mutation missing or escaped its target"}'\''' \
  'elif [ -e "$runner" ] || [ -n "$eval_status" ]; then' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"audit mutation or oracle leaked into fixture"}'\''' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":false,"result":"done","total_cost_usd":0,"usage":{}}'\''' \
  'fi' > "$fake_audit_mutation_probe"
chmod +x "$fake_audit_mutation_probe" || fail "audit mutation probe fixture を構築" "chmod failed"
for eval_configuration in with-skill old-skill without-skill; do
  if audit_mutation_probe_output=$(CLAUDE_EVAL_COMMAND="$fake_audit_mutation_probe" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/audit-mutation-probe-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration "$eval_configuration" --skill standard-audit --eval-id 4 2>&1) \
    && ! rg -q '"is_error": true' "$TEST_ROOT/audit-mutation-probe-evals/standard-audit/eval-4-sonnet/$eval_configuration/result.json"; then
    pass "$eval_configuration のaudit fixtureからmutationとoracleを隔離"
  else
    fail "$eval_configuration のaudit fixtureからmutationとoracleを隔離" "$audit_mutation_probe_output"
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
  'elif [ -e "$runner" ] || [ -n "$eval_status" ] || [ -n "$eval_ignored_status" ]; then' \
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
  'if [ "$diff_files" = "concerns/transaction/invisible-partial-commits.md" ] && rg -qF "// 二つ目の失敗を無視して成功を返す" concerns/transaction/invisible-partial-commits.md; then' \
  '  : ' \
  'elif [ "$diff_files" = "principles/comment/declaration-contracts.md" ] && [ "$(rg -cF "/** 素数かどうかを判定する。 */" principles/comment/declaration-contracts.md)" -eq 2 ] && ! rg -qF "@param candidate" principles/comment/declaration-contracts.md; then' \
  '  : ' \
  'else' \
  '  printf '\''%s\n'\'' '\''{"type":"result","is_error":true,"result":"example mutation missing or escaped its target"}'\''' \
  '  exit 0' \
  'fi' \
  'if [ -e "$runner" ]; then' \
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
elif task_output=$(timeout 10 env CLAUDE_EVAL_COMMAND="$fake_task_claude" SKILL_EVAL_OUTPUT_ROOT="$TEST_ROOT/task-evals" node "$SCRIPT_DIR/run-task-evals.mjs" --configuration with-skill --skill standard-apply --eval-id 1 2>&1); then
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
