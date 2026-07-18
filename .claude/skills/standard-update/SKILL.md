---
name: standard-update
description: architecture-standard(principles/concerns/languages/structure/tools/process)へ外部の素材を取り込んで更新する。技術記事・スライド・X の発言・知見・著名エンジニアの主張を渡されたら、どの層のどのファイルに当たるかを判定し、既存に足すか・新しい単位を作るか・矛盾を解消するかを決めて、標準の書式で更新する。原則・概念・言語規則・構造・採用(tools)・手順(process)の追加や改訂にも使う。project から標準への改訂提案(docs/revision)の回収にも使う。記事や知見を共有して「標準に反映して」「取り込んで」と言われたとき、また原則・概念・言語・構造・採用・手順の規則を足す/直すときは、skill 名を明示されなくても必ずこれを使う。
---

# standard-update

外部の素材を、この標準の規律どおりに取り込んで更新する。
変更を書いた者は自分の見落としを見られないので、配置と裏取りと検証を習慣でなく明示の手順にする。

## この標準の形(更新の対象)

- `principles/` — 言語に依存しない設計原則(なぜ)。構成・規律・表現の3群。
- `concerns/` — 言語非依存の概念ごとの規律(17概念)。effect・concurrency・dependency・types・persistence・transaction・messaging・authentication・authorization・observability・privacy・security・configuration・resilience・performance・lifecycle・experience。
- `languages/` — 言語ごとの実現。rust・csharp・typescript × 7 locus(formation・translation・connection・retention・coordination・publication・inspection)+ 1 全域規律(conventions。命名・整形・ドキュメントコメント・型名接尾辞)。
- `structure/` — ターゲットプロジェクトの root の境界・依存方向・各部の内部構成を、言語非依存に定める。skeleton が root 構成の正本、各部の layout が内部の正本。
- `tools/` — 何を使うか・どう選ぶかの採用の正本。language・stack・inspection・services・platforms の5分割。principles・concerns・structure・languages の上位規律に従属し、性質の要求は再定義しない。
- `process/` — どの順で作り、どこで確かめるか。作業の種別ごとの順序と確認点。7単位(bootstrap・design・implementation・refactoring・review・audit・migration)。順序と確認点だけを所有し、性質の規範を再定義しない。
- `docs/` — 作業の材料であり、標準には含めない。

6領域は MECE である。設計原則は principles のみ、モジュール設計の詳細(認証認可・DB/テーブル・型など)は concerns のみ(言語非依存)、ちょうど一つの部の境界・中身は structure のみ、言語の扱いは languages のみ、採用と判断基準は tools のみ、作業の順序と確認点は process のみ。

## project からの改訂提案の回収

project は、標準への改訂提案を project の docs/revision に置く(root [README](../../../README.md) の標準の参照節に定める)。
project の docs/revision を回収し、提案ごとに採否を裁定し、採る提案を取り込みの入力に渡す。

## 手順(どの更新も踏む)

### 1. 取り込み
入力(記事・スライド・X・知見)から、主張・パターン・決定を抜き出す。
持続する原則と、それを支える例とを分ける。例だけを規則にしない。共通構造を一段上げて一般化する。
入力は要約でなく一次の本文を求める。本文が無ければ、成果物は配置と判断までとし、追記の確定は本文を得てから行う。

### 2. 配置(MECE)
どの層のどのファイルが所有するかを、root README の配置規則で判定する。
判定の順は、値・なぜ → principles、採用と判断基準 → tools、作業の順序と確認点 → process、特定言語の実現 → languages、ちょうど一つの部の境界・中身 → structure、複数の部にまたがるか全層に効く → concerns。
そのうえで、対象の規律の6節を全て読んでから、次のどれかを決める。主張が既に在ることは多いので、書く前に確かめる。

- **足す**: 主張が既存の規律を精密にする・強める → その規律の6節を編集する。足す前に、その主張が既に在らないか、在るなら根拠が完了条件と行動を支え例が規律に反していないかを点検する。
- **新設**: 主張が所有者のいない別の事象 → 新しい規律を立てる。概念そのものが欠けていれば新しいファイルを作り、README と概念数を更新する。
- **矛盾の解消**: 主張が標準と食い違う → 黙って覆さない。標準は単一に保ち、逸脱は標準外を採る利用側 project の ADR(この repo の docs/decisions/ でなく)に置く。参照者の一致は採用根拠ではない。最終裁定は spine(整合性アンカー)との協調で下す。事実の誤りの訂正なら直して根拠を残す。
- **無変更**: 主張が既に全て所有され協調している → 編集しない。成果物は、どこが所有しているかを示す照合表にする。

