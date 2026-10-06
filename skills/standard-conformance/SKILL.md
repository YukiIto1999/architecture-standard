---
name: standard-conformance
description: architecture-standard に対する対象プロジェクトの適合性を読み取り専用で監査し、設定 drift と規律違反を baseline 差分管理可能な JSON 形式で報告する。「標準に適合しているか検査」「設定 drift を確認」「conformance baseline と比較」「適合性を JSON で報告」と指定された作業では、調査や編集に着手する前に、この skill を必ず使う。修正、コードの書き換え、標準本文の編集は行わない。対象 project への設計と実装は standard-apply、標準本文の改訂は standard-update、標準側の不備の還流は standard-feedback を使う。
---

# standard-conformance

対象プロジェクトが `architecture-standard` に適合しているかを読み取り専用で監査する Skill である。
コードや基線台帳は編集せず、監査結果と基線台帳との差分を報告する。
違反が見つからないことと、全域の調査が完了したことを分ける。

## 前提

- この Skill の所在（`skills/standard-conformance/SKILL.md`）から二段上の親 directory を `<standard-root>` として固定する。
- 基準は `<standard-root>` の現在の `README.md` と、`principles/`、`concerns/`、`structure/`、`tools/`、`languages/`、`process/` 配下の規範文書とする。
- 対象 project の directory を `<project-root>` とし、その directory を含む Git repository と Node.js、Git を使える環境で監査する。
- 基線台帳は対象 project の `docs/conformance-baseline.json` とし、`baseline.file` もこの project 相対 path と完全に一致させる。
- JSON 報告の `<report-path>` は対象 project を含む Git repository の外に置く。
  報告を書いて source の fingerprint を変えないためであり、基線台帳は project 内に保持して fingerprint に含める。
  この外部報告以外は、標準と対象 project のどちらも編集しない。

## 監査手順

### inventory

全域監査は、現在の正本と対象 project から期待文書集合と digest を取得して始める。

```bash
node "<standard-root>/skills/standard-conformance/scripts/check-coverage.mjs" inventory \
  --standard-root "<standard-root>" --project-root "<project-root>"
```

stdout の `status: INVENTORY` と `standardDigest`、`projectDigest`、`documents`、`requiredChecks` を保持し、`documents` にある全相対 path の disposition を報告へ残す。
期待集合は root `README.md` と六領域配下の全 Markdown 文書から自動導出されるため、固定した文書一覧や以前の監査結果で置き換えない。
`requiredChecks[document]` は、その文書について正本から導いた `[{rule: "file#heading", kinds: ["machine", "review"]}]` の形の検査割当であり、`kinds` は規律ごとの実際の割当に従う。
割当は principles と concerns の概念 README の規律台帳、および `languages/*/inspection.md` の対応表から取得され、別の registry で管理しない。
各領域の欠落や空、正本の読取失敗、Git repository に含まれない対象は開始条件を満たさない。
CLI を使えない場合は欠けている実行環境や配備物を報告し、監査完了や PASS、WARN としない。

`standardDigest` は現在の期待文書の path と内容に基づく。
`projectDigest` は、対象 project を含む Git repository 全体の tracked file と ignore されていない untracked file の path と内容、Git root からの project 相対 path、当該 project の基線台帳の有無と内容に基づく。
基線台帳は Gitignore の対象でも fingerprint に含め、同じ checkout 内の別 project へ報告を使い回さない。
project が Git root の配下なら、project 外の関連設定も含めて checkout の鮮度を確かめる。
digest は今回の観測の鮮度を確かめる値であり、標準の過去版への固定ではない。
観測後に正本や対象 source、基線台帳が変わったら、inventory を取り直して変更の影響を再評価する。
captured digest だけを新しい値へ書き換え、以前の証拠を新しい評価として扱わない。

### 照合

1. `<standard-root>/README.md` と [process/audit.md](../../process/audit.md) を読み、現在の判定の枠と監査順序を使う。
   対象 project の README、manifest、source、設定、test、決定の記録から、言語、実行経路、境界、依存方向、検証入口を確認する。
