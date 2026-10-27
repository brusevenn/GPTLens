import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "src"))

import benchmark
import run_auditor
import run_critic
import run_rank
import prompts
from pre_process import remove_annotations_from_text


class GPTLensProjectHarnessTests(unittest.TestCase):
    def test_preprocessor_keeps_comment_markers_inside_strings(self):
        source = 'contract C { string s = "https://example.invalid/a//b/*c*/"; /* remove */ function f() public {} // tail\\n}'
        result = remove_annotations_from_text(source)
        self.assertIn('"https://example.invalid/a//b/*c*/"', result)
        self.assertNotIn("remove", result)
        self.assertNotIn("tail", result)

    def test_index_has_154_cases_694_unique_files_and_label_free_project_map(self):
        index = json.loads((ROOT / "datasets/actoolbench-cleaned-154/tools/gptlens/input-index.json").read_text())
        self.assertEqual(index["case_count"], 154)
        self.assertEqual(len(index["cases"]), 154)
        self.assertEqual(index["unique_solidity_file_count"], 694)
        self.assertEqual(len(index["files"]), 694)
        self.assertEqual(index["project_count"], 121)
        self.assertFalse(index["case_labels_included"])
        self.assertFalse(benchmark._BLOCKED_LABEL_KEYS.intersection(benchmark._keys(index["cases"])))
        project = next(row for row in index["projects"] if row["source_file_count"] == 1)
        plan = benchmark.load_project_plan(project["project_id"])
        self.assertEqual(len(plan["files"]), 1)
        self.assertGreaterEqual(len(plan["case_ids"]), 1)
        self.assertTrue(plan["files"][0]["sha256"])

    def test_prompt_layouts_keep_native_words_and_only_reorder_fixed_suffix(self):
        code = "contract Synthetic { function f() public {} }"
        baseline = run_auditor.prompt_wrap(
            prompts.auditor_prompt, prompts.auditor_format_constrain, code, 3, "baseline"
        )
        stable = run_auditor.prompt_wrap(
            prompts.auditor_prompt, prompts.auditor_format_constrain, code, 3, "prefix_stable"
        )
        self.assertEqual(baseline.count(code), 1)
        self.assertEqual(stable.count(code), 1)
        self.assertLess(baseline.index(code), baseline.index(prompts.auditor_format_constrain))
        self.assertLess(stable.index(prompts.auditor_format_constrain), stable.index(code))
        finding = {"function_name": "f", "code": "function f() public {}", "vulnerability": "x", "reason": "y"}
        critic_base = run_critic.critic_prompt_wrap([finding], prompts.critic_few_shot_prompt, "baseline")
        critic_stable = run_critic.critic_prompt_wrap([finding], prompts.critic_few_shot_prompt, "prefix_stable")
        self.assertEqual(critic_base.count(finding["code"]), 1)
        self.assertEqual(critic_stable.count(finding["code"]), 1)
        self.assertLess(critic_base.index(finding["code"]), critic_base.index(prompts.critic_format_constrain))
        self.assertLess(critic_stable.index(prompts.critic_format_constrain), critic_stable.index(finding["code"]))

    def test_project_executes_native_auditor_critic_ranker_and_maps_case_ids(self):
        index = json.loads((ROOT / "datasets/actoolbench-cleaned-154/tools/gptlens/input-index.json").read_text())
        project = next(row for row in index["projects"] if row["source_file_count"] == 1)
        finding = {
            "function_name": "setOwner",
            "code": "function setOwner(address next) public { owner = next; }",
            "vulnerability": "Access control",
            "reason": "Synthetic fixture only",
        }

        def fake_auditor(args):
            stem = Path(args.input_file).stem
            run_auditor._write_json(Path(args.output_dir) / f"{stem}.json", [finding])
            run_auditor._write_json(Path(args.output_dir) / f"{stem}.status.json", {
                "stage": "auditor", "status": "complete", "finding_count": 1,
            })

        def fake_critic(args):
            stem = Path(args.input_file).stem
            critic = [{
                "function_name": "setOwner", "vulnerability": "Access control",
                "criticism": "Synthetic fixture", "correctness": 8, "severity": 7, "profitability": 6,
            }]
            run_critic._write_json(Path(args.output_dir) / f"{stem}.json", critic)
            run_critic._write_json(Path(args.output_dir) / f"{stem}.status.json", {
                "stage": "critic", "status": "complete", "finding_count": 1,
            })

        with tempfile.TemporaryDirectory() as temp, \
             patch.object(benchmark.run_auditor, "run", side_effect=fake_auditor), \
             patch.object(benchmark.run_critic, "run", side_effect=fake_critic):
            out = Path(temp) / "group"
            code, result = benchmark.run_project(project["project_id"], out, "baseline", 30)
            self.assertEqual(code, 0)
            self.assertEqual(result["status"], "COMPLETE")
            self.assertEqual(result["case_ids"], [
                row["case_id"] for row in index["cases"] if row["project_id"] == project["project_id"]
            ])
            row = result["file_results"][0]
            self.assertEqual(row["status"], "COMPLETED")
            self.assertEqual(row["auditor_status"]["status"], "complete")
            self.assertEqual(row["critic_status"]["status"], "complete")
            ranked = json.loads((out / row["ranker_output"]).read_text())
            self.assertEqual(ranked[0]["final_score"], 7.25)
            self.assertFalse((out / "requests.jsonl").exists())

    def test_auth_payment_error_halts_but_plain_rate_limit_is_recorded(self):
        self.assertTrue(benchmark._has_global_auth_error({
            "auditor_status": {"status": "error", "http_status": 429, "provider_error_code": "insufficient_quota"}
        }))
        self.assertTrue(benchmark._has_global_auth_error({
            "critic_status": {"status": "error", "http_status": 401, "error_type": "AuthenticationError"}
        }))
        self.assertFalse(benchmark._has_global_auth_error({
            "auditor_status": {"status": "error", "http_status": 429, "provider_error_code": "rate_limit_exceeded"}
        }))

    def test_no_findings_is_distinct_from_errors_and_ranker_skips_status_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            input_dir = root / "critic"
            output_dir = root / "ranked"
            input_dir.mkdir()
            (input_dir / "empty.json").write_text("[]", encoding="utf-8")
            (input_dir / "empty.status.json").write_text('{"status":"skipped_empty_findings"}', encoding="utf-8")
            args = SimpleNamespace(input_dir=str(input_dir), output_dir=str(output_dir),
                                   auditor_dir="", critic_dir="", strategy="default")
            run_rank.run(args)
            self.assertEqual(json.loads((output_dir / "empty.json").read_text()), [])
            self.assertEqual(len(list(output_dir.glob("*.json"))), 1)


if __name__ == "__main__":
    unittest.main()
