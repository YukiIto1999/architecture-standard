# migration

## 概要
migration は、稼働中の系を別の形へ移す過程を全系で統べる規律である。
principles の [evolution](../../principles/evolution/README.md) が定める段階的で可逆な段と収縮までの波及を、稼働中のデータと正本を移す作業として具象化する。
migration は移行の段と切替の判定を扱い、静止した関係と制約は [persistence](../persistence/README.md)、書き込みパスの確定点は [transaction](../transaction/README.md) が扱う。

## 規律

- [稼働中のスキーマを拡張・移行・収縮の段で進化させる](./expand-migrate-contract.md) — 機械+レビュー(新旧整合検査+移行照合)
- [別 datastore の移行を同じ時点で検証して切り替える](./datastore-cutover.md) — 機械+レビュー(新旧差分検証+移行照合)

## 参照
段階的で可逆な変更は [evolution](../../principles/evolution/README.md)、関係と制約の設計は [persistence](../persistence/README.md)、migration event の確定点は [transaction](../transaction/README.md) に従う。
移行の順序と確認点は [process/migration](../../process/migration.md) が定める。
