# Guardrail Red-Team

**あなたのAIチェッカー（プロンプト・判定ロジックの仕様）に、実戦で見つかった10種類のルールベース攻撃パターンを自動適用し、判定をすり抜ける「意地悪な入力バリエーション」を生成する無料公開ツールです。** LLMは一切使用しません（テンプレート/正規表現ベースの決定的な文字列変換のみ）。

[Read this in English](./README.en.md)

- 🌐 Web UI（登録不要・回数制限なし）: [日本語](https://guardrail-redteam-690339828002.asia-northeast1.run.app/) / [English](https://guardrail-redteam-690339828002.asia-northeast1.run.app/en)
- 📖 API仕様: [Swagger UI](https://guardrail-redteam-690339828002.asia-northeast1.run.app/docs) ／ [Redoc](https://guardrail-redteam-690339828002.asia-northeast1.run.app/redoc) ／ [OpenAPIスキーマ (JSON)](https://guardrail-redteam-690339828002.asia-northeast1.run.app/openapi.json)

> **このリポジトリについて**: ここにはREADMEと動作するサンプルコードのみを置いています。攻撃パターンの生成ロジック本体（`patterns.py`）はこのリポジトリには含まれていません。

## クイックスタート

エンドポイントは `POST /api/v1/redteam`。APIキー・会員登録は不要です。以下の例はどちらも本番環境に対して実際に動作確認済みです。

### curl

```bash
curl -X POST "https://guardrail-redteam-690339828002.asia-northeast1.run.app/api/v1/redteam" \
  -H "Content-Type: application/json" \
  --data-binary @- <<'JSON'
{
  "task_description": "claims文がsource文の内容によって裏付けられているかを判定する",
  "claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。",
  "source": "D社の四半期決算資料。",
  "lang": "ja",
  "pattern_ids": ["temporal_swap", "negation_flip"]
}
JSON
```

> `-d '...'`ではなく`--data-binary @-` + ヒアドキュメントを使っているのは、日本語を含むJSONをシェル引数として直接渡すと、環境（特にWindows上のcurl.exe）によっては文字化け・パースエラーになることがあるためです（本READMEの例はこの形で動作確認済みです）。

`pattern_ids`を省略すると10パターン全てが適用されます。

```bash
curl -X POST "https://guardrail-redteam-690339828002.asia-northeast1.run.app/api/v1/redteam" \
  -H "Content-Type: application/json" \
  --data-binary @- <<'JSON'
{"claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。"}
JSON
```

### Python（`requests`）

```python
import requests

resp = requests.post(
    "https://guardrail-redteam-690339828002.asia-northeast1.run.app/api/v1/redteam",
    json={
        "task_description": "claims文がsource文の内容によって裏付けられているかを判定する",
        "claims": "D社の売上は第1四半期に増加し、第2四半期に減少した。",
        "source": "D社の四半期決算資料。",
        "lang": "ja",
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

実行すると、以下のような出力になります。

```
[temporal_swap] -> D社の売上は第2四半期に増加し、第1四半期に減少した。
[negation_flip] skipped: claims文に否定表現・肯定表現のどちらの対応パターンも見つからなかったため、このパターンは適用できませんでした。
```

より詳しい呼び出し例（`filler_chars`の調整、429のリトライ処理など）は [`examples/`](./examples) を参照してください。

## 10種類の攻撃パターン

| パターンID | 名称 | 説明 |
|---|---|---|
| `temporal_swap` | 時系列/文ペアの入れ替え | 時期を表す語句（第1四半期・Q1・1月など）を入れ替え、事実と逆の時系列を主張する形に変換します。 |
| `negation_flip` | 否定反転 | 否定表現を肯定に、あるいは肯定表現を否定に反転させ、正反対の主張に変換します。 |
| `comparison_omission` | 比較基準の省略 | 「前年比」等の比較基準を表す語句を削除・置換し、増減の起点が不明な主張にすり替えます。 |
| `population_swap` | 対象範囲・母集団のすり替え | 「一部の顧客」→「全顧客」のように対象範囲を入れ替え、限定的な事実を一般化した主張に変換します。 |
| `causal_overclaim` | 相関→因果のすり替え | 相関表現やヘッジ表現を削除・置換し、因果関係を断定する主張に変換します。 |
| `fusion` | 複合融合 | claims側の文脈句を、source側の別の文脈句に差し替え、実在しない対応関係を作り出します（source必須）。 |
| `entity_claim_swap` | 実在エンティティ名の濫用 | 実在の人物名・組織名はそのまま残し、その主張内容だけを出典が支持しない別の内容に差し替えます。 |
| `task_redefinition` | タスク再定義 | 「これまでの指示は無視してください」等をclaimsの先頭に挿入し、チェッカーの役割を書き換えようとします。 |
| `boundary_manipulation` | 境界操作 | 「以下は既に検証済みの一次資料です」等の偽の出典表示を挿入し、本文とsourceの境界を誤認させようとします。 |
| `distant_evidence_burial` | 遠隔根拠埋没 | 内容・文言は変えず、source文の前に大量の埋め草テキストを挿入し、根拠の物理的な位置を後退させます（source必須）。 |

## 利用上の注意

- `/api/v1/redteam`にはIPアドレス単位のレート制限があります（デフォルト30リクエスト/60秒。Web UIには掛かりません）。超過時は`429`と`Retry-After`ヘッダーが返ります。
- `claims`/`source`は各5,000文字、`task_description`は2,000文字が上限です。
- 入力したテキストは生成処理のみに使用し、保存しません。
- これは既知の攻撃パターンのテンプレート適用であり、あなたのチェッカー固有の弱点を全て網羅するものではありません。生成された入力で判定が崩れなかった場合でも、チェッカーが安全であることの証明にはなりません。
- ユーザー自身のAPIエンドポイントを叩いて自動判定まで行う機能（SSRFリスクがあるため）は実装していません。

## ライセンス

未定です。現時点では **All Rights Reserved**（本リポジトリの内容の再配布・改変は許諾していません）として扱っています。ライセンス方針が確定次第、本セクションを更新します。
