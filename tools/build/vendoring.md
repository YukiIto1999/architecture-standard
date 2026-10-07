# Vendoring

用途は、独立した repository から機構のソースを共有する場合に、exact commit の tree を target の `libs/<mechanism>` へ再現することである。
採用は、vendor 方式(機構の指定 commit の tree を target の履歴へ複製し、出所の origin と commit ID を `libs/<mechanism>/UPSTREAM` に記録する)である。
判断基準は、取り込んだコードと `spec.md` が指定 commit の内容に一致し、clean clone 単体で追加の取得なしに build が成立して、CI と container の build context が完結することである。
出所の commit が記録され、取り込みの更新が通常の diff としてレビューできることを含む。
撤回条件は、判断基準を満たさなくなることであり、取り込みの重複や出所記録の欠落が実測で常態化することを再評価のトリガーとする。
