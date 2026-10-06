# Provenance

この file は生成、mutation、反実仮想の方法の出典と法的表示を記録し、実行時の手順には含めない。
Skill 本文と標準本文は独自に記述し、外部 package の本文、reference、script は複製していない。

| Source | Revision | License | 採用した観点 | 採らなかった内容 |
|---|---|---|---|---|
| [property-testing](https://github.com/nyxandro/property-testing-skill/blob/786d52b3211e3ccbd7fe8727e1d9ae9b9bad16de/property-testing/SKILL.md) | `786d52b3211e3ccbd7fe8727e1d9ae9b9bad16de` | [MIT](https://github.com/nyxandro/property-testing-skill/blob/786d52b3211e3ccbd7fe8727e1d9ae9b9bad16de/LICENSE) | channel からの領域、有効値の構築、空虚な判定の拒否、独立した oracle、操作ごとのモデル、縮小と失敗分類 | 性質の強弱の序列、関数ごとの 1:1、glue の一律除外、到着順の一律不変、language と runner の追加採用 |
| [mutation-testing](https://github.com/honnibal/claude-skills/blob/35b43e399bb8078a3d5b01ff6d86f06956df7591/mutation-testing.md.txt) | `35b43e399bb8078a3d5b01ff6d86f06956df7591` | [MIT](https://github.com/honnibal/claude-skills/blob/35b43e399bb8078a3d5b01ff6d86f06956df7591/LICENSE) | 小さい実装変更と破る保証と検出する判定の対応 | fixed count、全量の反復、timeout の一律検出扱い、利用者の変更を戻す Git 操作 |
| [pre-mortem](https://github.com/honnibal/claude-skills/blob/35b43e399bb8078a3d5b01ff6d86f06956df7591/pre-mortem.md.txt) | `35b43e399bb8078a3d5b01ff6d86f06956df7591` | [MIT](https://github.com/honnibal/claude-skills/blob/35b43e399bb8078a3d5b01ff6d86f06956df7591/LICENSE) | 合理的な変更から暗黙の不変条件と consumer の失敗を辿る思考実験 | 架空の incident を実際の報告の形にすること、独立した汎用設計 Skill、専用の報告 file |

確認日は 2026-10-06 である。
取得した方法は採否の材料として扱い、framework の具体的な仕様や経験的な改善量は採用していない。
契約から入力領域と oracle、操作列、縮小、分類へ進む方法の規範は `structure/tests/methods.md` に置き、Skill は実作業への適用を所有する。
強制的な assertion の赤と検証対象の保証の違反を検出した赤を区別するため、`principles/verification/test-reliability.md` の要求と完了条件も更新した。
検証の反復と証跡の再利用は `process/verification.md` の現行規律を使い、変更行の未検出 0 件、全量の生成 0 件の床を維持した。

往復する二つの変換が同じずれを持つ場合、定数 0 でも成り立つ比例関係、後続の clear が途中の欠落を消す操作列、全入力を棄却する生成器は、方法の限界を分ける論理的な反例である。
これらは repository の製品欠陥や framework benchmark の報告ではない。
同梱した task と発火境界の入力は未実行であり、baseline、forward eval、ablation の改善量は未測定である。

## Legal notices

MIT License

Copyright (c) 2026 nyxandro

Copyright (c) 2026 Matthew Honnibal

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
