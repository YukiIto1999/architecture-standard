# Playwright

用途は、UI をブラウザ越しに操作し見た目と疎通を確かめる実行系である。
採用は、TypeScript は Playwright である。
判断基準は、browser の操作と screenshot 比較を test runner として実行でき、操作の入力から表示までの時刻を測定でき、baseline 画像と実行環境の記録を版管理してレビューできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

UI の受入と smoke の判定は、[structure/tests/methods-surfaces](../../structure/tests/methods-surfaces.md) の「利用者面の受入」に従う。
Playwright Test の test を追加しなくても、Playwright で実画面を操作し、変更時の受入の証拠を得られる。
Playwright の test では、操作対象を利用者向けの role、label、text の locator で一意にし、固定の待機でなく、期待する文言、値、件数、状態への web-first assertion で結果を待って判定する。
Playwright で受入画像を取得する場合は、期待した結果を確認した同じ page の screenshot を使い、対応する検査条件と表示条件を証拠に添える。
継続的な visual の差分の検査は、この file の「baseline 画像と環境指紋を一つの更新単位で版管理する」に従う。

## 継続するブラウザ検査を直接実行する

### 要求
継続して実行するブラウザの E2E と visual は、Playwright Test に操作と assertion を直接定義し、repository の検証入口から実行する。

### 根拠
ブラウザの操作手順は UI の構成に依存するが、同じ業務結果を保証する限り、操作手順が変わっても業務の事例は変わらない。
継続検査は、選んだ経路を同じ入口で再実行できればよく、Gherkin から変換する層を必要としない。

### 完了条件
継続して守る E2E と visual の経路が、Playwright Test の検証入口から列挙でき、対応する期待結果に対して実行されている。

### 禁止事項
ブラウザの E2E と visual を、[structure/tests/layout](../../structure/tests/layout.md) の「実行可能な仕様」で定める業務仕様の代わりにすること。
変更時の一回の実行を、継続して実行する必要がある検査の代わりにすること。

### 行動
継続して守る経路は、Playwright Test に操作と assertion を直接書く。

## 表示までの時間を browser で測る

### 要求
[experience](../../concerns/experience/README.md) が定める状態または feedback の100ms、1秒を超える operation の progress 開始までの1秒と完了までの継続は、Playwright が browser を駆動する test で、利用者面の操作ごとに表示時刻を測定する。
この test は [structure/tests/layout](../../structure/tests/layout.md) の integration に置き、e2e の smoke に操作ごとの計測を加えない。

### 根拠
操作の入力と表示結果を同じ browser で測れば、handler の起動や server の完了でなく、利用者が状態、feedback、progress を見られるまでの時間を判定できる。
操作ごとの表示時刻の計測と、公開入口から業務結果までの実際の結合の検証は、観測と失敗条件が異なるため、それぞれを integration と e2e の役割に割り当てる。

### 完了条件
利用者面の各操作の入力時刻、状態または feedback の表示時刻、1秒を超える operation の progress 表示時刻と完了時刻が、integration に置いた Playwright の test で測定され、experience の閾値と継続条件を満たしている。

### 禁止事項
handler の起動時刻または server の完了時刻を、状態、feedback、progress が利用者へ表示された時刻として扱うこと。
操作ごとの表示時刻の計測を、e2e の smoke に加えること。

### 行動
Playwright が browser を駆動する integration の test で操作を入力し、入力時刻、状態または feedback の表示時刻、progress の表示時刻、完了時刻を記録して、experience の閾値と継続条件を検査する。

## baseline 画像と環境指紋を一つの更新単位で版管理する

### 要求
baseline 画像は、画像ごとか同じ実行環境を使う画像集合ごとに、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport の metadata と組にして版管理する。
metadata の各値は、形式を固定した canonical serialization から environment fingerprint を生成できる形で記録する。
検証時の現在値から生成した fingerprint と一致しなければ、screenshot の比較前に失敗させる。
fingerprint が一致した場合だけ、`toHaveScreenshot` で baseline 画像を比較する。
baseline を更新するときは、画像と metadata を生成する単一の更新処理を使い、片方の生成に失敗したら両方を確定しない。
画像と metadata は、一つの更新単位として明示的にレビューする。

### 根拠
実行環境が変わると描画が変わるので、fingerprint なしでは baseline との差分が環境差か退行かを判別できない。
canonical serialization から fingerprint を生成すれば、metadata の表記揺れを環境差と誤認しない。
比較の前に fingerprint で失敗させれば、環境差による偽の差分がレビューを汚さない。
`toHaveScreenshot` の差分を検証入口で検出すれば、未レビューの見た目の変更が baseline へ混入しない。
画像と metadata を一組で更新すれば、片方だけの更新による不整合が入らない。

### 完了条件
baseline 画像が、metadata と組で版管理されている。
各 baseline 画像か同じ実行環境を使う画像集合の metadata に、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport が記録されている。
metadata と実行環境の現在値が、同じ canonical serialization から environment fingerprint を生成している。
fingerprint の不一致が、screenshot 比較前の失敗になっている。
二つの fingerprint が一致した場合だけ、`toHaveScreenshot` が baseline 画像を比較している。
baseline 画像か metadata の生成に失敗した場合は、どちらも更新されていない。
画像と metadata の更新が、一つの更新単位としてレビューされている。

### 禁止事項
metadata を持たない baseline 画像を、版管理すること。
実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport のいずれかを metadata から省くこと。
fingerprint が不一致のまま、screenshot を比較すること。
baseline 画像か metadata のどちらか一方だけを更新すること。
baseline 画像と metadata の更新を、レビューなしに確定すること。

### 行動
baseline 画像ごとか同じ実行環境を使う画像集合ごとに metadata を置き、画像とともに版管理する。
metadata と実行環境の現在値を同じ形式で canonical serialization し、それぞれの environment fingerprint を生成する。
二つの fingerprint を screenshot の比較前に照合し、一致しなければ失敗させる。
baseline の更新では画像と metadata の両方を生成し、差分を同じ変更として明示的にレビューする。

### 例

baseline 集合の metadata は、次のように環境の値だけを持つ。

```json
{
  "arch": "x86_64",
  "browserVersion": "1.2.3",
  "ciImageDigest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "fontManifestDigest": "sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
  "hardwareRenderingClass": "software",
  "headlessMode": true,
  "os": "linux",
  "playwrightVersion": "1.2.3",
  "viewport": { "height": 720, "width": 1280 }
}
```

metadata と実行環境の現在値には同じ canonical serializer を適用し、fingerprint が一致した後だけ screenshot を比較する。

```ts
const expectedFingerprint = sha256(canonicalSerialize(baselineMetadata));
const actualFingerprint = sha256(canonicalSerialize(readVisualEnvironment()));

if (actualFingerprint !== expectedFingerprint) {
  throw new Error("visual environment fingerprint mismatch");
}

await expect(page).toHaveScreenshot();
```
