# Git の運用規約

このファイルは、このリポジトリで残す Git 履歴の規則を定める。一般的な fork の手順や pull request の作り方は扱わない。

## 変更の選別

- staging の前に `git status --short` と `git diff` を読み、今回の目的に属する変更を特定する。
- staging には `git add -- <path>` または `git add -p` を使う。別の目的に属する変更が作業ツリーにある状態で、`git add -A` を使わない。
- 既存の変更は、今回の目的に属さない限り、取り消さず、書き換えず、commit に含めない。
- `docs/` に置いた調査、監査、設計の記録は `.gitignore` に従い、commit に含めない。
- secret、token、鍵、個人情報を commit に含めない。

## commit の粒度

- 一つの commit には、一つの目的と一つの取り消し理由だけを持たせる。ファイル数の少なさではなく、単独で取り消せる境界で分ける。
- 本文の変更、その変更を成立させる検査、必須の参照更新は同じ commit に入れる。いずれかを欠いた中間 commit は作らない。
- 振る舞いの変更と、それに不要な構造改善は別の commit に分ける。
- 各 commit は、その時点で参照切れや検査失敗を残さず、単独で checkout して検証できる状態にする。
- 標準本文の変更は、`.claude/skills/standard-update/scripts/verify.sh` の全 PASS を検証入口とし、検査を変えたら `verify-test.sh` に両方向の fixture を足す。
- `main` に `WIP`、`fixup!`、`squash!` の commit を残さない。公開前に amend または interactive rebase で整理する。
- 履歴の整理(amend・force push)は公開後も行いうる。整理後の照合可能性は、root README が定める条文引用の契約が担う。整理を行ったら、準拠する project へ再 pin を促す。

## commit message

件名は scope なし、50文字以内の一行にする。body と trailer は付けない。

```text
<type>: <日本語の要約>
```

使用できる type は次のとおり。

| type | 用途 |
|---|---|
| `feat` | 規律、採用、機構を追加する |
| `fix` | 誤り、矛盾、検査漏れを直す |
| `refactor` | 意味を変えずに責務や構造を直す |
| `docs` | 標準の意味を変えず、運用や解説の文書だけを変更する |
| `test` | 検査だけを変更する |
| `build` | build や依存関係を変更する |
| `ci` | CI を変更する |
| `chore` | 上記に含まれない保守を行う |
| `style` | 意味を変えずに形式を整える |
| `perf` | 性能を改善する |
| `revert` | 既存の commit を取り消す |

type は拡張子ではなく変更の目的で決める。Markdown だけを変更しても、規律、採用、構造、手順の意味を加えるなら `feat`、誤りを直すなら `fix` を使う。

件名は、その変更を何のために行うかを具体的に書く。変更したファイル、編集操作、変更後の状態だけを要約しない。詳しい文脈、代替案、帰結を要する構造上の判断は、commit message で代用せず決定の記録へ置く。語を並べるときは「と」か読点でつなぎ、中黒を使わない。scope、複数行の説明、AI 名義の `Co-authored-by` や生成ツール名による attribution は付けない。

```text
feat: build の採用判断を再現できるようにする
fix: verifier の異常終了を見逃さない
refactor: skill の変更を独立して取り消せるようにする
docs: Git の誤った履歴操作を防ぐ
```

## commit 前の確認

staged diff が一つの目的に閉じていることを確認する。

```bash
git status --short
git diff --staged --check
git diff --staged --stat
git diff --staged
```

変更内容の検証は、[standard-update](.claude/skills/standard-update/SKILL.md) の「検証して閉じる」に従う。標準本文または通常の運用ファイルを変更した場合は、少なくとも repository verifier を実行する。

```bash
bash .claude/skills/standard-update/scripts/verify.sh
```

skill の変更では、回帰検査、評価、scoped audit を含む同手順の追加要件も省略しない。検査が失敗した状態を commit しない。検査できなかった項目がある場合は、成功したものとして扱わない。

## 履歴の整理

- `main` は merge commit を含まない線形履歴にする。branch で作業した場合は、公開前に rebase して fast-forward できる形へ整える。
- 公開前の commit は、目的ごとの境界が明確になるまで amend、rebase、cherry-pick で組み直せる。公開済みの commit は原則として書き換えない。
- 公開済み履歴の書き換えは、対象範囲と影響を確定し、リポジトリ所有者の明示承認を得てから行う。
- 書き換えの前に remote の旧 OID を記録し、リポジトリ外へ bundle を作る。旧 OID と新 OID の対応表を残し、各候補 commit を単独で検証する。
- 標準の commit を参照する利用側 project がある場合は、書き換えで到達不能になる OID を対応表から更新する。参照更新の経路を決めずに履歴を書き換えない。
- 対象外の branch、tag、archive は変更しない。

## push

- push は、commit と検証が終わった後の別操作として行う。実行前に `git fetch origin` で remote の現在値を取得する。
- 通常の更新は fast-forward の `git push origin main` だけを使う。
- 公開済み履歴を書き換える場合は、確認済みの旧 remote OID を明示した `--force-with-lease=refs/heads/main:<old-remote-oid>` を使う。`--force` は使わない。
- push 後は、local の `main` と remote の `main` が同じ OID を指すことを確認する。
