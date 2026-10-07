# json-schema-to-typescript

用途は、HTTP を持たない契約の JSON Schema から TypeScript の型を生成する道具である。
採用は、TypeScript は json-schema-to-typescript である。
判断基準は、`@typespec/json-schema` が出力する JSON Schema から contracts/generated の型を生成でき、生成器が TypeScript を要求せず製品の型検査 toolchain へ版の制約を広げず、生成した型が製品が採用する TypeScript の型検査を通り、同じ入力と同じ版から同じ出力を得られることである。
データ型は [structure/contracts/generated](../../structure/contracts/generated.md) の生成能力に従い、具体的な field、variant、制約を表し、通信 client と独立した公開入口から利用する。
公開契約の runtime 検証は [valibot](./valibot.md) が定める生成 schema を使い、その schema 駆動の生成処理を同じ contracts 生成 task に含める。
撤回条件は、判断基準を満たさなくなることであり、保守の停止、生成物が製品が採用する TypeScript の型検査を通らなくなること、生成器が特定の版の TypeScript を要求するようになることを再評価のトリガーとする。
