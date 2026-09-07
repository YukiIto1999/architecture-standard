# 検査の役割と model eval の範囲

`verify-test.sh` と `skill-package-check.sh` を実行した後、model eval の要否と範囲を決めるときに読む。

`skill-package-check.sh` は実作業へ公開する product 検査であり、frontmatter、3 skill の eval 定義、script 構文を検査する。`run-task-evals.mjs` が `SKILL_EVAL_ISOLATED_SKILL` と `SKILL_EVAL_CONFIGURATION` の有効な組を渡した隔離評価だけは、選択中 skill の隠された `evals/` を欠落としない。configuration が `without-skill` なら、選択中 skill directory 全体の不存在だけを許可し、directory の一部が残る状態は失敗にする。通常実行や片方だけの指定では、skill または eval 一式がなければ失敗する。`skill-test.sh` は期待する解答と mutation を検査する外側の evaluator 回帰検査であり、評価対象 agent へ公開せず、実作業の完了条件にも使わない。

変更の種類に応じて model eval の範囲を決める。

- `scripts/*` または `references/*.md` だけを変更し、SKILL.md と eval を変えない場合は、回帰検査だけを行い、model eval は実行しない。
- SKILL.md の instruction を変更した場合は、skill-creator の評価手順を使う。変更した instruction の入力と観測可能な結果を prompt と expectation が直接使う task だけを `old-skill` と `with-skill` の2条件で隔離実行する。変更された file を監査対象に含むだけの task や、同じ skill を使うだけの task は選ばない。expectation、最終応答、tool event、diff、tracked / ignored status、実行 error、時間、token を比較する。新規 skill で旧版がない場合だけ `without-skill` を比較対象にする。
- `evals/evals.json` だけを変更した場合は、変更した task を `with-skill` で実行する。現行 instruction の不足が失敗として再現した後に instruction を変更し、その段階で `old-skill` と `with-skill` を比較する。
- description または `evals/trigger-evals.json` を変更した場合は、`scripts/run-trigger-evals.mjs` で `trigger-evals.json` の全 query を実行する。3 skill を同時に置いた条件で expected skill または非発火を測り、Skill tool の完全な入力、観測中の実行 error、発火先を記録する。
- release 前、または instruction と description の双方を横断して変更したときは、全 task の3条件比較と full trigger eval の両方を行う。それ以外は変更面ごとの上記範囲に限定する。instruction と `evals/trigger-evals.json` の変更を組み合わせた場合は、影響 task の2条件比較と full trigger eval をそれぞれ行い、全 task や `without-skill` へ広げない。

task eval は本 task の完遂を、trigger eval は発火先だけを測る。起動成功を PASS とせず、別 context の grader が expectation ごとの成否と event または成果物の根拠を `grading.json` に残す。複数条件を比較した場合は、対象 task の集計を `benchmark.json` に残す。隔離 evaluator が実行できなければ model eval 完了とは扱わず、阻害要因を報告する。