2. 監査順序に沿って、設定 drift、境界、横断規律、原則、言語と道具の規律を照合する。
   `BannedSymbols`、`clippy.toml`、`oxlint`、`biome`、`.editorconfig` 等の設定は、対象が採用している機構について確認する。
3. 文書ごとに適用条件を source と project の出典で判断し、`checked`、`not-applicable`、`unresolved` のいずれかを記録する。
   すべての言語や道具を一律に適用対象へしない一方、条件付きの文書も期待集合から削除しない。
   未読、未調査、証拠不足は非適用の理由にせず、`unresolved` と不足する根拠を残す。
4. 適用する規律は [structure/tests/methods.md](../../structure/tests/methods.md) の割当方針と inventory の `requiredChecks` に従い、対象 project の検証入口の実行とレビューで照合する。
   割当のある文書は、各規律を `checks.rule` で完全に一致する正本の `file#heading` として指し、要求された kind ごとに検査を残す。
   machine と review の両方を要求する規律は、片方だけで完了としない。
   実行結果には command と結果の locator、レビュー結果には対象と判断の locator を残す。
   独立レビューと報告する場合は、独立した context の実際の記録を示す。
   正本や source を読んだ記録は `entries[].evidence` に残し、それだけで実行や独立レビューを済ませた `checks` にしない。
   意味を伴う判断は root README の適用判断に従い、既存の `reason`、`evidence`、review の locator の参照先へ、規律の条件と対象の事実から結論を導いた根拠を残す。
   見出しの名指しや形式検査の成功だけで適合とせず、読取、適用判断、実検証を区別する。
   文書の一部の規律だけが条件を満たさない場合は、その rule の適用判断を `kind: applicability`、`status: not-applicable` として理由と source、project の出典とともに残す。
   適用判断は実行検査の成功ではなく、同じ rule の machine や review と併記しない。
5. 違反を root README と process/audit の引用規則に従って記録し、project の実基線台帳と照合する。
   実行できなかった検査は `not-run`、判断できなかった文書は `unresolved` のまま残す。
6. JSON 報告を `<report-path>` に保存し、末尾の完了検査を実際に実行する。

## 出力仕様

監査報告は `violations`、`baseline`、`coverage` を持つ JSON とする。
次は形式の例であり、digest、path、出典、検査結果は実際の観測値に置き換える。
`coverage.entries` は例の文書だけで終えず、inventory の全期待文書について一件ずつ記録する。

```json
{
  "violations": [
    {
      "rule": "<標準ファイルの相対パス>#<該当見出し>",
      "file": "<プロジェクト内の相対ファイルパス>",
      "line": 42,
      "evidence": "<引用した規律本文と規律に反している観測事実>",
      "mechanizable": false
    }
  ],
  "baseline": {
    "file": "docs/conformance-baseline.json",
    "status": "new-violations-found",
    "newCount": 1,
    "baselineCount": 0,
    "resolvedCount": 0
  },
  "coverage": {
    "standardDigest": "<inventory の standardDigest>",
    "projectDigest": "<inventory の projectDigest>",
    "entries": [
      {
        "document": "<違反の rule が指す標準ファイルの相対パス>",
        "disposition": "checked",
        "evidence": [
          "<source: 標準本文の path と見出し>",
          "<project: 対象 source の path と行>"
        ],
        "checks": [
          {
            "rule": "<標準ファイルの相対パス>#<該当見出し>",
            "kind": "machine",
            "status": "failed",
            "evidence": "<tool: 実行 command と失敗結果の locator>"
          },
          {
            "rule": "<標準ファイルの相対パス>#<該当見出し>",
            "kind": "review",
            "status": "passed",
            "evidence": "<tool: レビュー記録の locator>"
          },
          {
            "rule": "<同じ文書内の条件付き規律の相対パス>#<該当見出し>",
            "kind": "applicability",
            "status": "not-applicable",
            "reason": "<この規律の適用条件を対象が満たさない理由>",
            "evidence": "<source と project: 適用条件と対象の観測を辿れる locator>"
          }
        ]
      },
      {
        "document": "<非適用と判断した標準ファイルの相対パス>",
        "disposition": "not-applicable",
        "evidence": [
          "<source: 適用条件を定める標準本文>",
          "<project: 対象が適用条件を満たさない根拠>"
        ],
        "reason": "<適用条件と対象の観測を対応付けた非適用理由>"
      },
      {
        "document": "<判断が未確定の標準ファイルの相対パス>",
        "disposition": "unresolved",
        "evidence": [
          "<project: 調査済み範囲または不足を観測した記録>"
        ],
        "reason": "<判断に不足している根拠>"
      }
    ]
  }
}
```

