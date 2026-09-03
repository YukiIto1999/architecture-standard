## 仕込みを境界の殻で行う

### 要求
純粋核と効果の殻の分離は [separation](../../principles/separation/effects-at-boundaries.md) の「副作用を境界に集める」に従い、観測の仕込みは業務の核の外側、境界の殻で行う。
telemetry の出力は、単一の規格に統一し、規格と collector の採用と収集の分離は [tools/platforms/opentelemetry](../../tools/platforms/opentelemetry.md) が定める。
利用者の環境で動く surface も観測の対象であり、そこでの収集も境界の殻で行う。
利用者の環境から届く観測は、境界の外から来る値として検証してから使う。

### 根拠
観測の処理を業務の核に埋めると、判断のテストに観測の足場が要り、核が観測に結合する。
仕込みを効果の殻で行えば、核は純粋な判断に保てる。
利用者の環境で動く surface は、動く場所が利用者の端末であっても、業務の判断を持たず効果の殻に観測を閉じるという構造は他の surface と変わらない。
利用者の環境から届く観測は、信頼の境界の外から来る値であり、[security](../security/README.md) の既定で信頼しない規律に従って扱う。

### 完了条件
観測の仕込みが、業務の核の外側、境界の殻で行われている。
telemetry の出力が、単一の規格に統一されている。
業務の核に、ログや計測の処理が混ざらず、核は判断と事実を値として返している。
業務の核の単体テストに、ログや計測の足場が要らない。
利用者の環境で動く surface の観測が、境界の殻で行われている。
利用者の環境から届く観測が、境界の外から来る値として、検証を経ずに信頼されていない。

### 禁止事項
業務の核に、ログや計測の処理を埋め込むこと。

### 行動
観測の仕込みを境界の殻へ移し、核は決定を値として返すだけにする。
利用者の環境で動く surface では、境界の殻の実装として収集を行う。
収集に個人情報が載る場合は、[privacy](../privacy/README.md) に従う。

### 例

業務の核にログを入れると、判断のテストにも観測処理の足場が必要になる。

```
function decide(x) { logger.info("deciding"); return x.ok ? a : b; }
```

判断は純粋なまま核へ置き、ログの記録は殻で行う。

```
function decide(x) { return x.ok ? a : b; }
```

殻は観測を記録し、核が返した判断をそのまま返す。

```
function observeDecision(x) {
  log("decision.started")
  const result = decide(x)
  record("decision.completed", result)
  return result
}
```
