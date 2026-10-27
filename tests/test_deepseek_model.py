import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))


class FakeRawResponse:
    def __init__(self):
        self.http_response = SimpleNamespace(json=lambda: {
            "id": "cmpl-test-1",
            "usage": {
                "prompt_tokens": 100,
                "completion_tokens": 9,
                "prompt_cache_hit_tokens": 96,
                "prompt_cache_miss_tokens": 4,
            },
            "choices": [{"finish_reason": "stop", "message": {"content": "SMOKE_OK", "reasoning_content": "synthetic"}}],
        })

    def parse(self):
        return SimpleNamespace(
            id="cmpl-test-1",
            choices=[SimpleNamespace(message=SimpleNamespace(content="SMOKE_OK"))],
            usage=SimpleNamespace(prompt_tokens=100, completion_tokens=9),
        )


class FakeHTTPClient:
    def __init__(self):
        self.closed = False

    def close(self):
        self.closed = True

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        self.close()


class FakeOpenAI:
    instances = []
    error = None

    def __init__(self, **kwargs):
        self.kwargs = kwargs
        self.request = None
        endpoint = SimpleNamespace(create=self.create)
        endpoint.with_raw_response = endpoint
        self.chat = SimpleNamespace(completions=endpoint)
        type(self).instances.append(self)

    def create(self, **kwargs):
        self.request = kwargs
        if self.__class__.error is not None:
            raise self.__class__.error
        return FakeRawResponse()

    def close(self):
        pass