`evidence` は source、project、tool の出典を辿れる非空の locator とし、`entries[].evidence` は空でない配列にする。
`checked` は空でない `checks` に加え、割当の有無にかかわらず、machine または review の `passed` か `failed` という実照合結果を少なくとも一件必要とする。
machine と review の検査は `kind: machine | review`、`status: passed | failed | not-run`、非空の `evidence` を持つ。
`checks.rule` を記録する場合は、同じ `document` の規律を指す。
検査割当がある文書は、`requiredChecks[document]` の各 rule を `checks.rule` で完全に一致させ、要求されたすべての kind について検査結果を残す。
一件の `review/passed` を、その文書に割り当てられた machine や他の規律の検査の代わりにしない。
文書内の条件付き規律を非適用にする場合は、その rule に `kind: applicability`、`status: not-applicable`、非空の `reason`、source と project の根拠を辿れる `evidence` を残す。
同じ rule の非適用と machine または review の結果の併記は、割当表に現れない rule も含めて矛盾として拒否される。
適用判断だけでは `checked` としない。
割当の全規律が非適用だけなら、文書の disposition を根拠付きの `not-applicable` にする。
割当表のない文書も、非空の machine または review の実照合結果と証拠を必要とする。
`failed` は、`checks.rule` があればその規律と完全に一致する `violations[].rule` を伴い、なければ文書全体の失敗としてその `document` を指す違反を伴う。
同じ文書に別の既存違反があっても、失敗した規律の違反報告の代わりにしない。
必要な kind の欠落や `not-run` は未完了とする。
`not-applicable` と `unresolved` は根拠となる `evidence` と非空の `reason` を持ち、`unresolved` は未完了とする。
違反なしの `violations: []` でも、文書の欠落、未確定、未実行があれば監査完了にはならない。

`baseline.status` は `matched`、`new-violations-found`、`baseline-not-found` のいずれかを参考値として残す。
報告内の `newCount`、`baselineCount`、`resolvedCount` は自己申告であり、CLI の合否根拠にはしない。

## 基線台帳

基線台帳は対象 project が所有する実ファイルであり、標準側や dotfiles 側へ移さない。
台帳の path を別の空ファイルへ切り替えて、既存違反との比較を回避しない。
内容は `{ "violations": [...] }` とし、各違反は報告と同じ `rule`、`file`、`line`、`evidence`、`mechanizable` の五つの field を持つ。
既存違反と認めるのは、実基線台帳の項目と五つすべてが一致した違反だけである。
過去の基線項目は五つの field の形式を検証するが、現在の期待文書集合にその規律の文書が残っていることは要求しない。
削除や移動された規律の旧項目も比較元とし、現在の報告に一致しない項目を `resolvedCount` に含める。
一方、現在の報告の違反は現在の期待文書を指す必要があり、未知の正本文書を指す違反は拒否される。
旧項目を現在の規範の代わりにしたり、path を読み替えて一致した既存違反にしたりしない。
報告の `baseline.status` や `newCount: 0` で実ファイルとの比較を代替しない。
基線台帳がなければ `baseline-not-found` とし、観測した違反をすべて新規として扱う。
新規違反を追記して基線を肥大化させず、解消後の削除は project 側の変更として [process/audit.md](../../process/audit.md) に従う。

## 完了検査

報告を保存した後、以下の実行経路で canonical check を実際に行い、stdout の JSON と終了コードを報告する。
直接実行する場合の入口は次の CLI とし、host の監査完了 gate を使う場合は後述の登録 command で同じ checker を実行するため、直接の check を重ねない。

