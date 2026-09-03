# PostgreSQL

用途は、永続化する事実の正本を関係と制約で保つ datastore である。
採用は、PostgreSQL である。
判断基準は、外部キー・一意・NOT NULL・検査の制約で関係の意図を表せることと、worker の queue の backend を同じ store で賄い、外部の broker を開かずに済むことである。
撤回条件は、判断基準を満たさなくなることであり、ライセンスとリリースポリシーの変化を再評価のトリガーとする。
