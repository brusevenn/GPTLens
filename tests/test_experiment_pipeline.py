import importlib.util
import json
import os
import sys
import types
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "src"
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
            "choices": [{"finish_reason": "stop", "message": {"content": '{"output_list": []}', "reasoning_content": "test reasoning"}}],
        })

    def parse(self):
        return SimpleNamespace(
            id="cmpl-test-1",
            choices=[SimpleNamespace(message=SimpleNamespace(content='{"output_list": []}'))],
            usage=SimpleNamespace(prompt_tokens=100, completion_tokens=9),
        )


class FakeHTTPClient:
    def close(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        self.close()


class FakeOpenAI:
    instances = []

    def __init__(self, **kwargs):
        self.kwargs = kwargs
        self.request = None
        endpoint = SimpleNamespace(create=self.create)
        endpoint.with_raw_response = endpoint
        self.chat = SimpleNamespace(completions=endpoint)
        self.__class__.instances.append(self)

    def create(self, **kwargs):
        self.request = kwargs
        return FakeRawResponse()

    def close(self):
        pass


class ProtocolTests(unittest.TestCase):
    def test_deepseek_request_uses_fixed_protocol_and_logs_cache_without_secrets(self):
        import model

        fake_http_client = FakeHTTPClient()
        with TemporaryDirectory() as tmp:
            log_path = Path(tmp) / "requests.jsonl"
            with patch.dict(os.environ, {"TOOL_REQUEST_LOG_FILE": str(log_path)}), \
                 patch.object(model, "OpenAI", FakeOpenAI), \
                 patch.object(model.httpx, "Client", return_value=fake_http_client) as client_factory, \
                 patch.object(model, "_api_key", "sentinel-not-a-real-key"), \
                 patch.object(model, "_base_url", "https://api.example.invalid/v1"):
                outputs = model.gpt("unique synthetic prompt", model="gpt-4")

            client = FakeOpenAI.instances[-1]
            request = client.request
            self.assertEqual(outputs, ['{"output_list": []}'])
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

            records = [json.loads(line) for line in log_path.read_text().splitlines()]
            self.assertEqual([row["event"] for row in records], ["request", "response"])
            self.assertEqual(records[0]["call_id"], records[1]["call_id"])
            record = records[1]
            self.assertEqual(record["request_id"], "cmpl-test-1")
            self.assertEqual(record["usage"]["prompt_cache_hit_tokens"], 96)
            self.assertEqual(record["usage"]["prompt_cache_miss_tokens"], 4)
            self.assertEqual(record["response_content"], ['{"output_list": []}'])
            self.assertEqual(
                record["raw_response"]["choices"][0]["message"]["reasoning_content"],
                "test reasoning",
            )
            serialized = log_path.read_text()
            self.assertNotIn("sentinel-not-a-real-key", serialized)
            self.assertNotIn("Authorization", serialized)

    def test_auditor_writes_explicit_empty_result_status_for_each_input(self):
        import run_auditor

        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "input.sol"
            source.write_text("contract Input {}", encoding="utf-8")
            out = Path(tmp) / "auditor"
            args = SimpleNamespace(
                backend="gpt-4", data_dir=tmp, input_file=str(source),
                output_dir=str(out), topk=3, num_auditor=1,
            )
            with patch.object(run_auditor, "gpt", return_value=['{"output_list": []}']):
                run_auditor.run(args)
            result = out / "input.json"
            status = out / "input.status.json"
            self.assertEqual(json.loads(result.read_text()), [])
            self.assertEqual(json.loads(status.read_text())["status"], "no_findings")

    def test_auditor_api_error_is_persisted_as_error_not_empty_findings(self):
        import run_auditor

        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "input.sol"
            source.write_text("contract Input {}", encoding="utf-8")
            out = Path(tmp) / "auditor"
            args = SimpleNamespace(
                backend="gpt-4", data_dir=tmp, input_file=str(source),
                output_dir=str(out), topk=3, num_auditor=1,
            )
            with patch.object(run_auditor, "gpt", side_effect=TimeoutError("timeout")):
                with self.assertRaises(RuntimeError):
                    run_auditor.run(args)
            status = json.loads((out / "input.status.json").read_text())
            self.assertEqual(status["status"], "error")
            self.assertEqual(status["error_type"], "TimeoutError")
            self.assertFalse((out / "input.json").exists())

    def test_auditor_parse_errors_are_not_treated_as_no_findings(self):
        import run_auditor
        with self.assertRaises(ValueError):
            run_auditor.auditor_response_parse(["not-json"])
        self.assertEqual(run_auditor.auditor_response_parse(['{"output_list": []}']), [])

    def test_critic_consumes_auditor_json_and_skips_empty_findings_explicitly(self):
        import run_critic

        with TemporaryDirectory() as tmp:
            auditor_dir = Path(tmp) / "auditor"
            critic_dir = Path(tmp) / "critic"
            auditor_dir.mkdir()
            (auditor_dir / "empty.json").write_text("[]", encoding="utf-8")
            args = SimpleNamespace(
                backend="gpt-4", auditor_dir=tmp, input_dir=str(auditor_dir),
                output_dir=str(critic_dir), input_file=None, num_critic=1, shot="few",
            )
            with patch.object(run_critic, "gpt") as mock_gpt:
                run_critic.run(args)
                mock_gpt.assert_not_called()
            self.assertEqual(json.loads((critic_dir / "empty.json").read_text()), [])
            status = json.loads((critic_dir / "empty.status.json").read_text())
            self.assertEqual(status["status"], "skipped_empty_findings")

    def test_critic_consumes_nonempty_auditor_json(self):
        import run_critic

        finding = {
            "function_name": "setOwner", "code": "owner = nextOwner;",
            "vulnerability": "Access control", "reason": "synthetic",
            "file_name": "input.sol",
        }
        critic_item = {
            "function_name": "setOwner", "vulnerability": "Access control",
            "correctness": 1, "severity": 1, "profitability": 1,
        }
        with TemporaryDirectory() as tmp:
            auditor_dir = Path(tmp) / "auditor"
            critic_dir = Path(tmp) / "critic"
            auditor_dir.mkdir()
            (auditor_dir / "input.json").write_text(json.dumps([finding]), encoding="utf-8")
            args = SimpleNamespace(
                backend="gpt-4", auditor_dir=tmp, input_dir=str(auditor_dir),
                output_dir=str(critic_dir), input_file=None, num_critic=1, shot="few",
            )
            with patch.object(run_critic, "gpt", return_value=[json.dumps({"output_list": [critic_item]})]) as mock_gpt:
                run_critic.run(args)
                mock_gpt.assert_called_once()
            result = json.loads((critic_dir / "input.json").read_text())
            self.assertEqual(len(result), 1)
            self.assertEqual(result[0]["file_name"], "input.sol")
            self.assertEqual(json.loads((critic_dir / "input.status.json").read_text())["status"], "complete")


    def test_critic_rejects_mismatched_function_binding_and_invalid_scores(self):
        import run_critic

        finding = {
            "function_name": "setOwner", "code": "function setOwner() {}",
            "vulnerability": "Access control", "reason": "synthetic",
            "file_name": "input.sol",
        }
        bad_outputs = [
            {"function_name": "withdraw", "vulnerability": "Access control",
             "correctness": 8, "severity": 7, "profitability": 6},
            {"function_name": "setOwner", "vulnerability": "Access control",
             "correctness": 10, "severity": 7, "profitability": 6},
        ]
        for index, output in enumerate(bad_outputs):
            with self.subTest(index=index), TemporaryDirectory() as tmp:
                auditor_dir = Path(tmp) / "auditor"
                critic_dir = Path(tmp) / "critic"
                auditor_dir.mkdir()
                (auditor_dir / "input.json").write_text(json.dumps([finding]), encoding="utf-8")
                args = SimpleNamespace(
                    backend="gpt-4", auditor_dir=tmp, input_dir=str(auditor_dir),
                    output_dir=str(critic_dir), input_file=None, num_critic=1, shot="few",
                    case_id="case",
                )
                with patch.object(run_critic, "gpt", return_value=[json.dumps({"output_list": [output]})]):
                    with self.assertRaises(RuntimeError):
                        run_critic.run(args)
                status = json.loads((critic_dir / "input.status.json").read_text(encoding="utf-8"))
                self.assertEqual(status["status"], "error")
                self.assertFalse((critic_dir / "input.json").exists())


if __name__ == "__main__":
    unittest.main()
