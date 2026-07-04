# principles を更新するとき

principles は、言語にも特定の関心にも依存しない設計原則を置く。
ここに書くのは「なぜそう設計するか」の根本であり、テーブル設計や型の実装のような詳細は concerns、言語の機構は languages に置く。

## 拠り所(書く前に深く読む)

参考にする11名の思想に照らす。
ミノ駆動・増田亨・nwiizo・mizchi・そーだい(曽根壮大)・t-wada(和田卓人)・kawasima・Alexis King・Robert C Martin・Martin Fowler・farstep。
X の発言・スライド・講演・ブログ・著作を、Read で済ませず web-researcher で深く読む。
領域の目安は、モデリングと型と命名がミノ駆動と増田と King と kawasima、データと状態が そーだい と増田、検証とテストが t-wada、依存と境界が Martin と Fowler。
古典(Parnas の情報隠蔽、connascence、Date の真である命題、Kleppmann の data outlives code など)も裏取りに使う。

## 根拠の高度

根本のなぜを述べる。
原則は、その判断がなぜ変更容易性に効くかを説明する。
概念の具象化(どの機構で守るか)は書かない。それは concerns の仕事である。
言語の機構名(型・FW・ライブラリ)は本文に出さない。例は擬似コードか最小の図示に留め、TS を主にしつつ他言語の同等手段を一行添える。

## 構成(置き場)

3群のどれかに置く。
構成は separation・modeling・data・construction、規律は verification・evolution、表現は legibility・naming・comment・documentation。
新しい原則は、まず既存の原則の補強で足りないかを問い、足りるなら足す。独立した原則のときだけ新ファイルを立てる。

## 書式

`# name`、`## 概要`(相互参照をリードに埋める。principles は `## 参照` 節を使わない)、原則ごとの `## 名`、各 `### 要求/根拠/完了条件/禁止事項/行動`、必要なら `### 例`。
遵守は要求・完了条件・禁止事項で照合し、根拠は理解のための記述として判定に使わない。

## この層の MECE 点検

- 言語機構・製品名・方言を本文に漏らしていないか(漏れていれば languages へ)。
- モジュール設計の詳細(テーブル設計・制約の使い分け・型の実装)を書いていないか(書いていれば concerns へ)。
- 既存の原則や concerns と同じことを再定義していないか。
- 表現の群(legibility/naming/comment/documentation)は、媒体(コード/名前/コメント/文書)で重ならず分かれているか。
