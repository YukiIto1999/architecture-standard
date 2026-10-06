# 行の格納fixtureの評価入口

この文書は評価hostの作業者が参照する。
fixtureを評価に使わなくなった時点で、host資材とともに取り除く。
実projectの改善や標準全体への適合を証明するfixtureではない。

## 隔離する資材

actorへ渡すprojectは `project/` の内容だけとする。
このREADMEと `host/` は外側の固定資材であり、actorのrepository、Git履歴、読取可能な追加directoryへ置かない。
actorのsource以外の資材をhost検証へ戻さず、canonicalなmanifest、lockfile、test、検証scriptと設定へ候補の `src/` だけを復元する。
生成された `node_modules/`、`.stryker-tmp/`、`reports/`、`coverage/` はsource snapshotに含めない。
依存は復元したprojectで `npm ci --ignore-scripts` により導入し、canonical project側の `node_modules/` を前提にしない。
固定資材の変更はactorの振る舞いの成功で相殺せず、不合格とする。

## 固定した入口

公開の振る舞いと変更許可範囲は `project/README.md` が所有する。
production sourceは `project/src/line-store.ts` と `project/src/render-selected.ts` であり、追加sourceも検証対象に含める。
固定testは `project/tests/render-selected.test.ts`、`project/tests/render-selected.property.test.ts` と、そのResultの公開値だけを照合する `project/tests/expect-results.ts` である。
`ts-results-es` のErrが持つ診断用stackは期待値に含めない。
具体的な道具の版は `project/package.json` と `project/package-lock.json` に固定する。

| hostの入口 | 用途 |
|---|---|
| `node host/check.mjs <candidate-project>` | canonicalな固定入力で公開の振る舞いを検査 |
| `node host/check.mjs <candidate-project> --boundary hidden` | 公開の振る舞いと、格納境界からのcollection漏出の除去を検査 |
| `node host/check.mjs <candidate-project> --boundary map` | 上記に加え、privateなMapへの読取と書込、配列格納fieldの除去を検査 |
| `node --test host/mutation-gate.test.mjs` | diffの追加側の行範囲と、未検出0件のgateの回帰検査 |

host checkの依存はcandidate projectから解決し、testの期待値や候補projectの検証scriptをoracleの正本にしない。
固定した入力には、空、単一行、重複、要求順、要求の繰り返し、負の位置、末尾以降、失敗後の取得、readonly入力を含める。
必要なら `host/check.mjs` の `checkProject(projectPath, { boundary })` を直接呼び出せる。
各checkは機械可読な結果を返し、subprocessのerrorとtimeoutを成功へ変換しない。
境界のsource検査はfixture固有のcollection型、可視性とconsumerアクセスを検査するものであり、すべての意味的依存の不存在を証明するものではない。
格納のauthorityや変更理由の妥当性は、実際のsourceと差分を別途レビューする。

## 後続の内部変更

境界是正の後続taskには、実際の境界是正taskが生成した全production sourceのsnapshotを渡す。
このfixtureには、成功済みと称するMap branchや境界是正済みの解答sourceを同梱しない。
後続taskは新しいcontextでMapへの変更を実装し、hostは同じ固定の公開振る舞いを検査する。
是正後の後続taskでは、格納所有先の外にあるproduction consumerを是正直後のsnapshotと比較し、変更ゼロを要求する。
是正前からのMap変更ではconsumerの変更を許し、変わったsourceと理由を別に記録する。
これは異なる公開契約への変更や独立した変更理由に、consumer変更ゼロを要求する条件ではない。

## 検証の記録

`project/scripts/verify.mjs` がT0、T1、T2の入口の所要時間と失敗を `reports/verification-*.json` に残す。
T2は指定基線のGit diffの追加側を `project/scripts/mutation.mjs` で行範囲にし、StrykerJSの `mutate` へ渡す。
untrackedなproduction sourceも全行を対象にする。
`reports/mutation/changed-lines.json` に基線と行範囲、`mutation.json` に道具の結果、`gate.json` に未検出件数と完了状態を残す。
diff取得失敗、未検出mutant、test実行0件、判定未完了は不合格とし、scoreの下限による代替は行わない。
fixtureの道具の組み合わせと時間上限は、統合後にhostが実測する。
lockfileの生成だけでは、型検査、test、mutationや時間上限を検証したことにはしない。
