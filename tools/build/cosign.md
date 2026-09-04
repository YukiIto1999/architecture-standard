# Cosign

用途は、release 成果物の digest と生成経路を、検証可能な署名済みの provenance に結び付ける機構である。
採用は、署名と検証に Cosign の鍵ペア署名(keyless を使わない)、provenance に SLSA v1.2 の Build Provenance を使い、生成する build platform は project が外部 service を一つ選んで ADR に記録する。
判断基準は、成果物と attestation Statement の subject digest、Build Provenance の builder identity、build type、external parameters を検証時に照合でき、署名の記録が公開の transparency log へ出ないことである。keyless は署名のたびに私設の成果物の識別子を公開の追記専用 log へ載せ、削除できないため採らない。
撤回条件は、判断基準を満たさなくなることであり、Cosign の鍵署名、SLSA Build Provenance、採用した build platform の提供条件の変化を再評価のトリガーとする。
