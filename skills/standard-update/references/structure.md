# structure を更新するとき

structure は、ターゲットプロジェクト全体と各部の責務、境界、依存方向、配置、および各部固有の設計規律を言語非依存に定める。
配置は [root README](../../../README.md) の配置規則に従い、構成を決める判断と特定概念の性質や保証を決める判断を分け、モジュール数で所有先を決めない。
検証技法の選択と規範から検証への割当は `structure/tests/methods.md` が所有し、structure を folder 配置だけに狭めない。

## 依存表の正本

skeleton の依存方向表が、root をまたぐ依存の唯一の駆動元である。
root は core・libs・contracts・surfaces・runtimes・deploy・tests の固定7境界である。core・contracts・tests は常に置き、libs は対応する機構があるときに置く。decisions と pipeline は、root の境界に無い。
surfaces は対話様式というアクターの軸で server・console・worker・viewer・extension・embedded の6 surface を直下に束ね、gui・hosts のような技術カテゴリの箱を作らない。
各部の layout は、この表が許す依存だけを内部の依存方向表として具体化する。skeleton の表と矛盾する依存を書かない。

## 根拠の高度

structure は「全体と各部をどう設計するか」に答える。
根拠は、構成や固有の設計判断が対象の変更理由と性質にどう対応するかを述べる。
principles が所有する判断基準と一般規律は再導出せず、参照する。
concerns が所有する特定概念の性質と保証は再定義せず、該当する正本を参照する。

## 書式

各部の地図は、core・libs・contracts・deploy・tests では layout.md、surfaces・runtimes では一覧の README.md と各面・各 host の layout.md である。
layout の固有規律は、principles/concerns/languages の必須5節(要求・根拠・完了条件・禁止事項・行動)を使わない。
書式は、導入の参照文(従う規律と該当 concerns・principles への言及)、フォルダ構成の図(コードブロックに役割を一行添える)、単位表または依存方向表(参照元→参照可の対応)、単位ごとの固有規律を topical な見出しで並べる形にする。
新しい部・面・host を足すときも、この形式に合わせる。

## この層の MECE 点検

- skeleton の依存表と矛盾する依存を、各部の layout に書いていないか。
- concerns が所有する概念の性質と保証(認証認可・永続化・型・observability など)を、structure の側で再定義していないか(再定義していれば正本への参照に戻す)。
- principles の判断基準と一般規律を、structure の側で再導出していないか。
- 市場から選ばず一意に定まる規格・プロトコル名を除き、採用(製品名・機構の選定)を structure に書いていないかを確認し、言語横断の採用は tools、言語 ecosystem 固有の採用は languages への参照に戻す。
- surfaces の直下に、技術カテゴリの箱(gui・hosts 等)を作っていないか。対話様式のアクターで境界を引いているか。
- root をまたぐ具体的な許可依存を skeleton、概念の一般的な性質と保証を concerns が所有しているか(複数の部に効くことだけを理由に構成の正本を concerns へ移さない)。
- 検証技法と規範から検証への割当の正本を、構成以外の判断だからという理由で `structure/tests/methods.md` から除いていないか。
- 新しい面・host・部を足すとき、skeleton の固定7境界・surfaces の6 surface という既存の型に当たらないかを先に確かめたか。
- layout の書式(フォルダ構成・依存表・topical 見出し)から外れて、principles/concerns/languages の必須5節を持ち込んでいないか。
