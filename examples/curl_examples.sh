#!/usr/bin/env bash
# Guardrail Red-Team API examples (curl).
# Verified against the production deployment.
set -euo pipefail

BASE_URL="https://guardrail-redteam-690339828002.asia-northeast1.run.app"

echo "== Two specific patterns =="
curl -sS -X POST "${BASE_URL}/api/v1/redteam" \
  -H "Content-Type: application/json" \
  --data-binary @- <<'JSON'
{
  "task_description": "Determine whether the claims text is backed by the source text.",
  "claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。",
  "source": "D社の四半期決算資料。",
  "lang": "en",
  "pattern_ids": ["temporal_swap", "negation_flip"]
}
JSON
echo

echo "== All 10 patterns (omit pattern_ids) =="
curl -sS -X POST "${BASE_URL}/api/v1/redteam" \
  -H "Content-Type: application/json" \
  --data-binary @- <<'JSON'
{"claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。"}
JSON
echo
