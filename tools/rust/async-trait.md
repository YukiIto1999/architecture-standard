# async-trait

用途は、実行時に差し替える非同期の port を動的ディスパッチで扱う機構である。
採用は、Rust は async-trait である。
判断基準は、edition のネイティブな async trait が dyn に乗らない制約を補い、trait の非同期メソッドを dyn で差し替え可能にすることである。
撤回条件は、判断基準を満たさなくなることであり、edition のネイティブな async trait が dyn に対応することを再評価のトリガーとする。