class DeepSeekModelTests(unittest.TestCase):
    def test_fixed_protocol_logs_started_and_full_response_without_secrets(self):
        import model

        FakeOpenAI.instances.clear()
        FakeOpenAI.error = None
        http_client = FakeHTTPClient()
        with tempfile.TemporaryDirectory() as tmp:
            log_path = Path(tmp) / "requests.jsonl"
            with patch.dict(os.environ, {"TOOL_REQUEST_LOG_FILE": str(log_path)}, clear=False), \
                 patch.object(model, "OpenAI", FakeOpenAI), \
                 patch.object(model.httpx, "Client", return_value=http_client) as client_factory, \
                 patch.object(model, "_api_key", "sentinel-not-a-real-key"), \
                 patch.object(model, "_base_url", "https://api.example.invalid/v1"):
                result = model.gpt("unique synthetic prompt", model="gpt-4", n=1)

            client = FakeOpenAI.instances[-1]
            request = client.request
            self.assertEqual(result, ["SMOKE_OK"])
            self.assertEqual(request["model"], "deepseek-flash")
            self.assertEqual(request["max_tokens"], 65536)
            self.assertEqual(request["extra_body"], {
                "reasoning_effort": "high",
                "thinking": {"type": "enabled"},
            })
            self.assertNotIn("temperature", request)
            self.assertNotIn("top_p", request)
            self.assertEqual(client.kwargs["timeout"], 300.0)
            self.assertEqual(client.kwargs["max_retries"], 0)
            client_factory.assert_called_once_with(timeout=300.0, trust_env=False)

            rows = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines()]
            self.assertEqual([row["event"] for row in rows], ["request", "response"])
            self.assertEqual(rows[0]["call_id"], rows[1]["call_id"])
            self.assertEqual(rows[0]["request"]["max_tokens"], 65536)
            self.assertEqual(rows[1]["request_id"], "cmpl-test-1")
            self.assertEqual(rows[1]["usage"]["prompt_cache_hit_tokens"], 96)
            self.assertEqual(rows[1]["usage"]["prompt_cache_miss_tokens"], 4)
            self.assertEqual(rows[1]["raw_response"]["choices"][0]["message"]["reasoning_content"], "synthetic")
            serialized = log_path.read_text(encoding="utf-8")
            self.assertNotIn("sentinel-not-a-real-key", serialized)
            self.assertNotIn("Authorization", serialized)
        self.assertTrue(http_client.closed)

    def test_wrong_max_tokens_is_rejected_before_request(self):
        import model
        FakeOpenAI.instances.clear()
        with patch.object(model, "_api_key", "not-a-real-key"), patch.object(model, "OpenAI", FakeOpenAI):
            with self.assertRaises(ValueError):
                model.gpt("prompt", max_tokens=4096)
            self.assertEqual(FakeOpenAI.instances, [])

    def test_transport_error_has_started_and_error_events_with_same_call_id(self):
        import model

        class SyntheticTransportError(Exception):
            status_code = 503
            request_id = "req-error-1"

        FakeOpenAI.instances.clear()
        FakeOpenAI.error = SyntheticTransportError("synthetic transport failure")
        http_client = FakeHTTPClient()
        with tempfile.TemporaryDirectory() as tmp:
            log_path = Path(tmp) / "requests.jsonl"
            with patch.dict(os.environ, {"TOOL_REQUEST_LOG_FILE": str(log_path)}, clear=False), \
                 patch.object(model, "OpenAI", FakeOpenAI), \
                 patch.object(model.httpx, "Client", return_value=http_client), \
                 patch.object(model, "_api_key", "not-a-real-key"), \
                 patch.object(model, "_base_url", "https://api.example.invalid/v1"):
                with self.assertRaises(SyntheticTransportError):
                    model.gpt("synthetic prompt")
            rows = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines()]
            self.assertEqual([row["event"] for row in rows], ["request", "error"])
            self.assertEqual(rows[0]["call_id"], rows[1]["call_id"])
            self.assertEqual(rows[1]["http_status"], 503)
        FakeOpenAI.error = None


    def test_api_error_body_is_saved_with_credentials_redacted(self):
        import model

        class ProviderError(Exception):
            status_code = 402
            request_id = "req-payment-1"
            code = "insufficient_quota"

            def __init__(self):
                super().__init__("payment required")
                self.response = SimpleNamespace(
                    json=lambda: {"error": {"code": "insufficient_quota", "message": "not-a-real-key"}},
                    text="",
                )

        FakeOpenAI.instances.clear()
        FakeOpenAI.error = ProviderError()
        with tempfile.TemporaryDirectory() as tmp:
            log_path = Path(tmp) / "requests.jsonl"
            with patch.dict(os.environ, {"TOOL_REQUEST_LOG_FILE": str(log_path)}, clear=False), \
                 patch.object(model, "OpenAI", FakeOpenAI), \
                 patch.object(model.httpx, "Client", return_value=FakeHTTPClient()), \
                 patch.object(model, "_api_key", "not-a-real-key"), \
                 patch.object(model, "_base_url", "https://api.example.invalid/v1"):
                with self.assertRaises(ProviderError):
                    model.gpt("synthetic prompt")
            rows = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(rows[1]["event"], "error")
            self.assertEqual(rows[1]["provider_error_code"], "insufficient_quota")
            self.assertEqual(rows[1]["raw_response"]["error"]["code"], "insufficient_quota")
            self.assertNotIn("not-a-real-key", log_path.read_text(encoding="utf-8"))
        FakeOpenAI.error = None



class FinishReasonTests(unittest.TestCase):
    def test_truncated_json_is_error_not_negative(self):
        import model
        original = FakeRawResponse
        class Truncated(original):
            def __init__(self):
                super().__init__()
                payload=self.http_response.json()
                payload["choices"][0]["finish_reason"]="length"
                self.http_response=SimpleNamespace(json=lambda:payload)
        with tempfile.TemporaryDirectory() as td, patch.dict(os.environ,{"TOOL_REQUEST_LOG_FILE":str(Path(td)/"requests.jsonl")}), patch.object(model,"OpenAI",FakeOpenAI), patch.object(model.httpx,"Client",return_value=FakeHTTPClient()), patch.object(model,"_api_key","test-key"):
            with patch.object(FakeOpenAI,"create",return_value=Truncated()):
                with self.assertRaisesRegex(RuntimeError,"INCOMPLETE_MODEL_RESPONSE"):
                    model.gpt("unique truncation fixture")
            rows=[json.loads(x) for x in (Path(td)/"requests.jsonl").read_text().splitlines()]
            self.assertEqual(rows[0]["event"],"request")
            self.assertEqual(rows[1]["raw_response"]["choices"][0]["finish_reason"],"length")

if __name__ == "__main__":
    unittest.main()