重複と抜けを必ず確認する。
フォルダ間: principles の根本を concerns で再導出しない。言語機構を concerns/principles に漏らさない。
ファイル間: 一つが所有し、他は参照に絞る(同じことを二箇所で根拠ごと書かない)。
網羅: 当たる所がなければ抜けなので、新設で埋める。
一つの主張が複数の所有者にまたがるときは、側面ごとに所有者を割り当て、重複でなく分担として扱う(例: 境界の parse は、境界をどこに引くかが separation、型への変換が modeling と types)。

### 3. 調べる
書く前に、層の拠り所で裏取りする。
記事だけから書かない。一次資料と標準の参考者に照らし、最低2源で確かめる。snippet で断定しない。
調査は web-researcher を使い、`docs/research/` に台帳として残す。
層ごとの拠り所と根拠の高度は、対象の層の reference を読む。

- principles を触る → `references/principles.md`
- concerns を触る → `references/concerns.md`
- languages を触る → `references/languages.md`
- structure を触る → `references/structure.md`
- tools を触る → `references/tools.md`
- process を触る → `references/process.md`

### 4. 書く
6節で書く。要求・根拠・完了条件・禁止事項・行動・例。
根拠の高度を層で変える。principles=根本のなぜ、concerns=概念の高度での具象化、languages=その言語の機構で base をどう満たすか、tools=選定の決め手。
文体は反 AI スロップにする。句点で改行して一文一義、記号(❌✅・emoji)を使わない、本文に人名を出さない、自分の言葉で書く。
詳細は層の reference に従う。

### 5. 配線
相互参照を張る。向きは concerns が正本、structure が参照する側であり、逆転させない。
概念の増減時は、root の README.md・concerns/README.md・本 skill・verify.sh を連動して更新する。関連する languages の参照も合わせて更新する。

### 6. 検証
変更したときは、この skill の `scripts/verify.sh` を走らせ、リンク切れ・6節の均衡・概念層への言語漏れ・概念数の整合・principles と concerns の逐語一致・concerns と structure の製品名指しが tools に登録済みかを確かめる。
配置の MECE(漏れ・重複・抜け)を見直す。
変更したファイルには `standard-audit` をかける。自分が書いた文は自分では評価できないので、別の目(白紙の subagent)で見る。
無変更のときは、照合表が所有を網羅しているかだけ確かめる。

## 横断の不変条件

- 作り切る。要求した範囲は最小実装で止めず作り切り、残作業を残さない。未要求の投機は足さない。
- 標準に例外を作らない。条件付きの分岐や例外は標準の側に作らず、逸脱は project の ADR に置く。
- 整合性を一級に扱う。決定どうしが協調し、A で賄える所に B を入れない。
- docs なしで自己充足にする。変更は、標準だけを読んで従える形にする。

## 自己充足の例(取り込みの典型)

```
入力: 「parse, don't validate」の記事
→ 配置: 型の境界 parse は principles/modeling(原則)と concerns/types(概念)が所有済み。
→ 判断: 新設でなく、既存への補強か整合確認。languages の各 translation が満たすか見る。

入力: retry の backoff に jitter を足す知見
→ 配置: concerns/resilience の過負荷を抑える規律が所有。
→ 判断: 足す。完了条件と行動に jitter を加える。

入力: 「設定は環境変数に置け」という、標準と食い違う主張
→ 配置: concerns/configuration。
→ 判断: 矛盾の解消。標準は「環境変数を源にしない」立場を保ち、採るなら project の ADR に逸脱として明記。
```

## 関連

- `references/{principles,concerns,languages,structure,tools,process}.md` — 層ごとの拠り所・根拠の高度・配置の型。該当層だけ読む。
- `scripts/verify.sh` — リンク・6節均衡・言語漏れ・概念数・逐語一致・製品名指しの tools 登録の機械検査。
- `standard-audit` — MECE と忠実度の総監査。更新の末尾検証にも、単体の見直しにも使う。
- 高重要度の更新は、白紙の subagent に先入観を与えない brief で走らせ、書いた者の評価と合わせて二面で固める。
