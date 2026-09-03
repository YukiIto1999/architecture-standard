# openidconnect

## BFF の token 管理

用途は、BFF が保持する token の交換と更新を担う機構である。
採用は、Rust は tower-sessions のサーバー側セッションと openidconnect のトークンエンドポイントクライアントである。
サーバー側セッションの分担は [tower-sessions](./tower-sessions.md) が受け持つ。
判断基準は、token set と expiry を server 側に保持し、期限前の更新で得た token set を同じ session へ置き換えられることである。
撤回条件は、判断基準を満たさなくなることであり、ライセンス、リリースポリシー、session と token endpoint の互換性の変化を再評価のトリガーとする。

## OIDC クライアント

用途は、OIDC の code と PKCE のフローを終端し ID Token を検証するクライアントである。
採用は、Rust は openidconnect である。
判断基準は、authorization code と PKCE の flow を終端し、ID Token の署名、issuer、audience、nonce を検証できることである。
撤回条件は、判断基準を満たさなくなることであり、保守の停止を再評価のトリガーとする。
