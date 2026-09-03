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
