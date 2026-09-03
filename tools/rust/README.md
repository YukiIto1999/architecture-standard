# rust ecosystem

rust の言語としての採用と、実現規律、採用物を置く。
言語の採用は、Rust edition 2024 である。
判断基準は、言語ごとの実現規律と検証方法を標準本文で完結して定められることである。
撤回条件は、判断基準を満たさなくなることであり、基盤版の保守終了または実現規律の欠落を再評価のトリガーとする。
実現軸と書式は、[tools の README](../README.md) の言語 ecosystem に従う。

## 実現軸

| ファイル | 意味 |
|---|---|
| [formation](./formation.md) | 値・型・不変条件のモデリング(実現軸) |
| [translation](./translation.md) | 外界境界での意味の出し入れ(実現軸) |
| [connection](./connection.md) | 副作用と依存の渡し方(実現軸) |
| [coordination](./coordination.md) | 非同期・並行・取り消しの実行(実現軸) |
| [publication](./publication.md) | 外部公開面と host(実現軸) |
| [inspection](./inspection.md) | 検証(実現軸) |
| [conventions](./conventions.md) | 命名・整形・ドキュメントコメント・型名接尾辞(全域規律) |

## 採用

採用物ごとに一つの file を置き、用途・採用・判断基準・撤回条件を持つ。

| ファイル | 用途 | 採用 |
|---|---|---|
| [apalis](./apalis.md) | 背景処理と定期実行の daemon の骨格である | Rust は apalis であり、PostgreSQL を backend にした queue に限って使う |
| [async-trait](./async-trait.md) | 実行時に差し替える非同期の port を動的ディスパッチで扱う機構である | Rust は async-trait である |
| [axum](./axum.md) | HTTP の API を公開する surface の骨格である | Rust は axum である |
| [cargo-llvm-cov](./cargo-llvm-cov.md) | テストが実行していない箇所を見つけるカバレッジ計測である | Rust は cargo-llvm-cov である |
| [cargo-mutants](./cargo-mutants.md) | テストが振る舞いを固定しているかを測る mutation 検査である | Rust は cargo-mutants である |
| [cargo-nextest](./cargo-nextest.md) | 単体・性質・結合のテストの実行系である | Rust は cargo-nextest である |
| [clap](./clap.md) | CLI の surface の骨格である | Rust は clap である |
| [clippy](./clippy.md) | 規則の違反をビルドで止める linter である | Rust は clippy である |
| [cucumber](./cucumber.md) | 業務語彙の executable spec を実行する道具である | Rust は cucumber の Rust 実装である |
| [fred](./fred.md) | Valkey へ接続する client である | Rust は fred である |
| [openidconnect](./openidconnect.md) | BFF の token 管理・OIDC クライアント | Rust は tower-sessions のサーバー側セッションと openidconnect のトークンエンドポイントクライアントである |
| [proptest](./proptest.md) | 入出力の不変量を性質として多くの入力で検査する property-based testing である | Rust は proptest である |
| [rustfmt](./rustfmt.md) | 表記を道具の既定で一意に揃える formatter である | Rust は rustfmt である |
| [serde](./serde.md) | 値を wire 形式と相互に直列化・逆直列化する機構である | Rust は serde である |
| [sqlx-cli](./sqlx-cli.md) | schema を変更する forward-only の SQL script を、履歴順に一度だけ、アプリの配備から独立して適用する道具である | Rust は sqlx-cli である |
| [sqlx](./sqlx.md) | SQL を型で扱いながら書く永続化アクセス層である | Rust は sqlx である |
| [tauri](./tauri.md) | 被ホストの viewer と core を利用者の端末で動かす host である | core が Rust のときは desktop・mobile ともに Tauri である |
| [testcontainers](./testcontainers.md) | 実依存のコンテナを起動し、本物に近い依存で検証する道具である | Rust は testcontainers である |
| [thiserror](./thiserror.md) | 責務の単位でエラー型を宣言し表示と変換を導出する機構である | Rust は thiserror である |
| [tokio-util](./tokio-util.md) | 協調的な取り消しを、処理の木へ伝える token の機構である | Rust は tokio-util である |
| [tokio](./tokio.md) | 非同期の実行を担う runtime である | Rust は Tokio である |
| [tower-lsp-server](./tower-lsp-server.md) | 言語サービスの公開・extension が接続する core への JSON-RPC | tower-lsp-server である |
| [tower-sessions](./tower-sessions.md) | BFF の token 管理・BFF の session 管理 | Rust は tower-sessions のサーバー側セッションと openidconnect のトークンエンドポイントクライアントである |
| [tower](./tower.md) | HTTP の経路の横断処理を、層として合成する機構である | Rust は tower と tower-http である |

## 言語機構で満たす用途

外部の採用物を持たず、言語機構または既存の採用で満たす用途を示す。

| 用途 | 満たし方 | 置き場 |
|---|---|---|
| viewer・extension・host の効果の表現 | 言語機構(Future・Result)で表し、外部ライブラリを採らない | [connection](./connection.md) |
| API の禁止 | clippy の disallowed_methods で満たし、専用の道具を置かない | [clippy](./clippy.md) |
| 構造検査 | root の tests/ に置く自作の構造検査で満たし、道具を置かない | [inspection](./inspection.md) |
| 未使用コードの検出 | コンパイラと lint の到達可能性に基づく検出で満たし、専用の道具を置かない | [inspection](./inspection.md) |
| UI の accessibility 検査 | viewer を TypeScript に委ねるため採用を持たない | — |
