import argparse
import json
import math
import os
from pathlib import Path

import model as llm_client
from model import gpt
from prompts import critic_zero_shot_prompt, critic_few_shot_prompt, critic_format_constrain


def critic_prompt_wrap(vul_info_list, prompt, prompt_layout="baseline"):
    vul_info_str = ""
    for vul_info in vul_info_list:
        function_name = vul_info["function_name"]
        function_code = vul_info["code"]
        vulnerability = vul_info["vulnerability"]
        reason = vul_info["reason"]
        vul_info_str += (
            "function_name: " + function_name + "\n"
            + "code: " + function_code + "\n"
            + "vulnerability: " + vulnerability + "\n"
            + "reason: " + reason + "\n------------------\n"
        )
    if prompt_layout == "baseline":
        return prompt + vul_info_str + critic_format_constrain
    if prompt_layout == "prefix_stable":
        return prompt + critic_format_constrain + vul_info_str
    raise ValueError(f"Unsupported prompt layout: {prompt_layout}")


def critic_response_parse(critic_outputs):
    output_list = []
    for critic_output in critic_outputs:
        try:
            data = json.loads(critic_output)
        except (TypeError, json.JSONDecodeError) as error:
            raise ValueError("Critic response was not valid JSON") from error
        if not isinstance(data, dict) or not isinstance(data.get("output_list"), list):
            raise ValueError("Critic response is missing a list-valued output_list")
        if not all(isinstance(item, dict) for item in data["output_list"]):
            raise ValueError("Critic output_list contains a non-object item")
        output_list.extend(data["output_list"])
    return output_list


def _write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temp_path, path)


def _input_files(args):
    if args.input_file:
        return [Path(args.input_file)]
    input_dir = Path(args.input_dir) if args.input_dir else Path("logs") / args.auditor_dir
    return sorted(
        path for path in input_dir.glob("*.json")
        if path.is_file() and not path.name.endswith(".status.json")
    )


def run(args):
    inputs = _input_files(args)
    if not inputs:
        raise FileNotFoundError("No Auditor JSON outputs found")
    output_dir = Path(args.output_dir) if args.output_dir else Path("logs") / args.auditor_dir / f"critic_{args.backend}_{args.num_critic}_{args.shot}"
    errors = 0
    for input_path in inputs:
        result_path = output_dir / input_path.name
        status_path = output_dir / f"{input_path.stem}.status.json"
        llm_client.last_request_error = None
        try:
            auditor_output_list = json.loads(input_path.read_text(encoding="utf-8"))
            if not isinstance(auditor_output_list, list):
                raise ValueError("Auditor output must be a JSON list")
            if not auditor_output_list:
                _write_json(result_path, [])
                _write_json(status_path, {
                    "case_id": getattr(args, "case_id", None),
                    "input_file": input_path.name,
                    "stage": "critic",
                    "status": "skipped_empty_findings",
                    "finding_count": 0,
                })
                print(json.dumps({"input_file": input_path.name, "status": "skipped_empty_findings"}))
                continue

            prompt = critic_zero_shot_prompt if args.shot == "zero" else critic_few_shot_prompt
            critic_input = critic_prompt_wrap(auditor_output_list, prompt, getattr(args, "prompt_layout", "baseline"))
            critic_outputs = gpt(critic_input, model=args.backend, n=args.num_critic)
            critic_bug_info_list = critic_response_parse(critic_outputs)
            if len(critic_bug_info_list) != len(auditor_output_list):
                raise ValueError("Critic output count does not match Auditor findings")

            final = []
            for auditor_info, critic_info in zip(auditor_output_list, critic_bug_info_list):
                if critic_info.get("function_name") != auditor_info.get("function_name"):
                    raise ValueError("Critic function_name does not match its Auditor finding")
                if critic_info.get("vulnerability") != auditor_info.get("vulnerability"):
                    raise ValueError("Critic vulnerability does not match its Auditor finding")
                for score_name in ("correctness", "severity", "profitability"):
                    score = critic_info.get(score_name)
                    if isinstance(score, bool) or not isinstance(score, (int, float)) or not math.isfinite(score) or not 0 <= score <= 9:
                        raise ValueError(f"Critic {score_name} must be a finite number in [0, 9]")
                final.append({
                    **critic_info,
                    "reason": auditor_info["reason"],
                    "code": auditor_info["code"],
                    "file_name": auditor_info.get("file_name", input_path.name),
                })
            _write_json(result_path, final)
            _write_json(status_path, {
                "case_id": getattr(args, "case_id", None),
                "input_file": input_path.name,
                "stage": "critic",
                "status": "complete",
                "finding_count": len(final),
            })
            print(json.dumps({"input_file": input_path.name, "status": "complete", "finding_count": len(final)}))
        except Exception as error:
            errors += 1
            _write_json(status_path, {
                "case_id": getattr(args, "case_id", None),
                "input_file": input_path.name,
                "stage": "critic",
                "status": "error",
                "error_type": type(error).__name__,
                **(llm_client.last_request_error or {}),
            })
            print(json.dumps({"input_file": input_path.name, "status": "error", "error_type": type(error).__name__}))

    if errors:
        raise RuntimeError(f"Critic failed for {errors} input(s); per-input statuses were saved")


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", type=str, choices=["gpt-3.5-turbo", "gpt-4"], default="gpt-4")
    parser.add_argument("--input_dir", type=str, default=None)
    parser.add_argument("--input_file", type=str, default=None)
    parser.add_argument("--output_dir", type=str, default=None)
    parser.add_argument("--case_id", type=str, default=None)
    parser.add_argument("--auditor_dir", type=str, default="auditor_gpt-4_top3_1")
    parser.add_argument("--num_critic", type=int, default=1)
    parser.add_argument("--shot", type=str, choices=["zero", "few"], default="few")
    parser.add_argument("--prompt-layout", choices=["baseline", "prefix_stable"], default="baseline")
    return parser.parse_args(argv)


if __name__ == "__main__":
    run(parse_args())
