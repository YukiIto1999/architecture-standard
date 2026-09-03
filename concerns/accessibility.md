# accessibility

## 概要
accessibility は、利用者面の可達性と識別性を全系で統べる規律である。
適用範囲は、利用者が判断し操作する面である。
GUI の viewer を主に、extension の UI や console の対話にも及ぶ。
pointer target、対比、色だけに頼らない表現の規律は、visual UI だけに適用する。
console には、keyboard 操作の規律を適用する。
principles の [legibility](../principles/legibility.md) が定める明瞭さを、入力機構と知覚の差を越えて届く利用者面へ具象化する。
設計の目的は、入力機構と知覚と手の精度の差によって、操作と識別が不可能になる面を作らないことである。

## キーボードで操作でき、色だけに頼らない

### 要求
visual UI と console のすべての操作を、keyboard で行えるようにする。
visual UI は、WCAG 2.2 Level AA を満たす。
visual UI のフォーカスを、通常の keyboard 操作で脱出できない場所に閉じ込めない。
modal dialog を開いている間は Tab 順序を dialog 内に保ち、Escape と明示された閉じる操作の双方で dialog を閉じられるようにし、起点か次の操作先へフォーカスを戻す。
visual UI の状態は、色とラベルの両方で示す。
visual UI の通常の text と images of text は、Success Criterion 1.4.3 に従い、背景との contrast ratio を4.5:1以上にする。
visual UI の large text と large images of text は、Success Criterion 1.4.3 に従い、背景との contrast ratio を3:1以上にする。
Roman の large text は、18pt(24 CSS px)以上、または14pt(約18.67 CSS px)以上かつ bold の text に限る。
Roman の bold は、使用した font face と user agent の font metadata から判定する。
CJK の large text は、font metrics から WCAG 2.2 が定める large print と同等の大きさであることを checker が実証できる text に限る。
CJK の large print 相当を実証できない text には、通常の text と同じ4.5:1以上を適用する。
Success Criterion 1.4.3 の対比要件から除外するのは、inactive な UI component の text または image of text、純粋な装飾、表示されない text または image of text、重要な他の視覚内容を含む画像の一部である text または image of text、logotype または brand name に限る。
visual UI の component と state の識別に必要な visual information と、内容の理解に必要な graphic は、Success Criterion 1.4.11 に従い、隣接色との contrast ratio を3:1以上にする。
component と state の visual information から除外するのは、inactive な UI component と、user agent が外観を決めて author が変更していない UI component に限る。
内容の理解に必要な graphical object から除外するのは、その particular presentation が情報に不可欠な場合に限る。

### 根拠
visual UI では、mouse を使えない利用者も keyboard で全操作に届く必要がある。
脱出手段のない keyboard trap は、keyboard の利用者が先へ進むことを妨げる。
modal dialog は背後を操作不能にするため、開いている間はフォーカスを内側に保ち、閉じる操作と閉鎖後の復帰先を備える。
visual UI で色だけを使って状態を示すと、色を見分けにくい利用者に伝わらない。
visual UI で対比が足りないと、文字が読めない。
contrast ratio と success criterion を固定すれば、対比を印象でなく computed style から判定できる。

### 完了条件
visual UI で mouse から届く操作が、すべて keyboard でも届く。
console のすべての操作が、keyboard から届く。
visual UI に、通常の keyboard 操作で脱出できない focus trap がない。
modal dialog の Tab 順序が dialog 内に保たれ、Escape と明示された閉じる操作で閉じられ、閉鎖後のフォーカスが起点か次の操作先へ戻っている。
visual UI の状態が、色とラベルの両方で示されている。
visual UI が、WCAG 2.2 Level AA を満たしている。
通常の text と images of text の contrast ratio が4.5:1以上である。
large text と large images of text の contrast ratio が3:1以上である。
Roman の large text が、18pt(24 CSS px)以上、または14pt(約18.67 CSS px)以上かつ font face と user agent の metadata で bold と判定されている。
CJK の large text が、font metrics により WCAG 2.2 の large print と同等であることを実証されている。
CJK の large print 相当を実証できない text に、4.5:1以上が適用されている。
component と state の識別に必要な visual information と、内容の理解に必要な graphic の contrast ratio が3:1以上である。
Success Criterion 1.4.3 と1.4.11の除外が、各 criterion の例外種別と対象を記録した場合だけ適用されている。
Success Criterion 1.4.11 の UI component の例外と graphical object の例外が、それぞれの対象だけに適用されている。
表示結果の style、font face、user agent の font metadata、font metrics、隣接色、例外記録が、各 contrast ratio を照合できる証拠として残っている。

