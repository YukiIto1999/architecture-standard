# SonarQube

## 検査の基盤

用途は、認知的複雑さの検査と quality gate を提供する検査の基盤である。
採用は、SonarQube Community Build のセルフホストである。
判断基準は、無償の Community Build が cognitive complexity(S3776)と quality gate を提供することと、セルフホストが 1 顧客 1 配備と整合することである。
撤回条件は、無償の Community Build で判断基準の提供が続かなくなることであり、リリースポリシーの変化を再評価のトリガーとする。

## 認知的複雑さの検査

用途は、認知的複雑さを quality gate で検査する道具である。
採用は、セルフホストした SonarQube Community Build の cognitive complexity(S3776)と quality gate である。
判断基準は、switch や match の構造化を一度だけ加点し、閉じた直和の網羅的な分岐を罰しないことである。
撤回条件は、無償の Community Build で quality gate と S3776 が提供されなくなることであり、リリースポリシーの変化を再評価のトリガーとする。

## cognitive complexity を一箇所で測る

### 要求
認知的複雑さは、セルフホストした SonarQube の cognitive complexity(S3776)を quality gate で測る。
SonarQube の profile は cognitive complexity(S3776)に絞り、各言語のローカル lint と同目的の規則を重ねない。
しきい値を既定から緩める変更は、project の ADR に明記する。

### 根拠
cognitive complexity は switch や match の構造化を一度だけ加点し、分岐の数に比例しないので、閉じた直和の網羅的な分岐を罰しない。
同じ規則を quality gate とローカル lint の双方で有効にすると、同じ性質を二重に測ることになる。
profile を絞れば、ローカル linter が既に検査する規則を SonarQube 側で重ねて測ることがない。

### 完了条件
認知的複雑さが、SonarQube の quality gate だけで測られている。
SonarQube の profile が、cognitive complexity に絞られている。
緩和が、project の ADR に明記されている。

### 禁止事項
cognitive complexity を、ローカル lint と SonarQube の両方で有効にすること。
SonarQube の profile に、ローカル lint と同目的の規則を重ねて有効にすること。
閉じた直和の網羅的な分岐を、複雑度の加点対象にする指標を採ること。

### 行動
SonarQube の profile を cognitive complexity(S3776)に絞り、各言語のローカル lint から複雑度の規則を外す。

