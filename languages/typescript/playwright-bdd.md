# playwright-bdd

用途は、Gherkin の feature を Playwright Test のテストファイルへ変換し、UI smoke を Gherkin で書けるようにする変換器である。
採用は、TypeScript は playwright-bdd である。
判断基準は、Gherkin の記法で UI smoke を書け、変換した test の実行を [playwright](./playwright.md) の runner に委ねられることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。

## 仕様

### 要求
業務語彙の executable spec は、[verification](../../principles/verification/README.md) が定める同じ検査経路で、cucumber-js として実行する。
feature の各 step は、一つの step binding と、その binding が呼ぶ公開 interface の operation に対応させる。
feature、step binding、公開 interface の対応は、各一覧を実体から導く drift 検査と executable spec の実行で検証する。
UI の E2E smoke と visual は playwright-bdd と Playwright で書き、両者は目的が別なので代替として並べない。
[experience](../../concerns/experience/README.md) が定める状態または feedback の100ms、1秒を超える operation の progress 開始までの1秒と完了までの継続は、Playwright の E2E で表示時刻を測定する。
visual の baseline 画像は、画像ごとか同じ実行環境を使う画像集合ごとに対応する metadata と組にし、レビューを通して版管理する。
metadata は、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport を持つ。
metadata の各値は、形式を固定した canonical serialization から environment fingerprint を生成できる形で記録する。
visual は、実行環境の現在値から生成した environment fingerprint と metadata の fingerprint を screenshot の比較前に照合する。
fingerprint が一致しないときは、visual を失敗させ、旧い baseline 画像との screenshot 比較を実行しない。
baseline を更新するときは、画像と metadata を一つの更新単位として生成し、同じ変更で明示的にレビューする。

### 根拠
[verification](../../principles/verification/README.md) が定める、実行可能な仕様と実装を同じ検査経路に載せ、別成果物なら対応を検証する要求に、cucumber-js で応える。
feature、step binding、公開 interface は別の成果物なので、対応の drift 検査がなければ一方だけ古くなりうる。
executable spec は、業務の振る舞いを公開の interface 越しに確かめる。
UI の E2E smoke と visual は、ブラウザ越しの見た目と疎通を確かめる。
操作の入力と表示結果を同じ E2E で測れば、handler の起動や server の完了でなく、利用者が状態、feedback、progress を見られるまでの時間を判定できる。
baseline 画像と実行環境の metadata を組にすれば、画像を承認した環境を再現できる。
canonical serialization から fingerprint を生成すれば、metadata の表記揺れを環境差と誤認しない。
fingerprint を screenshot の比較前に照合すれば、実行環境の差を見た目の変更として承認する経路を閉じられる。
画像と metadata を一つの更新単位にすれば、画像だけを別の環境へ持ち越さない。
`toHaveScreenshot` の差分を検証入口で検出すれば、未レビューの見た目の変更が baseline へ混入しない。
cucumber-js は Cucumber 自身を test runner にして、業務語彙のシナリオを公開の interface 越しに検証する。
playwright-bdd は Gherkin の feature ファイルを Playwright Test のテストファイルへ変換する変換器で、実行は Playwright の runner が担い、UI を操作して見た目と疎通を確かめる。
同じ Gherkin の記法でも、前者は業務語彙の仕様の実行系、後者は UI smoke を Gherkin で書くための変換器であり、担う目的が違う。
両者は目的が違う。
目的の違うものを代替として並べると、どちらの役割も果たせなくなる。

### 完了条件
業務語彙の executable spec が、cucumber-js で書かれ、実行されている。
feature の全 step が、一つの step binding と公開 interface の operation に対応している。
feature、step binding、公開 interface の対応に欠落と余剰がなく、drift 検査と executable spec の実行が同じ検証入口で通っている。
UI の E2E smoke と visual が、playwright-bdd と Playwright で書かれている。
各操作の入力時刻、状態または feedback の表示時刻、1秒を超える operation の progress 表示時刻と完了時刻が Playwright で測定され、experience の閾値と継続条件を満たしている。
visual の baseline 画像と対応する metadata が、レビュー済みの状態で版管理されている。
各 baseline 画像か同じ実行環境を使う画像集合の metadata に、実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport が記録されている。
metadata と実行環境の現在値が、同じ canonical serialization から environment fingerprint を生成している。
二つの fingerprint が一致した場合だけ、`toHaveScreenshot` が baseline 画像を比較している。
fingerprint が一致しない場合は、screenshot を比較せずに visual が失敗している。
baseline 画像と metadata の更新が一つの更新単位で行われ、同じ変更として明示的にレビューされている。
baseline 画像か metadata の生成に失敗した場合は、どちらも更新されていない。
両者が、代替として並べられていない。

### 禁止事項
executable spec と UI の E2E smoke・visual を、代替として並べること。
handler の起動時刻または server の完了時刻を、状態、feedback、progress が利用者へ表示された時刻として扱うこと。
visual の baseline 画像か metadata のどちらか一方だけを更新すること。
baseline 画像と metadata の更新を、レビューなしに確定すること。
実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport のいずれかを metadata から省くこと。
environment fingerprint が一致しない状態で、旧い baseline 画像との screenshot 比較を実行すること。
baseline 画像と metadata を別々の変更で更新すること。
仕様に、実装の操作の語を書くこと。
実行可能であることを理由に、feature、step binding、公開 interface の継ぎ目が消えたとみなすこと。
feature、step binding、公開 interface の対応を、人が固定した件数だけで検査すること。

### 行動
業務の語彙でシナリオを書き、cucumber-js のステップで実装する。
feature の step、step binding、公開 interface の operation をそれぞれ実体から列挙し、対応の欠落と余剰を drift 検査で失敗させる。
drift 検査と executable spec を、実装と同じ検証入口で実行する。
UI の E2E smoke と visual は playwright-bdd と Playwright で別に書く。
Playwright で操作を入力し、入力時刻、状態または feedback の表示時刻、progress の表示時刻、完了時刻を記録して、experience の閾値と継続条件を検査する。
baseline 画像ごとか同じ実行環境を使う画像集合ごとに metadata を置き、画像とともに版管理する。
実行 image digest、OS、arch、hardware rendering class、Playwright と browser の version、headless mode、font manifest digest、viewport を metadata へ記録する。
metadata と実行環境の現在値を同じ形式で canonical serialization し、それぞれの environment fingerprint を生成する。
二つの fingerprint を screenshot の比較前に照合し、一致しなければ失敗させる。
fingerprint が一致した場合だけ、`toHaveScreenshot` で baseline 画像を比較する。
baseline を更新するときは、画像と metadata の両方を生成する単一の更新処理を使い、片方の生成に失敗したら両方を確定しない。
baseline の画像と metadata の差分を、同じ変更として明示的にレビューする。

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

baseline の更新処理は画像と metadata を同時に生成し、両方を同じ変更としてレビューへ出す。
