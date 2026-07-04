# structure を更新するとき

structure は、ターゲットプロジェクトの各部の、言語非依存の構造を定める。
ちょうど一つの部の境界・中身を扱う関心はここに来る。複数の部にまたがる、または全層に効く関心は concerns に置く。

## 依存表の正本

skeleton の依存方向表が、root をまたぐ依存の唯一の駆動元である。
root は core・contracts・surfaces・runtimes・deploy・tests・companion の固定7境界であり、decisions と pipeline はコード境界でないため依存表の対象に含まれない。
surfaces は対話様式というアクターの軸で server・console・worker・viewer・extension・embedded の6 surface を直下に束ね、gui・hosts のような技術カテゴリの箱を作らない。
各部の layout は、この表が許す依存だけを内部の依存方向表として具体化する。skeleton の表と矛盾する依存を書かない。

## 拠り所(書く前に本体を読む)

structure を触るときは、skeleton.md 本体で境界表・依存方向表・入口の命名・自己ホストと被ホストの区別を確かめる。
各部の内部構成は、対応する layout.md(core・contracts・deploy・tests)または README.md(surfaces・runtimes)と、各面・各 host の layout.md で確かめる。
憶測で依存関係や命名を書かず、現行本文を根拠にする。

## 根拠の高度

structure は「各部をどう組むか」に答える。
根拠は、境界の内部構成・依存方向・命名がなぜその形かを、変更理由の分離(アクター・変更理由が異なれば境界を分ける)で述べる。
principles の根本のなぜを再導出しない。それは principles 側にあり、参照するだけに留める。
concerns が定めた横断規律(認証認可・永続化・型・observability など)を再定義しない。structure は該当 concerns への参照に留める。

## 書式

各部の地図は、core・contracts・deploy・tests では layout.md、surfaces・runtimes では一覧の README.md と各面・各 host の layout.md である。
layout の固有規律は、principles/concerns/languages の6節(要求・根拠・完了条件・禁止事項・行動)を使わない。
書式は、導入の参照文(横断規律と該当 concerns・principles への言及)、フォルダ構成の図(コードブロックに役割を一行添える)、単位表または依存方向表(参照元→参照可の対応)、単位ごとの固有規律を topical な見出しで並べる形にする。
新しい部・面・host を足すときも、この形式に合わせる。

## この層の MECE 点検

- skeleton の依存表と矛盾する依存を、各部の layout に書いていないか。
- concerns の規律(横断的な認証認可・永続化・型・observability など)を、structure の側で再定義していないか(再定義していれば concerns への参照に戻す)。
- principles の根本原則を、structure の側で再導出していないか。
- surfaces の直下に、技術カテゴリの箱(gui・hosts 等)を作っていないか。対話様式のアクターで境界を引いているか。
- 複数の部にまたがる関心を structure の一部だけに書いていないか(またがっていれば concerns へ)。
- 新しい面・host・部を足すとき、skeleton の固定7境界・surfaces の6 surface という既存の型に当たらないかを先に確かめたか。
- layout の書式(フォルダ構成・依存表・topical 見出し)から外れて、principles/concerns/languages の6節を持ち込んでいないか。
