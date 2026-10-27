import argparse
import json
import os
from pathlib import Path


def rank_by_score(json_list):
    return sorted(json_list, key=lambda x: x["final_score"], reverse=True)


def score_findings(critic_output_list, strategy="default"):
    scored = []
    for item in critic_output_list:
        finding = dict(item)
        correctness = float(finding["correctness"])
        severity = float(finding["severity"])
        profitability = float(finding["profitability"])
        if strategy == "default":
            final_score = 0.5 * correctness + 0.25 * severity + 0.25 * profitability
        elif strategy == "customize":
            raise ValueError("GPTLens customize rank strategy is not implemented")
        else:
            raise ValueError("Please choose correct scoring strategy")
        finding["final_score"] = final_score
        scored.append(finding)
    return rank_by_score(scored)


def run(args):
    input_dir = Path(args.input_dir) if args.input_dir else Path("logs") / args.auditor_dir / args.critic_dir
    output_dir = Path(args.output_dir) if args.output_dir else input_dir / f"ranker_{args.strategy}"
    output_dir.mkdir(parents=True, exist_ok=True)
    errors = []
    ranked_count = 0
    for path in sorted(input_dir.glob("*.json")):
        # Stage status sidecars are metadata, not critic findings.
        if not path.is_file() or path.name.endswith(".status.json"):
            continue
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(value, list):
                raise ValueError("Critic output must be a JSON list")
            ranked = score_findings(value, args.strategy)
            target = output_dir / path.name
            temp = target.with_suffix(target.suffix + ".tmp")
            temp.write_text(json.dumps(ranked, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            os.replace(temp, target)
            ranked_count += 1
        except Exception as error:
            errors.append((path.name, type(error).__name__))
    if errors:
        raise RuntimeError(f"Ranker failed for {len(errors)} file(s): {errors}")
    print(json.dumps({"status": "complete", "ranked_files": ranked_count}))


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=str, choices=["CVE", "ACToolBench154"], default="CVE")
    parser.add_argument("--auditor_dir", type=str, default="auditor_gpt-4_0.7_top3_1")
    parser.add_argument("--critic_dir", type=str, default="critic_gpt-4_0_1")
    parser.add_argument("--input-dir", type=str, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    parser.add_argument("--strategy", type=str, default="default", choices=["default", "customize"])
    return parser.parse_args(argv)


if __name__ == "__main__":
    run(parse_args())