### 禁止事項
visual UI に、mouse でしか行えない操作を置くこと。
visual UI の状態を、色だけで示すこと。
visual UI のフォーカスを、通常の keyboard 操作で脱出できない場所に閉じ込めること。
modal dialog から Escape と明示された閉じる操作を外すこと。
modal dialog を閉じた後のフォーカスの復帰先を定めないこと。
通常の text または image of text を、contrast ratio が4.5:1未満の状態で表示すること。
基準未満の text を、Success Criterion 1.4.3 の例外に該当しないまま対比検査から除外すること。
Roman の large text の大きさと font face の bold metadata を確認せず、3:1の閾値を適用すること。
CJK の large print 相当を font metrics で実証せず、3:1の閾値を適用すること。
component と state の識別に必要な visual information または内容の理解に必要な graphic を、Success Criterion 1.4.11 の例外に該当しないまま3:1未満で表示すること。
inactive または user agent appearance の例外を、graphical object へ適用すること。
essential presentation の例外を、UI component または state へ適用すること。

### 行動
visual UI と console を keyboard だけで辿り、届かない操作を見つける。
visual UI では、脱出手段のない focus trap を見つける。
modal dialog では、Tab と Shift+Tab が dialog 内を循環し、Escape と閉じる操作で閉鎖でき、フォーカスが起点か次の操作先へ戻ることを確かめる。
すべての操作に keyboard の経路を与える。
visual UI では、フォーカスの順路を保ち、状態を色とラベルの両方で示し、対比を確保する。
表示後の Roman text の style、font face、user agent の font metadata を取得し、18pt以上、または14pt以上かつ bold のどちらかへ分類する。
CJK text は font metrics から WCAG 2.2 の large print と同等であることを checker で実証し、実証できない場合は通常の text として扱う。
表示後の text、component と state の識別に必要な visual information、内容の理解に必要な graphic の隣接色を取得し、Success Criterion 1.4.3と1.4.11のcontrast ratioを検査する。
対比検査から除外する対象は、該当する criterion の例外種別と理由を記録して照合する。
Success Criterion 1.4.11 は、UI component と state の例外を UI component だけに、essential presentation の例外を graphical object だけに照合する。

### 例

```
対象: 通常の text
隣接色との contrast ratio: 4.7:1
適用する閾値: 4.5:1
例外: 無し
判定: 適合

対象: 保存操作の識別に必要な境界線
隣接色との contrast ratio: 3.2:1
適用する閾値: 3:1
例外: 無し
判定: 適合
```

## pointer target を掴める大きさに保つ

### 要求
visual UI の pointer target は、WCAG 2.2 の Success Criterion 2.5.8 に従い、24×24 CSS px 以上にする。
24×24 CSS px 未満の target は、Success Criterion 2.5.8 が定める例外に該当する場合だけ許し、該当する例外と理由を記録する。

### 根拠
掴める大きさの下限を置かないと、手の精度の差だけで操作が不可能になる。
下限を満たす pointer target は、精度の低い操作でも対象を外さずに押せる。
24×24 CSS px という閾値を固定すれば、押しやすさを印象でなく bounding box で判定できる。

### 完了条件
visual UI の pointer target が24×24 CSS px以上であるか、Success Criterion 2.5.8 の例外と理由を持っている。
各 pointer target の表示後の CSS px の bounding box と例外記録が、照合できる証拠として残っている。

### 禁止事項
Success Criterion 2.5.8 の例外記録がない pointer target を、24×24 CSS px 未満にすること。

### 行動
各 pointer target の表示後の bounding box を CSS px で測り、幅と高さを24 CSS px以上にする。
24×24 CSS px 未満の target は、Success Criterion 2.5.8 の例外と理由が記録されている場合だけ検査から除外する。

### 例

```
対象: 保存の主操作
表示後の bounding box: 幅32 CSS px、高さ24 CSS px
Success Criterion 2.5.8 の例外: 無し
判定: 24×24 CSS px 以上
```

## 参照
明瞭さは [legibility](../principles/legibility.md)、利用者に向けた画面の体験は [experience](./experience.md) に従う。
viewer の構造は [structure/surfaces/viewer](../structure/surfaces/viewer/layout.md)、検証の技法と検証手段の割り当ては [structure/tests/methods](../structure/tests/methods.md)、見た目と機構は [languages](../languages/) が定める。
