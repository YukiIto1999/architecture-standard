# OSV-Scanner

用途は、release 成果物の SBOM を既知脆弱性と照合し、検出を release の失敗にする道具である。
採用は、OSV-Scanner である。
判断基準は、SPDX の SBOM を入力にでき、言語を横断して既知脆弱性が一件でもあれば非ゼロの終了値を返すことである。
撤回条件は、判断基準を満たさなくなることであり、advisory database の更新停止と保守の停止を再評価のトリガーとする。
