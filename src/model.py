"""Fixed, auditable DeepSeek client for the comparison experiment.

The client deliberately sends no temperature/top_p parameters. Credentials are loaded
from the repository-local .env, but are never included in request logs.
"""
import hashlib
import json
import os
import re
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

import httpx
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env", override=False)

MODEL_NAME = "deepseek-flash"
REASONING_EFFORT = "high"
THINKING = {"type": "enabled"}
MAX_TOKENS = 65536
REQUEST_TIMEOUT_SECONDS = 300.0
MAX_RETRIES = 0

_api_key = os.getenv("DEEPSEEK_API_KEY") or os.getenv("OPENAI_API_KEY", "")
_base_url = os.getenv("DEEPSEEK_BASE_URL") or os.getenv("OPENAI_BASE_URL") or "https://api.deepseek.com"
completion_tokens = 0
prompt_tokens = 0
cache_hit_tokens = 0
cache_miss_tokens = 0
request_attempt_count = 0
usage_missing_count = 0
usage_invalid_count = 0
last_request_error = None


def _append_request_log(record):
    log_path = os.getenv("TOOL_REQUEST_LOG_FILE")
    if not log_path:
        return
    path = Path(log_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as output:
        output.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
        output.flush()
        os.fsync(output.fileno())


def _request_context():
    return {
        "tool": os.getenv("EXPERIMENT_TOOL", "GPTLens"),
        "dataset": os.getenv("EXPERIMENT_DATASET"),
        "case_id": os.getenv("EXPERIMENT_CASE_ID"),
        "case_ids": [x for x in os.getenv("EXPERIMENT_CASE_IDS", "").split(",") if x],
        "project_id": os.getenv("EXPERIMENT_PROJECT_ID"),
        "input_id": os.getenv("EXPERIMENT_INPUT_ID"),
        "stage": os.getenv("EXPERIMENT_STAGE"),
        "prompt_layout": os.getenv("EXPERIMENT_PROMPT_LAYOUT", "baseline"),
    }


def _usage_int(usage, key):
    value = usage.get(key) if isinstance(usage, dict) else None
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else None


def _record_error(call_id, request_body, started, error, raw_response=None):
    global last_request_error
    last_request_error = {
        "error_type": type(error).__name__,
        "http_status": getattr(error, "status_code", None),
        "provider_error_code": getattr(error, "code", None),
    }
    record = {
        **_request_context(),
        "event": "error",
        "call_id": call_id,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "status": "error",
        "model": MODEL_NAME,
        "request": request_body,
        "latency_seconds": round(time.monotonic() - started, 6),
        "error_type": type(error).__name__,
        "http_status": getattr(error, "status_code", None),
        "request_id": getattr(error, "request_id", None),
    }
    if raw_response is None:
        response = getattr(error, "response", None)
        if response is not None:
            try:
                raw_response = response.json()
            except Exception:
                raw_response = getattr(response, "text", None)
    if raw_response is not None:
        # Provider error bodies are useful for audit (e.g. context-limit/quota
        # codes), but scrub credential-shaped strings before persisting.
        def scrub(value):
            if isinstance(value, str):
                if _api_key:
                    value = value.replace(_api_key, "[REDACTED]")
                return re.sub(r"(?i)sk-[A-Za-z0-9_-]{12,}", "[REDACTED]", value)
            if isinstance(value, list):
                return [scrub(item) for item in value]
            if isinstance(value, dict):
                return {key: scrub(item) for key, item in value.items()}
            return value
        record["raw_response"] = scrub(raw_response)
    record["provider_error_code"] = getattr(error, "code", None)
    _append_request_log(record)


def gpt(prompt, model=None, max_tokens=MAX_TOKENS, n=1, stop=None) -> list:
    messages = [{"role": "user", "content": prompt}]
    return chatgpt(messages, model=MODEL_NAME, max_tokens=max_tokens, n=n, stop=stop)


def chatgpt(messages, model=MODEL_NAME, max_tokens=MAX_TOKENS, n=1, stop=None) -> list:
    global completion_tokens, prompt_tokens, cache_hit_tokens, cache_miss_tokens
    global request_attempt_count, usage_missing_count, usage_invalid_count
    if max_tokens != MAX_TOKENS:
        raise ValueError("GPTLens comparison protocol fixes max_tokens at 65536")
    if not _api_key:
        raise RuntimeError("No LLM API key configured; set DEEPSEEK_API_KEY.")

    outputs = []
    prompt_sha256 = hashlib.sha256(
        json.dumps(messages, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    with httpx.Client(timeout=REQUEST_TIMEOUT_SECONDS, trust_env=False) as http_client:
        client = OpenAI(
            api_key=_api_key,
            base_url=_base_url,
            timeout=REQUEST_TIMEOUT_SECONDS,
            max_retries=MAX_RETRIES,
            http_client=http_client,
        )
        try:
            while n > 0:
                count = min(n, 20)
                n -= count
                request_body = {
                    "model": MODEL_NAME,
                    "messages": messages,
                    "max_tokens": max_tokens,
                    "n": count,
                    "stop": stop,
                    "reasoning_effort": REASONING_EFFORT,
                    "thinking": THINKING,
                    "request_timeout_seconds": REQUEST_TIMEOUT_SECONDS,
                    "automatic_retries": MAX_RETRIES,
                    "prompt_sha256": prompt_sha256,
                    "prompt_layout": os.getenv("EXPERIMENT_PROMPT_LAYOUT", "baseline"),
                }
                call_id = uuid.uuid4().hex
                request_attempt_count += 1
                started = time.monotonic()
                _append_request_log({
                    **_request_context(),
                    "event": "request",
                    "call_id": call_id,
                    "timestamp_utc": datetime.now(timezone.utc).isoformat(),
                    "model": MODEL_NAME,
                    "request": request_body,
                })
                raw_response_json = None
                try:
                    raw_response = client.chat.completions.with_raw_response.create(
                        model=MODEL_NAME,
                        messages=messages,
                        max_tokens=max_tokens,
                        n=count,
                        stop=stop,
                        extra_body={
                            "reasoning_effort": REASONING_EFFORT,
                            "thinking": THINKING,
                        },
                    )
                    raw_response_json = raw_response.http_response.json()
                    response = raw_response.parse()
                except Exception as error:
                    _record_error(call_id, request_body, started, error, raw_response=raw_response_json)
                    raise

                batch_outputs = [choice.message.content or "" for choice in response.choices]
                outputs.extend(batch_outputs)
                raw_usage = raw_response_json.get("usage") or {}
                hit = _usage_int(raw_usage, "prompt_cache_hit_tokens")
                miss = _usage_int(raw_usage, "prompt_cache_miss_tokens")
                response_usage = response.usage
                prompt_count = getattr(response_usage, "prompt_tokens", None)
                completion_count = getattr(response_usage, "completion_tokens", None)
                prompt_count = prompt_count if isinstance(prompt_count, int) else None
                completion_count = completion_count if isinstance(completion_count, int) else None
                if prompt_count is not None:
                    prompt_tokens += prompt_count
                if prompt_count is None or completion_count is None or hit is None or miss is None:
                    usage_missing_count += 1
                raw_usage_all = raw_response_json.get("usage") or {}
                expected_usage = ("prompt_tokens", "completion_tokens", "prompt_cache_hit_tokens", "prompt_cache_miss_tokens")
                if any(key in raw_usage_all and _usage_int(raw_usage_all, key) is None for key in expected_usage):
                    usage_invalid_count += 1
                if completion_count is not None:
                    completion_tokens += completion_count
                if hit is not None:
                    cache_hit_tokens += hit
                if miss is not None:
                    cache_miss_tokens += miss

                # Preserve the full provider JSON response (including any
                # reasoning_content) but never log headers or API credentials.
                _append_request_log({
                    **_request_context(),
                    "event": "response",
                    "call_id": call_id,
                    "timestamp_utc": datetime.now(timezone.utc).isoformat(),
                    "status": "complete",
                    "model": MODEL_NAME,
                    "request_id": response.id,
                    "request": request_body,
                    "latency_seconds": round(time.monotonic() - started, 6),
                    "usage": {
                        "prompt_tokens": prompt_count,
                        "completion_tokens": completion_count,
                        "prompt_cache_hit_tokens": hit,
                        "prompt_cache_miss_tokens": miss,
                    },
                    "response_content": batch_outputs,
                    "raw_response": raw_response_json,
                })
                raw_choices = raw_response_json.get("choices") or []
                if len(raw_choices) != count or any(choice.get("finish_reason") != "stop" for choice in raw_choices):
                    raise RuntimeError("INCOMPLETE_MODEL_RESPONSE_FINISH_REASON")
        finally:
            client.close()
    return outputs


def gpt_usage(backend=None):
    return {
        "completion_tokens": completion_tokens,
        "prompt_tokens": prompt_tokens,
        "prompt_cache_hit_tokens": cache_hit_tokens,
        "prompt_cache_miss_tokens": cache_miss_tokens,
        "request_attempt_count": request_attempt_count,
        "usage_missing_count": usage_missing_count,
        "usage_invalid_count": usage_invalid_count,
    }
