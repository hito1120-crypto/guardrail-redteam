"""Guardrail Red-Team API example (Python + requests).

Verified against the production deployment. Run with:
    pip install requests
    python redteam_client.py
"""
import requests

BASE_URL = "https://guardrail-redteam-690339828002.asia-northeast1.run.app"


def main() -> None:
    resp = requests.post(
        f"{BASE_URL}/api/v1/redteam",
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


if __name__ == "__main__":
    main()
