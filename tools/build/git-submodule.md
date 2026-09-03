# Git submodule

用途は、独立した機構リポジトリの exact commit を、target の `libs/<mechanism>` へ再現することである。
採用は、Git submodule である。
判断基準は、target の tree が gitlink で機構の commit object ID を固定し、`.gitmodules` が origin と path を記録し、clean clone から同じ commit のコードと `spec.md` を同じ path へ checkout できることである。
撤回条件は、gitlink、origin、path のいずれかを target の履歴で再現できなくなることであり、Git の submodule 仕様と利用する repository host の取得条件の変化を再評価のトリガーとする。
