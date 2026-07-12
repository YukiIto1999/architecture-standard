# language

language は、言語の選定を定める。
[README](./README.md) の選定の共通基準に従う。

## 対象言語の集合

この標準が対象とする言語は、Rust・C#・TypeScript である。
採用は、core は Rust・C#、host と viewer と extension は TypeScript である。
各言語の役割と基盤の版は、[languages/README](../languages/README.md) の言語と役割の表を正本とする。

## core 言語の選定観点

project は、core の言語を一つ選び、選定の理由と単一採用を project の ADR に記録する。
選ぶ基準は、言語と役割の表の役割の差である。
選定の手順は、[languages/README](../languages/README.md) に従う。

## 対象外言語の縮退経路

対象に無い言語を使う project は、principles・concerns・structure に従い、languages 相当の定めを project の ADR で定める。
