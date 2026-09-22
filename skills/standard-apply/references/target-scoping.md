# 意味と根拠の追跡

completion、state、success、failure などの受入語は、対象 source だけでは意味を確定できないことがある。公開 consumer、決定の記録、state authority、既存 test を照合してから設計する。

1. 対象 source を読み、公開 symbol と明示的な参照先を確認する。
2. target project の README、manifest、そこからの参照で source と test の置き場を確認する。決定の記録の正本の置き場は最上位 README の宣言で確認し、宣言がなければ置き場と契約の authority を Unknown に残す。manifest や直接リンクから読めた記録は候補として区別する。既知の path は直接読み、未特定の場所だけ範囲を絞って探す。
3. LSP または native search で caller から公開 consumer まで追う。名前が変わる境界では、alias、route、返却値など観測した接点を次の検索に使う。
4. decision record の採用状態と契約本文を読み、受入語の意味、authority、terminal state を確認する。採用状態は project の記載形式に従って判断し、特定の見出しや一行の書式との一致だけで捨てない。置き場の宣言がなければ、現在の標準本文の配置規則を確認する。
5. 公開 consumer の返却値や authority state を観測する test を読む。内部関数名の検索が空でも、test 不在とは判断しない。宣言された test target、公開 route、観測する値を手掛かりに追い、test が実際に保証する条件と不足を分ける。

判断を左右する関係ごとに根拠を揃え、解消できない不足は確認範囲とともに Unknown とする。未確認の関数、error 型、writer、persistence の責務を発明しない。task の終了や handle の join は、persisted domain completion の証拠になるとは限らない。

標準本文と対象 project の調査を往復する必要がある場合は、SKILL.md の参照経路に従う。固定の検索回数で調査を打ち切らず、判断を変えない追加探索もしない。
