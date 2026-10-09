# audit-trail

## 概要
audit-trail は、後日の説明責任を立証する証跡を全系で統べる規律である。
principles の [data](../../principles/data/README.md) が定める業務事実の保持を、説明責任を要する操作の証跡として具象化する。
証跡の探索可能な構造は [observability](../observability/README.md)、追記だけの保管の形は [persistence](../persistence/README.md)、状態の変更と証跡の同時確定は [transaction](../transaction/README.md)、載せてよい個人情報と期限は [privacy](../privacy/README.md) が正本である。

## 規律

- [説明責任のある操作を証跡として追記する](./append-accountable-operations.md) — レビュー(決定記録と、証跡の保管の関係および確定経路の照合)

## 参照
業務事実の保持の形は [data](../../principles/data/README.md)、追記だけの保管は [persistence](../persistence/README.md)、状態の変更と証跡の同時確定は [transaction](../transaction/README.md) に従う。
探索可能な構造化は [observability](../observability/README.md)、個人情報の最小化と期限は [privacy](../privacy/README.md) に従う。
拒否の記録は [authorization](../authorization/README.md)、消去の証跡は [privacy](../privacy/README.md) が適用を書く。
