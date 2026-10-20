---
name: standard-conformance
description: architecture-standard に対する対象プロジェクトの適合性を読み取り専用で監査し、設定 drift と規律違反を baseline 差分管理可能な JSON 形式で報告する。「標準に適合しているか検査」「設定 drift を確認」「conformance baseline と比較」「適合性を JSON で報告」と指定された作業では、調査や編集に着手する前に、この skill を必ず使う。修正、コードの書き換え、標準本文の編集は行わない。対象 project への設計と実装は standard-apply、標準本文の改訂は standard-update、標準側の不備の還流は standard-feedback を使う。
---

# standard-conformance

対象プロジェクトが `architecture-standard` に適合しているかを読み取り専用で監査する Skill である。
適用する規律を一つずつ、対象 project の実際の source、設定、実行結果と照合し、違反、非適用、未確認を分けて報告する。
コードや基線台帳は編集せず、監査結果と基線台帳との差分を報告する。
違反が見つからないことと、全域の調査が完了したことを分ける。

## 前提

- `<standard-root>` は現行規範 root であり、標準を管理する owner が現在の規範として指定した checkout の root である。
  依頼が明示した値か、host の agent policy が案内する値を使う。
  gate がある host では `dotfiles-agent-gate standard-root` がこの値を出力する。
  この Skill の配備先、固定 Rev、remote の HEAD、`pwd`、対象 project 内の複製から導かない。
  値を得られなければ不足する前提として報告し、配備済み source の標準本文で監査を始めない。
- 基準は `<standard-root>` の現在の `README.md` と、`principles/`、`concerns/`、`structure/`、`tools/`、`languages/`、`process/` 配下の規範文書とする。
  領域の欠落や空、本文の読取失敗は不足する前提として報告する。
  旧い本文、この Skill の配備先の近くにある本文、別の root へ切り替えて監査を続けない。
- 対象 project の directory を `<project-root>` とする。
- 基線台帳は対象 project の `docs/conformance-baseline.json` とし、`baseline.file` もこの project 相対 path と完全に一致させる。
- JSON 報告は応答で返す。file として保存する場合の `<report-path>` は、対象 project を含む Git repository の外に置く。
  この外部報告以外は、標準と対象 project のどちらも編集しない。

## 監査手順

### 規律の列挙

全域監査は、現在の標準から照合する規律を取得して始める。
`<standard-root>/README.md` の領域表と六領域の README を読み、六領域配下の全 Markdown 文書を列挙する。
principles と concerns は概念 README の規律台帳、languages は `languages/*/inspection.md` の対応表から、規律を `<標準ファイルの相対パス>#<見出し>` の単位で取得する。
台帳のない領域は、文書が定める構成、依存方向、採用 entry、順序と確認点を単位にする。
固定した文書一覧や以前の監査結果で置き換えず、全文書を少なくとも一つの項目で扱う。
台帳の検証欄が割り当てる機械検査とレビューは、規律ごとの照合手段として保持する。
検証欄の「…対象について、」は適用対象の説明として読み、後続の割当を保持する。
この説明だけで非適用とせず、対象との照合結果を残す。
言語の対応表を、既知の見出しと3列の表、少なくとも一つの検証割当として読めない場合は、その言語の規律を未確認にする。
未知の構造を「割当なし」へ読み替えて合格させない。
監査の途中で正本、対象 source、基線台帳が変わったら、影響する規律を読み直し、以前の観測を新しい評価として扱わない。

### 照合

1. `<standard-root>/README.md` と `<standard-root>/process/audit.md` を読み、現在の判定の枠と監査順序を使う。
   対象 project の README、manifest、source、設定、test、決定の記録から、言語、実行経路、境界、依存方向、検証入口を確認する。
2. 監査順序に沿って、設定 drift、境界、横断規律、原則、言語と道具の規律を照合する。
   `BannedSymbols`、`clippy.toml`、`oxlint`、`biome`、`.editorconfig` 等の設定は、対象が採用している機構について確認する。
3. 規律ごとに適用条件を標準本文と project の出典で判断し、`checked`、`not-applicable`、`unresolved` のいずれかを記録する。
   すべての言語や道具を一律に適用対象にしない一方、条件付きの規律や文書を列挙から外さない。
   非適用には、適用条件を定める本文と、対象が条件を満たさない観測を対応付けた理由を残す。
   未読、未調査、証拠不足は非適用の理由にせず、`unresolved` と不足する根拠を残す。
4. 適用する規律は `<standard-root>/structure/tests/methods.md` の割当方針と台帳の検証欄に従い、対象 project の検証入口の実行とレビューで照合する。
   機械検査とレビューの両方が割り当てられた規律は、片方だけで完了としない。
   実行結果には command と結果の locator、レビュー結果には対象と判断の locator を残す。
   独立レビューと報告する場合は、独立した context の実際の記録を示す。
   標準本文や source を読んだ記録は `evidence` に残し、それだけで実行や独立レビューを済ませた `checks` にしない。
   意味を伴う判断は root README の適用判断に従い、規律の条件と対象の事実から結論を導いた根拠を、`reason`、`evidence`、review の locator の参照先へ残す。
   見出しの名指しや形式検査の成功だけで適合とせず、読取、適用判断、実検証を区別する。
5. 違反を root README と process/audit の引用規則に従って記録し、project の実基線台帳と照合する。
   実行できなかった検査は `not-run`、判断できなかった規律は `unresolved` のまま残す。
6. JSON 報告を作り、末尾の完了の判定を実際に確かめる。

## 出力仕様

