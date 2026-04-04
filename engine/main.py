"""
Wisper engine: OpenAI-compatible streaming proxy for chat/completions.
The macOS app sends Bearer WISPER_ENGINE_TOKEN; this service forwards to OpenAI with OPENAI_API_KEY.
"""

import os
import secrets
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response, StreamingResponse

app = FastAPI(title="Wisper Engine", version="0.1.0")

_OPENAI_API_KEY: Optional[str] = None
_ENGINE_TOKEN: Optional[str] = None
_OPENAI_BASE_URL: str = "https://api.openai.com/v1"


@app.on_event("startup")
def _load_config() -> None:
    global _OPENAI_API_KEY, _ENGINE_TOKEN, _OPENAI_BASE_URL
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    token = os.environ.get("WISPER_ENGINE_TOKEN", "").strip()
    if not key:
        raise RuntimeError("OPENAI_API_KEY is required")
    if not token:
        raise RuntimeError("WISPER_ENGINE_TOKEN is required")
    _OPENAI_API_KEY = key
    _ENGINE_TOKEN = token
    base = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1").strip().rstrip("/")
    _OPENAI_BASE_URL = base


def _verify_bearer(request: Request) -> None:
    assert _ENGINE_TOKEN is not None
    auth = request.headers.get("authorization") or request.headers.get("Authorization") or ""
    if not auth.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization")
    token = auth[7:].strip()
    if not secrets.compare_digest(token, _ENGINE_TOKEN):
        raise HTTPException(status_code=401, detail="Invalid token")


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/v1/chat/completions", response_model=None)
async def proxy_chat_completions(request: Request):
    _verify_bearer(request)
    assert _OPENAI_API_KEY is not None

    body = await request.body()
    url = f"{_OPENAI_BASE_URL}/chat/completions"
    fwd_headers: dict[str, str] = {
        "Authorization": f"Bearer {_OPENAI_API_KEY}",
        "Content-Type": request.headers.get("content-type") or "application/json",
    }

    timeout = httpx.Timeout(connect=60.0, read=600.0, write=60.0, pool=60.0)
    client = httpx.AsyncClient(timeout=timeout)

    try:
        cm = client.stream("POST", url, content=body, headers=fwd_headers)
        resp = await cm.__aenter__()
    except Exception:
        await client.aclose()
        raise

    if resp.status_code >= 400:
        err_body = await resp.aread()
        await cm.__aexit__(None, None, None)
        await client.aclose()
        return Response(
            content=err_body,
            status_code=resp.status_code,
            media_type=resp.headers.get("content-type", "application/json"),
        )

    async def stream_bytes():
        try:
            async for chunk in resp.aiter_raw():
                yield chunk
        finally:
            await cm.__aexit__(None, None, None)
            await client.aclose()

    media_type = resp.headers.get("content-type") or "text/event-stream"
    return StreamingResponse(stream_bytes(), status_code=resp.status_code, media_type=media_type)
