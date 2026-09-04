# Vendoring

用途は、独立した機構リポジトリの exact commit を、target の `libs/<mechanism>` へ再現することである。
採用は、vendor 方式(機構リポジトリの指定 commit の tree を target の履歴へ複製し、出所の origin と commit ID を `libs/<mechanism>/UPSTREAM` に記録する)である。
判断基準は、clean clone 単体で build が成立し、CI と container の build context が追加の取得なしに完結することである。出所の commit が記録され、取り込みの更新が通常の diff としてレビューできることを含む。
撤回条件は、判断基準を満たさなくなることであり、取り込みの重複や出所記録の欠落が実測で常態化することを再評価のトリガーとする。
