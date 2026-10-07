# 意味と根拠の追跡

completion、state、success、failure などの受入語は、対象 source だけでは意味を確定できないことがある。公開 consumer、明示された要件と宣言の契約、state authority、既存 test と、必要な変更理由、Why not、直接リンクされた資料を照合してから設計する。

1. 対象 source を読み、公開 symbol と明示的な参照先を確認する。
2. target project の README、manifest、そこからの参照で source と test の置き場、要件と入力契約の入口を確認する。
   参照を読む順序は、参照元 file の絶対 path を確認し、その親 directory に参照先を結合し、`.` と `..` を解決してから読取 tool へ絶対 path を渡す。
   例えば `/repo/src/README.md` の `../contracts/` は `/repo/contracts/` であり、tool の current directory から `../contracts/` を探す操作ではない。
   directory への参照なら、解決済み directory の絶対 path を列挙の root に固定し、得た file を読む。
   読めなかった参照は、元の locator、解決済み path と読取結果を区別して記録し、未特定の場所だけ範囲を絞って探す。
   外部 ADR の置き場の宣言がないことだけでは、契約の authority を Unknown にしない。
3. LSP または native search で caller から公開 consumer まで追う。名前が変わる境界では、alias、route、返却値など観測した接点を次の検索に使う。
4. 現在の宣言の契約、判断に関係する変更理由と Why not、直接リンクされた要件や文書を読み、受入語の意味、authority、terminal state を確認する。未実装の要件と入力契約は現行実装の説明と区別する。過去の判断の記録を読む場合は、当時の採用と現在も拘束する条件を分け、特定の見出しや一行の書式との一致だけで採否を決めない。
5. 公開 consumer の返却値や authority state を観測する test を読む。内部関数名の検索が空でも、test 不在とは判断しない。宣言された test target、公開 route、観測する値を手掛かりに追い、test が実際に保証する条件と不足を分ける。

判断を左右する関係ごとに根拠を揃え、解消できない不足は確認範囲とともに Unknown とする。未確認の関数、error 型、writer、persistence の責務を発明しない。task の終了や handle の join は、persisted domain completion の証拠になるとは限らない。

標準本文と対象 project の調査を往復する必要がある場合は、SKILL.md の参照経路に従う。固定の検索回数で調査を打ち切らず、判断を変えない追加探索もしない。
