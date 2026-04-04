# Wisper engine

Small **OpenAI-compatible** HTTP proxy for the WisperClone macOS app. It keeps `OPENAI_API_KEY` on the server and authenticates clients with `WISPER_ENGINE_TOKEN` (stored in the app’s Keychain as the “API key or engine token”).

**Speech-to-text stays on the Mac** (Apple Speech or whisper.cpp). This service only proxies **chat completions** (the rewrite / LLM step).

## Setup

```bash
cd engine
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Export variables (or copy `.env.example` to `.env` and load it however you prefer):

```bash
export OPENAI_API_KEY="sk-..."
export WISPER_ENGINE_TOKEN="your-long-random-secret"
```

## Run

```bash
uvicorn main:app --host 127.0.0.1 --port 8765
```

## Health check

```bash
curl -s http://127.0.0.1:8765/health
```

## Streaming chat completions (curl)

Replace `YOUR_ENGINE_TOKEN` and ensure the model exists on your OpenAI account:

```bash
curl -sN http://127.0.0.1:8765/v1/chat/completions \
  -H "Authorization: Bearer YOUR_ENGINE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "stream": true,
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Say hello in one short sentence."}
    ]
  }'
```

You should see SSE lines starting with `data: `, ending with `data: [DONE]`.

## WisperClone app settings

1. **API base URL:** `http://127.0.0.1:8765/v1` (include `/v1`; the app appends `/chat/completions`).
2. **API key / engine token:** same value as `WISPER_ENGINE_TOKEN`.
3. **Model:** e.g. `gpt-4o-mini` (passed through to OpenAI).

## Production notes

- Terminate TLS in front of this service; do not expose it without authentication.
- Rotate `WISPER_ENGINE_TOKEN` if it leaks; consider per-user tokens and rate limits for a real product.
