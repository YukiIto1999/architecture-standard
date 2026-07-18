# language

language は、言語の選定を定める。
[README](./README.md) の選定の共通基準に従う。

## 対象言語の集合

用途は、標準が languages 層で実現を定める言語の集合である。
採用は、Rust・C#・TypeScript である。
各言語の役割と基盤の版は、[languages/README](../languages/README.md) の言語と役割の表を正本とする。
判断基準は、core・surface・host の全役割を、この集合で単一に覆えることである。
撤回条件は、判断基準を満たさなくなることであり、役割の追加と基盤の版の停滞を再評価のトリガーとする。

## core 言語の選定観点

project は、core の言語を一つ選び、選定の理由と単一採用を project の ADR に記録する。
選定の基準は、[languages/README](../languages/README.md) の言語と役割の表の役割の差である。

## 対象外言語の縮退経路

対象に無い言語を使う project は、principles・concerns・structure に従い、languages 相当の定めを project の ADR で定める。
