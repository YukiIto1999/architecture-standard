# Syft

用途は、release する成果物の部品を、言語横断の機械可読な一覧へ生成する道具である。
採用は、Syft であり、出力は SPDX JSON とする。
判断基準は、filesystem・archive・container image の完成した成果物を走査し、対象言語と OS package を署名と脆弱性検査の共通入力へ出力できることである。
撤回条件は、判断基準を満たさなくなることであり、対象 ecosystem の対応終了と保守の停止を再評価のトリガーとする。
