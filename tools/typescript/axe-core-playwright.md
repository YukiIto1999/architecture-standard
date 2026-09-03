# @axe-core/playwright

用途は、UI の E2E で、自動判定できる accessibility の違反を検出する道具である。
採用は、TypeScript は @axe-core/playwright である。
判断基準は、採用済みの Playwright の runner と page に対して、操作後の各状態で対比・ラベル・focus の機械判定できる違反を検査し、リポジトリの検証入口で止められることである。
検査する規律は、[concerns/accessibility](../../concerns/accessibility.md) に従う。
撤回条件は、判断基準を満たさなくなることであり、保守の停止と Playwright との互換性の喪失を再評価のトリガーとする。

## accessibility

### 要求
自動判定できる accessibility の違反は、E2E で機械検査する。これを @axe-core/playwright で満たす。
キーボードの到達性は、Playwright の操作と focus の assertion で E2E シナリオとして確かめる。
pointer target は、Playwright で表示後の bounding box を CSS px で測定し、Success Criterion 2.5.8 の例外記録と照合する。
text と non-text の contrast は、Playwright で表示結果の style、font face、user agent の font metadata、font metrics、隣接色を取得し、Success Criterion 1.4.3 と1.4.11の閾値と例外記録に照合する。
keyboard の到達性、色に頼らない表現、pointer target の下限、text と non-text の対比の規律は、[accessibility](../../concerns/accessibility.md) に従う。

### 根拠
[accessibility](../../concerns/accessibility.md) が要求する対比・ラベル・色だけに頼らない表現のうち、機械判定できる違反は axe の規則が検出する。
playwright-bdd は Playwright Test へ変換するので、生成されたテストの page に AxeBuilder を適用すれば、既存の runner のまま検査が加わる。
axe は focus trap やキーボードの全機能への到達を判定し切れないので、到達性は操作のシナリオで確かめる。
axe の規則だけでは、project が記録した Success Criterion 2.5.8 の例外、Roman と CJK の large text の根拠、Success Criterion 1.4.3 と1.4.11の対象別の例外を照合できない。
Playwright で表示結果と例外記録を同じ E2E に入力すれば、accessibility の観測可能な閾値と証拠要件をそのまま検査できる。

### 完了条件
操作後の各状態が、@axe-core/playwright で検査され、違反が検証入口で失敗になっている。
キーボードの到達性が、E2E シナリオで確かめられている。
各 pointer target の表示後の bounding box が CSS px で測定され、24×24 CSS px 以上であるか、Success Criterion 2.5.8 の例外と理由を持っている。
text と non-text の表示結果、font の分類根拠、隣接色、適用した例外が記録され、Success Criterion 1.4.3 と1.4.11の閾値に照合されている。

### 禁止事項
機械検査の通過だけで、accessibility を満たしたと称すること。
Success Criterion 2.5.8、1.4.3、1.4.11 の例外を、対象と理由の記録なしに検査から除くこと。
Roman または CJK の large text の分類根拠を記録せず、3:1の閾値を適用すること。

### 行動
E2E の各状態で AxeBuilder を適用し、違反を失敗として報告する。
Tab・Escape・focus の assertion で、キーボードの到達性のシナリオを書く。
Playwright で pointer target の表示後の bounding box を CSS px で測り、Success Criterion 2.5.8 の例外記録と照合する。
Playwright で表示結果の style、font face、user agent の font metadata、font metrics、隣接色を取得し、Success Criterion 1.4.3 と1.4.11の閾値および例外記録と照合する。
