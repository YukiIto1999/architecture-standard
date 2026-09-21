# Duende.AccessTokenManagement

用途は、BFF が保持する token の交換と更新を担う機構である。
採用は、C# は Duende.AccessTokenManagement である。
判断基準は、token set と expiry を server 側に保持し、期限前の更新で得た token set を同じ session へ置き換えられることである。
撤回条件は、判断基準を満たさなくなることであり、ライセンス、リリースポリシー、session と token endpoint の互換性の変化を再評価のトリガーとする。
