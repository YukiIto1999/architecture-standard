# platforms

platforms は、セルフホストする基盤の採用を定める。
エントリは、[README](../README.md) の書式と選定の共通基準に従う。
基盤に対する規律は concerns と structure が定め、ここでは採用と判断基準だけを持つ。
各エントリは、ツールごとのファイルが持つ。

| 用途 | 採用 | ファイル |
|---|---|---|
| datastore | PostgreSQL | [postgresql.md](./postgresql.md) |
| 一時 store | Valkey | [valkey.md](./valkey.md) |
| 認可の engine | OpenFGA | [openfga.md](./openfga.md) |
| 検査の基盤 | SonarQube Community Build | [sonarqube.md](./sonarqube.md) |
| secret の暗号化 | SOPS | [sops.md](./sops.md) |
| telemetry | OpenTelemetry | [opentelemetry.md](./opentelemetry.md) |
