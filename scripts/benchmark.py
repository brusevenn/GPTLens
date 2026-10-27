#!/usr/bin/env python3
"""Run one GPTLens ACToolBench project group, preserving native pipeline and per-file evidence.

One project group may correspond to several dataset case IDs. Each unique Solidity file
is passed once through GPTLens Auditor -> Critic -> native Ranker. Case mappings are
recorded in project-result.json; labels are never loaded.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import re
from pathlib import Path
import signal
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from pre_process import remove_annotations_from_text
import run_auditor
import run_critic
import run_rank


DATASET = "ACToolBench154"
EXPECTED_CASES = 154
EXPECTED_PROJECTS = 121
EXPECTED_INPUT_FILES = 694
PROTOCOL = {
    "provider": "deepseek",
    "model": "deepseek-flash",
    "reasoning_effort": "high",
    "thinking": {"type": "enabled"},
    "max_tokens": 65536,
    "request_timeout_seconds": 300,
    "automatic_retries": 0,
    "direct_no_env_proxy": True,
    "global_concurrency": 2,
    "project_timeout_seconds": 1200,
    "temperature": None,
    "top_p": None,
}
_BLOCKED_LABEL_KEYS = {
    "label", "labels", "vulnerability_type", "vulnerable_function",
    "ground_truth", "ground_truth_status", "root_cause", "adjudication",
    "reference_label", "expected_result",
}


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _atomic_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    with temp.open("rb") as stream:
        os.fsync(stream.fileno())
    os.replace(temp, path)


def _keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield str(key).lower()
            yield from _keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _keys(child)


def _prompt_identity(prompt_layout: str) -> dict:
    import prompts
    parts = {
        "auditor_prompt": prompts.auditor_prompt,
        "auditor_format_constraint": prompts.auditor_format_constrain,
        "auditor_topk_prefix": prompts.topk_prompt1,
        "auditor_topk_suffix": prompts.topk_prompt2,
        "critic_zero": prompts.critic_zero_shot_prompt,
        "critic_few": prompts.critic_few_shot_prompt,
        "critic_format_constraint": prompts.critic_format_constrain,
        "layout": prompt_layout,
        "protocol": "GPTLENS_NATIVE_AUDITOR_CRITIC_RANKER_V1",
    }
    canonical = json.dumps(parts, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"version": "GPTLENS_NATIVE_AUDITOR_CRITIC_RANKER_V1", "layout": prompt_layout,
            "sha256": hashlib.sha256(canonical).hexdigest()}


def load_project_plan(project_id: str, index_path: Path | None = None) -> dict:
    index_path = index_path or ROOT / "datasets/actoolbench-cleaned-154/tools/gptlens/input-index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    if index.get("schema") != "actoolbench-tool-input-index-v1" or index.get("tool") != "GPTLens":
        raise ValueError("Unexpected GPTLens input-index schema/tool")
    if index.get("case_count") != EXPECTED_CASES or len(index.get("cases", [])) != EXPECTED_CASES:
        raise ValueError("ACToolBench case count is not 154")
    if index.get("project_count") != EXPECTED_PROJECTS or len(index.get("projects", [])) != EXPECTED_PROJECTS:
        raise ValueError("ACToolBench project count is not 121")
    if index.get("unique_solidity_file_count") != EXPECTED_INPUT_FILES or len(index.get("files", [])) != EXPECTED_INPUT_FILES:
        raise ValueError("GPTLens source input count is not 694")
    if index.get("case_labels_included") is not False:
        raise ValueError("Refusing GPTLens input index that does not explicitly exclude labels")
    if _BLOCKED_LABEL_KEYS.intersection(_keys(index.get("cases", []))):
        raise ValueError("Label-like fields found in GPTLens input case records")

    project_rows = [row for row in index["projects"] if row.get("project_id") == project_id]
    if len(project_rows) != 1:
        raise ValueError(f"Expected one project_id in input index, found {len(project_rows)}")
    cases = [row for row in index["cases"] if row.get("project_id") == project_id]
    if not cases:
        raise ValueError("Project has no mapped dataset cases")
    files = [row for row in index["files"] if row.get("project_id") == project_id]
    if not files or len(files) != project_rows[0].get("source_file_count"):
        raise ValueError("Project source-file inventory does not match the index")
    tool_paths = [row.get("tool_input_path") for row in files]
    if len(tool_paths) != len(set(tool_paths)):
        raise ValueError("Duplicate tool input path within project")
    if len({Path(path).stem for path in tool_paths}) != len(tool_paths):
        raise ValueError("GPTLens output stem collision within project")

    for row in files:
        tool_path = ROOT / row["tool_input_path"]
        source_path = ROOT / row["source_path"]
        expected = row["sha256"]
        if not tool_path.is_file() or not source_path.is_file():
            raise FileNotFoundError(f"Indexed source input missing: {row['tool_input_path']}")
        if _sha256_file(tool_path) != expected or _sha256_file(source_path) != expected:
            raise ValueError(f"Indexed source hash mismatch: {row['tool_input_path']}")

    hash_manifest_path = ROOT / "datasets/actoolbench-cleaned-154/file-hashes.jsonl"
    hash_rows = [json.loads(line) for line in hash_manifest_path.read_text(encoding="utf-8").splitlines() if line]
    config_by_path = {
        row["repo_path"]: row for row in hash_rows
        if row.get("project_id") == project_id and row.get("role") == "compile_config"
    }
    config_paths = sorted(set(project_rows[0].get("compile_config_paths", [])))
    if not config_paths:
        raise ValueError("Project has no indexed compile configuration")
    config_records = []
    for relative in config_paths:
        row = config_by_path.get(relative)
        path = ROOT / relative
        if row is None or not path.is_file() or _sha256_file(path) != row.get("sha256"):
            raise ValueError(f"Compile configuration missing/hash mismatch: {relative}")
        config_records.append({"path": relative, "sha256": row["sha256"], "bytes": row["bytes"]})

    return {
        "dataset_id": index["dataset_id"],
        "project_id": project_id,
        "project": project_rows[0],
        "case_ids": [row["case_id"] for row in cases],
        "files": files,
        "index_path": index_path,
        "index_sha256": _sha256_file(index_path),
        "hash_manifest_sha256": _sha256_file(hash_manifest_path),
        "compile_configs": config_records,
    }


def _safe_traceback() -> str:
    text = traceback.format_exc()
    text = text.replace(str(ROOT), "$REPO")
    text = text.replace("/home/shanzy", "$HOME")
    text = re.sub(r"(?i)sk-[A-Za-z0-9_-]{12,}", "[REDACTED]", text)
    text = re.sub(r"(?i)(DEEPSEEK_API_KEY|OPENAI_API_KEY)(\s*[=:]\s*)[^\s]+",
                  r"\1\2[REDACTED]", text)
    return text


def _write_error(output: Path, item: dict, stage: str, error_type: str, details: str | None = None) -> str:
    digest = hashlib.sha256(item["tool_input_path"].encode("utf-8")).hexdigest()[:12]
    path = output / "errors" / f"{digest}-{stage}.txt"
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    body = f"stage={stage}\ninput_id={item['tool_input_path']}\nerror_type={error_type}\n"
    if details:
        body += details.rstrip() + "\n"
    temp.write_text(body, encoding="utf-8")
    os.replace(temp, path)
    return str(path.relative_to(output))


def _status(path: Path) -> dict:
    if not path.is_file():
        return {"status": "missing"}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {"status": "invalid_status_record"}
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return {"status": "invalid_status_record"}


def _file_record(item: dict) -> dict:
    return {
        "input_id": item["tool_input_path"],
        "source_path": item["source_path"],
        "source_sha256": item["sha256"],
        "source_bytes": item["bytes"],
        "status": "PENDING",
        "auditor_status": "NOT_RUN",
        "critic_status": "NOT_RUN",
        "ranker_status": "NOT_RUN",
    }


def _global_provider_stop_path() -> Path | None:
    value = os.environ.get("EXPERIMENT_GLOBAL_STOP_FILE")
    return Path(value) if value else None


def _mark_global_provider_stop() -> None:
    path = _global_provider_stop_path()
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        temp = path.with_name(path.name + f".tmp-{os.getpid()}")
        temp.write_text(json.dumps({"status": "STOPPED_AUTH_OR_PAYMENT_ERROR", "tool": "GPTLens"}) + "\n")
        os.replace(temp, path)


def _has_global_auth_error(record: dict) -> bool:
    for stage_key in ("auditor_status", "critic_status"):
        status = record.get(stage_key, {})
        status = status if isinstance(status, dict) else {"status": status}
        if status.get("http_status") in (401, 402, 403):
            return True
        if status.get("error_type") in ("AuthenticationError", "PermissionDeniedError"):
            return True
        if status.get("provider_error_code") in ("insufficient_quota", "billing_hard_limit_reached", "payment_required"):
            return True
    return False


def run_project(project_id: str, output: Path, prompt_layout: str = "baseline",
                timeout_seconds: int = 1200, index_path: Path | None = None) -> tuple[int, dict]:
    if prompt_layout not in ("baseline", "prefix_stable", "prefix_stable_v2"):
        raise ValueError("prompt_layout must be baseline or prefix_stable")
    if timeout_seconds <= 0:
        raise ValueError("timeout_seconds must be positive")
    if timeout_seconds > 1200:
        raise ValueError("GPTLens comparison case timeout must not exceed 1200 seconds")
    output = output.resolve()
    result_path = output / "project-result.json"
    if result_path.exists():
        raise FileExistsError("Refusing to overwrite an existing project result; no samples are replayed")
    for name in ("normalized", "auditor", "critic", "ranker"):
        existing = output / name
        if existing.exists() and any(existing.iterdir()):
            raise FileExistsError(f"Refusing non-empty existing {name} output; no samples are replayed")

    plan = load_project_plan(project_id, index_path)
    output.mkdir(parents=True, exist_ok=True)
    dirs = {name: output / name for name in ("normalized", "auditor", "critic", "ranker")}
    for path in dirs.values():
        path.mkdir(parents=True, exist_ok=True)

    files = [_file_record(item) for item in plan["files"]]
    now = datetime.now(timezone.utc).isoformat()
    meta = {
        "schema": "GPTLENS_PROJECT_RESULT_V1",
        "tool": "GPTLens",
        "dataset": DATASET,
        "dataset_id": plan["dataset_id"],
        "project_id": project_id,
        "case_ids": plan["case_ids"],
        "project_source_file_count": len(files),
        "source_index_sha256": plan["index_sha256"],
        "source_hash_manifest_sha256": plan["hash_manifest_sha256"],
        "source_file_hashes_verified": True,
        "compile_configs_verified": plan["compile_configs"],
        "ground_truth_read": False,
        "prompt_identity": _prompt_identity(prompt_layout),
        "model_configuration": PROTOCOL,
        "started_utc": now,
        "updated_utc": now,
        "status": "RUNNING",
        "execution_status": "RUNNING",
        "file_results": files,
    }
    current_file = None
    current_stage = None

    def save():
        meta["updated_utc"] = datetime.now(timezone.utc).isoformat()
        _atomic_json(result_path, meta)

    def interrupted(signum, _frame):
        if current_file is not None:
            current_file["status"] = "TIMEOUT_UNKNOWN" if signum == signal.SIGALRM else "INTERRUPTED_UNKNOWN"
            current_file["active_stage"] = current_stage
            current_file["error_type"] = "CaseTimeout" if signum == signal.SIGALRM else "Interrupted"
        for row in files:
            if row["status"] == "PENDING":
                row["status"] = "NOT_RUN_CASE_TIMEOUT" if signum == signal.SIGALRM else "NOT_RUN_AFTER_INTERRUPT"
        meta["status"] = "TIMEOUT" if signum == signal.SIGALRM else "INTERRUPTED"
        meta["execution_status"] = meta["status"]
        meta["ended_utc"] = datetime.now(timezone.utc).isoformat()
        save()
        raise SystemExit(4 if signum == signal.SIGALRM else 130)

    old_handlers = {}
    if hasattr(signal, "SIGALRM"):
        old_handlers[signal.SIGALRM] = signal.signal(signal.SIGALRM, interrupted)
        signal.setitimer(signal.ITIMER_REAL, timeout_seconds)
    for sig in (signal.SIGTERM, signal.SIGINT):
        old_handlers[sig] = signal.signal(sig, interrupted)

    request_log_before = os.environ.get("TOOL_REQUEST_LOG_FILE")
    try:
        if request_log_before:
            request_log = Path(request_log_before)
            request_log_label = request_log.name
        else:
            request_log = output / "requests.jsonl"
            request_log_label = "requests.jsonl"
        os.environ["TOOL_REQUEST_LOG_FILE"] = str(request_log)
        os.environ["EXPERIMENT_TOOL"] = "GPTLens"
        os.environ["EXPERIMENT_DATASET"] = DATASET
        os.environ["EXPERIMENT_PROJECT_ID"] = project_id
        os.environ["EXPERIMENT_CASE_IDS"] = ",".join(plan["case_ids"])
        os.environ["EXPERIMENT_CASE_ID"] = plan["case_ids"][0] if len(plan["case_ids"]) == 1 else ""
        os.environ["EXPERIMENT_PROMPT_LAYOUT"] = prompt_layout

        for row, item in zip(files, plan["files"]):
            global_stop = _global_provider_stop_path()
            if global_stop is not None and global_stop.exists():
                row.update(status="NOT_RUN_GLOBAL_PROVIDER_STOP", error_type="GlobalProviderStop")
                row["auditor_status"] = {"status": "NOT_RUN_GLOBAL_PROVIDER_STOP"}
                row["critic_status"] = {"status": "NOT_RUN_GLOBAL_PROVIDER_STOP"}
                row["ranker_status"] = {"status": "NOT_RUN_GLOBAL_PROVIDER_STOP"}
                save()
                continue
            current_file = row
            current_stage = "preprocess"
            row["status"] = "RUNNING"
            save()
            source = ROOT / item["tool_input_path"]
            normalized = dirs["normalized"] / source.name
            try:
                normalized_text = remove_annotations_from_text(source.read_text(encoding="utf-8"))
                normalized.write_text(normalized_text, encoding="utf-8")
                row["normalized_sha256"] = _sha256_file(normalized)
            except Exception as error:
                row.update(status="INPUT_ERROR", error_type=type(error).__name__)
                row["error_log"] = _write_error(output, item, "preprocess", type(error).__name__, _safe_traceback())
                save()
                continue

            stem = source.stem
            auditor_file = dirs["auditor"] / f"{stem}.json"
            auditor_status_path = dirs["auditor"] / f"{stem}.status.json"
            os.environ["EXPERIMENT_INPUT_ID"] = item["tool_input_path"]

            current_stage = "auditor"
            os.environ["EXPERIMENT_STAGE"] = current_stage
            auditor_args = argparse.Namespace(
                backend="gpt-4", data_dir=str(normalized.parent), input_file=str(normalized),
                output_dir=str(dirs["auditor"]), case_id=None, topk=3, num_auditor=1,
                prompt_layout=prompt_layout,
            )
            try:
                run_auditor.run(auditor_args)
            except Exception as error:
                row["auditor_error_type"] = type(error).__name__
                row["error_log"] = _write_error(output, item, "auditor", type(error).__name__, _safe_traceback())
            auditor_status = _status(auditor_status_path)
            row["auditor_status"] = auditor_status
            if auditor_status.get("status") not in ("complete", "no_findings"):
                row.update(status="AUDITOR_ERROR", error_type=auditor_status.get("error_type", "AuditorError"))
                row["critic_status"] = {"status": "NOT_RUN_PREDECESSOR_ERROR"}
                row["ranker_status"] = {"status": "NOT_RUN_PREDECESSOR_ERROR"}
                save()
                if _has_global_auth_error(row):
                    meta["status"] = "STOPPED_AUTH_OR_PAYMENT_ERROR"
                    meta["execution_status"] = meta["status"]
                    _mark_global_provider_stop()
                    for pending in files:
                        if pending["status"] == "PENDING":
                            pending["status"] = "NOT_RUN_GLOBAL_PROVIDER_STOP"
                    break
                continue

            current_stage = "critic"
            os.environ["EXPERIMENT_STAGE"] = current_stage
            critic_file = dirs["critic"] / auditor_file.name
            critic_status_path = dirs["critic"] / f"{stem}.status.json"
            critic_args = argparse.Namespace(
                backend="gpt-4", input_dir=None, input_file=str(auditor_file),
                output_dir=str(dirs["critic"]), case_id=None, auditor_dir="",
                num_critic=1, shot="few", prompt_layout="prefix_stable" if prompt_layout=="prefix_stable_v2" else prompt_layout,
            )
            global_stop = _global_provider_stop_path()
            if global_stop is not None and global_stop.exists():
                row.update(status="INCOMPLETE_GLOBAL_PROVIDER_STOP", error_type="GlobalProviderStop")
                row["critic_status"] = {"status": "NOT_RUN_GLOBAL_PROVIDER_STOP"}
                row["ranker_status"] = {"status": "NOT_RUN_GLOBAL_PROVIDER_STOP"}
                save()
                continue
            try:
                run_critic.run(critic_args)
            except Exception as error:
                row["critic_error_type"] = type(error).__name__
                row["error_log"] = _write_error(output, item, "critic", type(error).__name__, _safe_traceback())
            critic_status = _status(critic_status_path)
            row["critic_status"] = critic_status
            if critic_status.get("status") not in ("complete", "skipped_empty_findings"):
                row.update(status="CRITIC_ERROR", error_type=critic_status.get("error_type", "CriticError"))
                row["ranker_status"] = {"status": "NOT_RUN_PREDECESSOR_ERROR"}
                save()
                if _has_global_auth_error(row):
                    meta["status"] = "STOPPED_AUTH_OR_PAYMENT_ERROR"
                    meta["execution_status"] = meta["status"]
                    _mark_global_provider_stop()
                    for pending in files:
                        if pending["status"] == "PENDING":
                            pending["status"] = "NOT_RUN_GLOBAL_PROVIDER_STOP"
                    break
                continue

            current_stage = "ranker"
            try:
                critic_data = json.loads(critic_file.read_text(encoding="utf-8"))
                ranked = run_rank.score_findings(critic_data, "default")
                rank_path = dirs["ranker"] / auditor_file.name
                _atomic_json(rank_path, ranked)
                row["ranker_status"] = {"status": "complete", "finding_count": len(ranked)}
                row["ranker_output"] = str(rank_path.relative_to(output))
                row["status"] = "NO_FINDINGS" if auditor_status["status"] == "no_findings" else "COMPLETED"
            except Exception as error:
                row.update(status="RANKER_ERROR", error_type=type(error).__name__)
                row["ranker_status"] = {"status": "error", "error_type": type(error).__name__}
                row["error_log"] = _write_error(output, item, "ranker", type(error).__name__, _safe_traceback())
            save()

        if meta["status"] == "RUNNING":
            meta["execution_status"] = "PROJECT_COMPLETE" if all(
                row["status"] in ("COMPLETED", "NO_FINDINGS") for row in files
            ) else "PROJECT_WITH_FAILURES"
            meta["status"] = "COMPLETE" if meta["execution_status"] == "PROJECT_COMPLETE" else "WITH_FAILURES"
        meta["ended_utc"] = datetime.now(timezone.utc).isoformat()
        meta["request_log"] = request_log_label
        meta["usage"] = __import__("model").gpt_usage()
        save()
        exit_code = 0 if meta["status"] == "COMPLETE" else (3 if meta["status"] == "STOPPED_AUTH_OR_PAYMENT_ERROR" else 2)
        print(json.dumps({"project_id": project_id, "case_ids": plan["case_ids"], "status": meta["status"],
                          "execution_status": meta["execution_status"], "file_count": len(files),
                          "failed_files": sum(row["status"] not in ("COMPLETED", "NO_FINDINGS") for row in files),
                          "request_log": request_log_label}))
        return exit_code, meta
    finally:
        if hasattr(signal, "ITIMER_REAL"):
            signal.setitimer(signal.ITIMER_REAL, 0)
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
        if request_log_before:
            os.environ["TOOL_REQUEST_LOG_FILE"] = request_log_before
        else:
            os.environ.pop("TOOL_REQUEST_LOG_FILE", None)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--prompt-layout", choices=("baseline", "prefix_stable", "prefix_stable_v2"), default="baseline")
    parser.add_argument("--timeout-seconds", type=int, default=1200)
    parser.add_argument("--input-index", default=None)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    index_path = Path(args.input_index).resolve() if args.input_index else None
    exit_code, _ = run_project(args.project_id, Path(args.output), args.prompt_layout,
                               args.timeout_seconds, index_path)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
