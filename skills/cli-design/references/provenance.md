# Provenance

この file は CLI と terminal の方法の出典と法的表示を記録し、実行時の手順には含めない。
Skill 本文と標準本文は独自に記述し、外部 package の本文、reference、script は複製していない。

| Source | Revision | License | 採用した観点 | 採らなかった内容 |
|---|---|---|---|---|
| [create-cli](https://github.com/steipete/agent-scripts/blob/79150cfac4a6ba4df13cf30176bf2db85170ae6c/skills/create-cli/SKILL.md) | `79150cfac4a6ba4df13cf30176bf2db85170ae6c` | [MIT](https://github.com/steipete/agent-scripts/blob/79150cfac4a6ba4df13cf30176bf2db85170ae6c/LICENSE) | 人と script の契約、入力と出力、終了、設定解決、破壊操作、実装可能な呼び出し仕様 | donor package への実行依存、推測した既定値、環境変数を含む固定優先順、固定した例の件数 |
| [tui-design](https://github.com/gfargo/tui-design-skill/blob/ad8407a34ffe43793ae4d07280bdae25a2b12f13/plugins/tui-design/skills/tui-design/SKILL.md) | `ad8407a34ffe43793ae4d07280bdae25a2b12f13` | [MIT](https://github.com/gfargo/tui-design-skill/blob/ad8407a34ffe43793ae4d07280bdae25a2b12f13/LICENSE) | terminal の所有と復元、一時引き渡しと終了の区別、cell 幅、入力 loop、PTY の実結合 | ecosystem の追加採用、固定寸法と操作数、固定した PTY 件数、汎用 review の別入口 |

確認日は 2026-10-06 である。
取得した方法は採否の材料として扱い、製品や framework の経験的な品質の主張は採用していない。
CLI 固有の規範は `structure/surfaces/console/layout.md`、設定解決は `concerns/configuration/single-config-source.md`、検査への割当は `structure/tests/methods.md` に置いた。
複数源の解決を一つの設定源の契約に集め、環境変数と secret の既存の禁止を維持した。
Skill はそれらを project の呼び出しへ落とす手順だけを所有する。
代表的な task と発火境界の入力を同梱したが、baseline、forward eval、ablation は未実行であり、改善量は未測定である。

## Legal notices

MIT License

Copyright (c) 2026 Peter Steinberger

Copyright (c) 2026 gfargo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
