# migration

## 概要
migration は、新旧の稼働条件を踏まえて系を別の形へ移す過程を全系で統べる規律である。
principles の [evolution](../../principles/evolution/README.md) が定める段階的で可逆な段と収縮までの波及を、データと正本を移す作業として具象化する。
migration は停止切替と併存時の移行の段および切替の判定を扱い、静止した関係と制約は [persistence](../persistence/README.md)、書き込みパスの確定点は [transaction](../transaction/README.md) が扱う。

## 規律

- [新旧の併存に応じてスキーマを切り替える](./schema-change-cutover.md) — 機械+レビュー(停止切替の停止確認・復旧点・照合後の再開と併存時の新旧整合検査+移行照合)
- [別 datastore の移行を同じ時点で検証して切り替える](./datastore-cutover.md) — 機械+レビュー(新旧差分検証+移行照合)

## 参照
段階的で可逆な変更は [evolution](../../principles/evolution/README.md)、関係と制約の設計は [persistence](../persistence/README.md)、migration event の確定点は [transaction](../transaction/README.md) に従う。
移行の順序と確認点は [process/migration](../../process/migration.md) が定める。
