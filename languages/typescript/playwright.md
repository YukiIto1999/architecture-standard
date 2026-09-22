# Playwright

用途は、UI をブラウザ越しに操作し見た目と疎通を確かめる実行系である。
採用は、TypeScript は Playwright である。
判断基準は、browser の操作と screenshot 比較を test runner として実行でき、操作の入力から表示までの時刻を測定でき、baseline 画像と実行環境の記録を版管理してレビューできることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 表示までの時間を E2E で測る

### 要求
[experience](../../concerns/experience/README.md) が定める状態または feedback の100ms、1秒を超える operation の progress 開始までの1秒と完了までの継続は、Playwright の E2E で表示時刻を測定する。

### 根拠
操作の入力と表示結果を同じ E2E で測れば、handler の起動や server の完了でなく、利用者が状態、feedback、progress を見られるまでの時間を判定できる。

### 完了条件
各操作の入力時刻、状態または feedback の表示時刻、1秒を超える operation の progress 表示時刻と完了時刻が Playwright で測定され、experience の閾値と継続条件を満たしている。

### 禁止事項
handler の起動時刻または server の完了時刻を、状態、feedback、progress が利用者へ表示された時刻として扱うこと。

### 行動
Playwright で操作を入力し、入力時刻、状態または feedback の表示時刻、progress の表示時刻、完了時刻を記録して、experience の閾値と継続条件を検査する。

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