監査報告は `violations`、`baseline`、`inspection` を持つ JSON とする。
次は形式の例であり、path、出典、検査結果は実際の観測値に置き換える。
`inspection.entries` は例の規律だけで終えず、列挙した全規律について一件ずつ記録する。

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
  "inspection": {
    "entries": [
      {
        "rule": "<標準ファイルの相対パス>#<該当見出し>",
        "disposition": "checked",
        "evidence": [
          "<source: 標準本文の path と見出し>",
          "<project: 対象 source の path と行>"
        ],
        "checks": [
          {
            "kind": "machine",
            "status": "failed",
            "evidence": "<tool: 実行 command と失敗結果の locator>"
          },
          {
            "kind": "review",
            "status": "passed",
            "evidence": "<tool: レビュー記録の locator>"
          }
        ]
      },
      {
        "rule": "<非適用と判断した規律の相対パス>#<該当見出し>",
        "disposition": "not-applicable",
        "evidence": [
          "<source: 適用条件を定める標準本文>",
          "<project: 対象が適用条件を満たさない根拠>"
        ],
        "reason": "<適用条件と対象の観測を対応付けた非適用理由>"
      },
      {
        "rule": "<判断が未確定の規律の相対パス>#<該当見出し>",
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

`rule` は規律の `<標準ファイルの相対パス>#<該当見出し>` とし、見出し単位の規律を持たない文書は相対パスだけを指す。
`evidence` は source、project、tool の出典を辿れる非空の locator とし、`entries[].evidence` は空でない配列にする。
`checked` は、割り当てられた検査の種類ごとに、`checks` へ `passed` か `failed` の実照合結果を少なくとも一件残す。
割当のない規律も、machine または review の実照合結果を少なくとも一件必要とする。
`checks` の各項目は `kind: machine | review`、`status: passed | failed | not-run`、非空の `evidence` を持つ。
一件の `review/passed` を、同じ規律に割り当てられた machine や他の規律の検査の代わりにしない。
`failed` の検査は、同じ `rule` を指す `violations[].rule` を伴う。
同じ文書に別の既存違反があっても、失敗した規律の違反報告の代わりにしない。
`not-run` の検査が一つでもある規律は `unresolved` とし、実行できた検査の結果は `checks` に残す。
`not-applicable` と `unresolved` は根拠となる `evidence` と非空の `reason` を持つ。
適用判断だけで `checked` にしない。

## 基線台帳

基線台帳は対象 project が所有する実ファイルであり、標準側や dotfiles 側へ移さない。
台帳の path を別の空ファイルへ切り替えて、既存違反との比較を回避しない。
内容は `{ "violations": [...] }` とし、各違反は報告と同じ `rule`、`file`、`line`、`evidence`、`mechanizable` の五つの field を持つ。
既存違反と認めるのは、実基線台帳の項目と五つすべてが一致した違反だけである。
実基線台帳を読み、報告の違反と台帳の項目を五つの field で比較して件数を数える。

- `newCount` は、台帳に一致しない報告の違反の数である。
- `baselineCount` は、台帳の項目と一致した報告の違反の数である。
- `resolvedCount` は、現在の報告に一致しない台帳の項目の数である。

`baseline.status` は、台帳があり新規違反がなければ `matched`、新規違反があれば `new-violations-found`、台帳がなければ `baseline-not-found` とする。
削除や移動された規律の旧項目も比較元とし、現在の報告に一致しない項目は `resolvedCount` に含める。
現在の報告の違反は現在の標準本文の規律を指し、旧項目を現在の規範の代わりにしたり、path を読み替えて一致した既存違反にしたりしない。
報告の `baseline.status` や `newCount: 0` で実ファイルとの比較を代替しない。
基線台帳がなければ `baseline-not-found` とし、観測した違反をすべて新規として扱う。
新規違反を追記して基線を肥大化させず、解消後の削除は project 側の変更として `<standard-root>/process/audit.md` に従う。

## 完了の判定

報告を返す前に、次を実際に確かめる。

- 列挙した全文書と全規律に `inspection.entries` の項目がある。
- `checked` の各項目が、割り当てられた検査の種類ごとに実照合の結果と `evidence` を持つ。
- `not-applicable` と `unresolved` の各項目が、`evidence` と非空の `reason` を持つ。
- `failed` の検査ごとに、同じ `rule` を指す `violations[]` の項目がある。
- `baseline` の件数が、実基線台帳との比較から数えた値である。
- 報告が JSON として読める。

結論は、観測した事実だけで次のいずれかに分ける。

| 結論 | 条件 |
|---|---|
| 未完了 | 規律の列挙を終えていない、適用判断だけで実照合が一件もない、または `unresolved` か `not-run` が残る |
| 新規違反あり | 全規律の照合を終え、基線台帳に一致しない違反がある |
| 既存違反のみ | 全規律の照合を終え、違反がすべて実基線台帳と一致する |
| 違反なし | 全規律の照合を終え、違反がない |

未完了は他の結論より優先し、観測した新規違反と既存違反は別に報告する。
未完了の報告は、未確認の規律と不足する根拠を示し、全域の適合も未確認の規律の適合も主張しない。
実行しなかった検査、読めなかった資料、利用できなかった検証入口は、通過したものとして扱わない。

この監査が示すのは、確認した規律ごとの観測と判断である。
引用の意味、適用判断の妥当性、証拠の真偽、列挙に現れない規範命題への実検査は保証しない。
project の analyzer や実行テスト、独立レビューの代わりではなく、すべての設計思想を機械検証したことにもならない。

## Non-goals

- 指摘の修正やコードの書き換えは行わず、修正は `standard-apply` と `<standard-root>/process/implementation.md`、`<standard-root>/process/refactoring.md` へ渡す。
- 標準側の本文や規律を編集せず、標準側の矛盾や不足は `standard-feedback` へ渡す。
