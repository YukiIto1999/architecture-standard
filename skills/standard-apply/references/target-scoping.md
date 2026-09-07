# 閉じた対象調査経路

exact source path を与えられ、受入条件に completion、state、success または failure がある設計で、最初の対象 project 操作の前に読む。

exact source path を与えられ、受入条件に completion、state、success または failure がある設計は、次の対象 project 操作だけを記載順に行う。

1. exact source file を読む。
2. target project root の `README.md` を exact path で読み、source root と test root の記載を確認する。存在しない場合は別名の manifest を探さず、source root は exact source の親 directory、test root は Unknown とする。
3. 対象 source の公開 symbol を source root で exact token の一回の Grep にかけ、一段上の公開 caller を読む。内部で呼ぶ未定義 symbol は、一つを選んだ exact token の Grep 一回だけで定義を探す。同じ token を別の root で再検索しない。
4. 対象 source の公開 symbol と同じ exact token を `docs/decisions/` で一回 Grep し、一致した Accepted ADR を読む。`Job`、`State`、`Status`、`completion` のような一般候補を順に試さない。ADR が authority 型を名指しする場合だけ、その exact 型名を source root で一回 Grep し、一致した authority source を読む。
5. 手順2で test root を確認できた場合だけ、公開 caller の exact symbol をその root で一回 Grep し、一致 test を読む。確認できなければ test 契約を Unknown にする。

この経路で対象 project に使える探索は、各手順に明記した単一 token の限定 Grep だけである。`|` を含む OR pattern、project root 全域の Grep、Glob、別名 manifest の試行を使わない。外部 cancellation、deadline、writer、依存、設定の明示的な起点が読んだ経路になければ、不在と検索せず Unknown にする。手順外の探索で得た結果は設計根拠にせず、経路を完了と報告しない。
対象 project の手順を閉じた後に、`<standard-root>` を起点として標準本文へ移る。標準本文の読む順序と量は SKILL.md の参照経路に従う。
