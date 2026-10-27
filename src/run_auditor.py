import argparse
import json
import os
from pathlib import Path

import model as llm_client
from model import gpt
from prompts import auditor_prompt, auditor_format_constrain
from prompts import topk_prompt1, topk_prompt2


def remove_spaces(text):
    return " ".join(text.split())


def prompt_wrap(prompt, format_constraint, code, topk, prompt_layout="baseline"):
    fixed_suffix = format_constraint + topk_prompt1.format(topk=topk) + topk_prompt2
    if prompt_layout == "baseline":
        return prompt + code + fixed_suffix
    if prompt_layout == "prefix_stable":
        return prompt + fixed_suffix + code
    raise ValueError(f"Unsupported prompt layout: {prompt_layout}")


def auditor_response_parse(auditor_outputs):
    output_list = []
    for auditor_output in auditor_outputs:
        try:
            data = json.loads(auditor_output)
        except (TypeError, json.JSONDecodeError) as error:
            raise ValueError("Auditor response was not valid JSON") from error
        if not isinstance(data, dict) or not isinstance(data.get("output_list"), list):
            raise ValueError("Auditor response is missing a list-valued output_list")
        if not all(isinstance(item, dict) for item in data["output_list"]):
            raise ValueError("Auditor output_list contains a non-object item")
        output_list.extend(data["output_list"])
    return output_list


def solve(args, code):
    auditor_input = prompt_wrap(auditor_prompt, auditor_format_constrain, code, args.topk, getattr(args, "prompt_layout", "baseline"))
    auditor_outputs = gpt(auditor_input, model=args.backend, n=args.num_auditor)
    return auditor_response_parse(auditor_outputs)


def _write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temp_path, path)


def _input_files(args):
    if args.input_file:
        return [Path(args.input_file)]
    return sorted(path for path in Path(args.data_dir).iterdir() if path.is_file() and path.suffix.lower() == ".sol")


def _output_stem(source, args, input_count):
    if args.input_file or input_count == 1:
        return source.stem
    relative = source.relative_to(Path(args.data_dir))
    import hashlib
    suffix = hashlib.sha256(relative.as_posix().encode("utf-8")).hexdigest()[:10]
    return f"{source.stem}-{suffix}"


def run(args):
    output_dir = Path(args.output_dir) if args.output_dir else Path("logs") / f"auditor_{args.backend}_top{args.topk}_{args.num_auditor}"
    inputs = _input_files(args)
    if not inputs:
        raise FileNotFoundError("No Solidity inputs found")

    errors = 0
    for source in inputs:
        stem = _output_stem(source, args, len(inputs))
        result_path = output_dir / f"{stem}.json"
        status_path = output_dir / f"{stem}.status.json"
        llm_client.last_request_error = None
        try:
            code = remove_spaces(source.read_text(encoding="utf-8"))
            findings = solve(args, code)
            for finding in findings:
                finding.setdefault("file_name", source.name)
            _write_json(result_path, findings)
            status = "complete" if findings else "no_findings"
            _write_json(status_path, {
                "case_id": getattr(args, "case_id", None),
                "input_file": source.name,
                "stage": "auditor",
                "status": status,
                "finding_count": len(findings),
            })
        except Exception as error:
            errors += 1
            _write_json(status_path, {
                "case_id": getattr(args, "case_id", None),
                "input_file": source.name,
                "stage": "auditor",
                "status": "error",
                "error_type": type(error).__name__,
                **(llm_client.last_request_error or {}),
            })
            print(json.dumps({"input_file": source.name, "status": "error", "error_type": type(error).__name__}))
            continue
        print(json.dumps({"input_file": source.name, "status": status, "finding_count": len(findings)}))

    if errors:
        raise RuntimeError(f"Auditor failed for {errors} input(s); per-input statuses were saved")


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", type=str, choices=["gpt-3.5-turbo", "gpt-4"], default="gpt-4")
    parser.add_argument("--data_dir", type=str, default="../data/CVE_clean")
    parser.add_argument("--input_file", type=str, default=None)
    parser.add_argument("--output_dir", type=str, default=None)
    parser.add_argument("--case_id", type=str, default=None)
    parser.add_argument("--topk", type=int, default=3)
    parser.add_argument("--num_auditor", type=int, default=1)
    parser.add_argument("--prompt-layout", choices=["baseline", "prefix_stable"], default="baseline")
    return parser.parse_args(argv)


if __name__ == "__main__":
    run(parse_args())
