# connection

## 概要
connection は、TypeScript で副作用と依存の渡し方を扱う実現軸である。
concerns の [effect](../../concerns/effect.md) が定める効果システムを、viewer・extension・host の軽い役割に合わせて満たす。
効果の表現と Result の規律は [neverthrow](./neverthrow.md) が持つ。
[separation](../../principles/separation.md) の依存の向きと [dependency](../../concerns/dependency.md) の「依存を内側へ一方向に向ける」の規律に従う。

## 依存を環境で受け、host の能力を port で宣言する

### 要求
効果が要求する依存は環境で受け取り、module の最上位に可変な singleton を作らない。
host に求める能力は ui port の型で宣言し、実装は host の composition が注入する。
本番とテストで、環境の実装を差し替える。

### 根拠
依存を環境で受ければ、計算が要求する能力が型に出て、組立点だけが具象を知る。
module の最上位の可変な singleton は、隠れた共有状態になり、差し替えとテストを阻む。
host の能力を ui port の型で宣言すれば、実装に縛られず host の composition が差し込める。
本番とテストで環境を差し替えると、host の能力をテストで制御できる。

### 完了条件
効果が要求する依存が、環境で受け取られている。
module の最上位に、可変な singleton がない。
host に求める能力が ui port の型で宣言され、host の composition が注入している。

### 禁止事項
module の最上位に、可変な singleton を作ること。
業務の核で、依存を直接生成すること。

### 行動
依存を環境で受け、host の能力を ui port の型で宣言し、host の composition が注入する。
本番とテストで、環境の実装を差し替える。

### 例
モジュール最上位の可変 singleton は、隠れた共有状態になる。

```typescript
export const userGateway = new UserGateway();
```

依存を環境で受け、host の能力を ui port で宣言する。

```typescript
interface HasUsers { users: UserGateway }
interface UiPort { notify(message: Message): void }
```

## 参照
効果システムは [effect](../../concerns/effect.md)、依存の向きは [dependency](../../concerns/dependency.md) に従う。
取り消しの AbortSignal は [coordination](./coordination.md)、状態は [solidjs](./solidjs.md) に従う。
