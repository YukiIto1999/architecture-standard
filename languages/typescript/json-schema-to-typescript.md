# json-schema-to-typescript

用途は、HTTP を持たない契約の JSON Schema から TypeScript の型を生成する道具である。
採用は、TypeScript は json-schema-to-typescript である。
判断基準は、`@typespec/json-schema` が出力する JSON Schema から contracts/generated の型を生成でき、生成器が TypeScript を要求せず製品の型検査 toolchain へ版の制約を広げず、生成した型が製品が採用する TypeScript の型検査を通り、同じ入力と同じ版から同じ出力を得られることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、生成物が製品が採用する TypeScript の型検査を通らなくなること、生成器が特定の版の TypeScript を要求するようになることを再評価のトリガーとする。
