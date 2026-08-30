# Guardrail Red-Team

**A free tool that automatically applies 10 rule-based attack patterns — discovered through real-world red-teaming — to your AI checker (a prompt / judgment-logic spec), generating adversarial input variations designed to slip past its judgment.** It does not use an LLM at all (deterministic template / regex-based text transformations only).

[日本語版はこちら](./README.md)

- 🌐 Web UI (no sign-up, no rate limit): [English](https://guardrail-redteam-690339828002.asia-northeast1.run.app/en) / [日本語](https://guardrail-redteam-690339828002.asia-northeast1.run.app/)
- 📖 API reference: [Swagger UI](https://guardrail-redteam-690339828002.asia-northeast1.run.app/docs) / [Redoc](https://guardrail-redteam-690339828002.asia-northeast1.run.app/redoc) / [OpenAPI schema (JSON)](https://guardrail-redteam-690339828002.asia-northeast1.run.app/openapi.json)

> **About this repository**: this repo contains only a README and working sample code. The attack-pattern generation logic itself (`patterns.py`) is not included here.

## Quickstart

The endpoint is `POST /api/v1/redteam`. No API key or sign-up required. Both examples below have been verified to work against the production deployment.

### curl

```bash
curl -X POST "https://guardrail-redteam-690339828002.asia-northeast1.run.app/api/v1/redteam" \
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
```

> We use `--data-binary @-` with a heredoc instead of `-d '...'` because passing JSON containing non-ASCII characters directly as a shell argument can get mangled or fail to parse on some setups (notably curl.exe on Windows). The examples above were verified to work in this form.

Omit `pattern_ids` to run all 10 patterns.

```bash
curl -X POST "https://guardrail-redteam-690339828002.asia-northeast1.run.app/api/v1/redteam" \
  -H "Content-Type: application/json" \
  --data-binary @- <<'JSON'
{"claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。"}
JSON
```

### Python (`requests`)

```python
import requests

resp = requests.post(
    "https://guardrail-redteam-690339828002.asia-northeast1.run.app/api/v1/redteam",
    json={
        "task_description": "Determine whether the claims text is backed by the source text.",
        "claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。",
        "source": "D社の四半期決算資料。",
        "lang": "en",
        "pattern_ids": ["temporal_swap", "negation_flip"],
    },
    timeout=10,
)
resp.raise_for_status()

for result in resp.json():
    if result["applied"]:
        print(f"[{result['pattern_id']}] -> {result['result']}")
    else:
        print(f"[{result['pattern_id']}] skipped: {result['skip_reason']}")
```

This prints something like:

```
[temporal_swap] -> D社の売上は第2四半期に増加し、第1四半期に減少した。
[negation_flip] skipped: This pattern could not be applied: no matching negative or affirmative expression was found in the claims text.
```

Note: the sample `claims`/`source` text above is Japanese — the API transforms text in either language, but pattern coverage differs slightly per language (see the pattern table below). See [`examples/`](./examples) for more detailed usage (tuning `filler_chars`, handling `429` retries, etc).

## The 10 attack patterns

| Pattern ID | Name | What it does |
|---|---|---|
| `temporal_swap` | Temporal / clause-pair swap | Swaps time-related markers (e.g. Q1/Q2, quarter names, months) to reverse the claimed timeline. |
| `negation_flip` | Negation flip | Flips a negative expression to affirmative (or vice versa), reversing the claim's meaning. |
| `comparison_omission` | Comparison-basis omission | Removes/rewrites comparison-basis phrases (e.g. "year-over-year"), swapping in a claim with an unclear reference point. |
| `population_swap` | Population / scope swap | Swaps scope-quantifier words (e.g. "some customers" → "all customers"), generalizing a limited claim. |
| `causal_overclaim` | Correlation-to-causation overclaim | Removes hedges or rewrites correlation language into a causal claim. |
| `fusion` | Multi-source fusion | Replaces a claim's context phrase with an unrelated context phrase from the source text, fabricating a nonexistent correspondence (requires `source`). |
| `entity_claim_swap` | Real-entity name reuse | Keeps a real person/organization name unchanged but replaces the claim content attached to it with content the source does not support. |
| `task_redefinition` | Task redefinition | Prepends text that tries to override the checker's role (e.g. "ignore prior instructions"). |
| `boundary_manipulation` | Boundary manipulation | Prepends a fake "already-verified source" marker to blur the boundary between untrusted input and trusted source. |
| `distant_evidence_burial` | Distant evidence burial | Leaves content and wording unchanged but prepends a large filler block before the source, pushing it far back in the document (requires `source`). |

## Usage notes

- `/api/v1/redteam` has a per-IP rate limit (default: 30 requests/60s; the Web UI is not rate-limited). Exceeding it returns `429` with a `Retry-After` header.
- `claims`/`source` are capped at 5,000 characters each; `task_description` at 2,000.
- Text you submit is used only for generation and is not stored.
- This is a template application of known attack patterns — it does not cover every possible weakness specific to your checker. If your checker holds up against the generated inputs, that does not prove it is safe.
- There is no feature to call your own API endpoint and run automated judging (this is intentionally out of scope, to avoid SSRF risk).

## License

Not yet finalized. Until then, this repository's content is treated as **All Rights Reserved** (no redistribution or modification is granted). This section will be updated once a license is decided.