```bash
node "<standard-root>/skills/standard-conformance/scripts/check-coverage.mjs" check \
  --standard-root "<standard-root>" --project-root "<project-root>" \
  --report "<report-path>"
```

報告を評価できた stdout は `status`、`coverageComplete`、`expectedDocuments`、`standardDigest`、`projectDigest`、`newCount`、`baselineCount`、`resolvedCount`、`baselineFound`、`diagnostics` を持つ。
読取や形式の不正で評価できない `INVALID` では、`status` と `diagnostics` を報告し、算出できなかった件数をゼロとみなさない。
件数は実基線台帳から再計算され、台帳がない場合は `baselineFound: false` として比較元を空集合にする。
未完了と新規違反が併存すれば `INCOMPLETE` を優先し、`diagnostics` には両方を残す。

| status | 意味 | 終了コード |
|---|---|---|
| `PASS` | 文書単位の coverage が完了し、観測した違反がない | 0 |
| `WARN` | 文書単位の coverage が完了し、実基線台帳と一致した既存違反だけがある | 0 |
| `FAIL` | 文書単位の coverage は完了しているが、新規違反がある | 1 |
| `INCOMPLETE` | 文書の disposition、証拠、検査結果が完了条件を満たさないか、digest が古い | 1 |
| `INVALID` | 報告が不正、または正本、project、報告、基線台帳を読めない | 2 |

CLI の結果が `INCOMPLETE`、`INVALID`、`FAIL` なら、PASS や WARN として報告しない。
未実行の CLI を通過したものと扱わない。
文書の欠落、余分、重複、不足証拠、正本に割り当てられた rule や kind の欠落、`not-run`、`unresolved`、古い digest、新規違反は完了検査を通過しない。
全文書を `not-applicable` にした場合や、適用判断だけで実照合結果が一件もない場合は、空の監査として未完了とする。

完了検査が確かめるのは、現在の期待集合に対して文書単位の coverage が閉じ、正本から導いた検査割当ごとに実検査または根拠付きの非適用判断が残り、実基線台帳との差分が合格条件を満たすことである。
割当のない全規範命題を新たに抽出する検査ではなく、引用の意味、適用判断の妥当性、証拠の真偽、文書内の全規範命題への実検査は保証しない。
project の analyzer や実行テスト、独立レビューの代わりではなく、すべての設計思想を機械検証したことにもならない。

### host の監査完了 gate

dotfiles の runtime gate が session を管理する host では、直接の Node check の代わりに次の command を実行する。

```bash
dotfiles-agent-gate conformance --session "<実 session ID>" \
  --repo "<project-root>" --standard-root "<standard-root>" \
  --report "<report-path>"
```

session ID は実際の client context または stop が示した command から取得し、推測で作らない。
この adapter は成功して読んだ canonical Skill と同じ物理的な正本 root の checker を実行し、終了コード0で PASS か WARN の場合だけ receipt を記録する。
同じ本文を別の root へコピーして、成功読取した正本束との照合を回避しない。
この Skill の canonical 本文を成功して読んだ session は、stop でその receipt を必要とする。
stop は現在の inventory と、Skill、正本、project source、報告、checker の鮮度を照合し、同じ観測に対する check を重ねて実行しない。
正本や source が変わった場合は再評価し、Skill の配備内容が変わった場合は canonical 本文を読み直してから、登録 command を実行し直す。

checker と規範の正本は architecture-standard が、receipt と stop の強制は dotfiles の runtime が所有する。
runtime gate がない host では Node CLI を直接実行し、その CLI を CI や検証入口へ接続する責務は対象 project の所有者へ渡す。
読み取り専用監査で CI 設定を勝手に編集せず、未接続の状態を自動 stop 強制済みとして報告しない。
gate があっても必要な checker が旧配備にない場合は、source の更新と再配備を不足する前提として報告し、receipt 登録済みとは扱わない。

## Non-goals

- 指摘の修正やコードの書き換えは行わず、修正は `standard-apply` と [process/implementation.md](../../process/implementation.md)、[process/refactoring.md](../../process/refactoring.md) へ渡す。
- 標準側の本文や規律を編集せず、標準側の矛盾や不足は `standard-feedback` へ渡す。
