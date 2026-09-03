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
