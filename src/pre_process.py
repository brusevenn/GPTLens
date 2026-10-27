import argparse
import os
import re
from pathlib import Path


def remove_annotations_from_text(data):
    """Strip Solidity comments without interpreting comment markers inside strings."""
    result = []
    state = "code"
    quote = None
    i = 0

    while i < len(data):
        char = data[i]
        next_char = data[i + 1] if i + 1 < len(data) else ""

        if state == "code":
            if char in ("'", '"'):
                quote = char
                state = "string"
                result.append(char)
                i += 1
            elif char == "/" and next_char == "/":
                result.append(" ")
                state = "line_comment"
                i += 2
            elif char == "/" and next_char == "*":
                result.append(" ")
                state = "block_comment"
                i += 2
            else:
                result.append(char)
                i += 1
            continue

        if state == "string":
            result.append(char)
            if char == "\\" and i + 1 < len(data):
                result.append(data[i + 1])
                i += 2
                continue
            if char == quote:
                state = "code"
                quote = None
            i += 1
            continue

        if state == "line_comment":
            if char == "\n":
                result.append("\n")
                state = "code"
            i += 1
            continue

        if state == "block_comment":
            if char == "*" and next_char == "/":
                state = "code"
                i += 2
                continue
            if char == "\n":
                result.append("\n")
            i += 1

    if state == "block_comment":
        raise ValueError("Unterminated Solidity block comment")

    return re.sub(r"\n\s*\n", "\n", "".join(result)).strip()


def remove_annotations(file_path):
    path = Path(file_path)
    return remove_annotations_from_text(path.read_text(encoding="utf-8"))


def preprocess_directory(data_dir, output_dir=None):
    source_dir = Path(data_dir)
    target_dir = Path(output_dir) if output_dir else Path(f"{source_dir}_clean")
    target_dir.mkdir(parents=True, exist_ok=True)
    processed = []
    for source in sorted(source_dir.iterdir()):
        if not source.is_file() or source.suffix.lower() != ".sol":
            continue
        content = remove_annotations(source)
        target = target_dir / source.name
        temp = target.with_suffix(target.suffix + ".tmp")
        temp.write_text(content, encoding="utf-8")
        os.replace(temp, target)
        processed.append(source.name)
    return processed


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", type=str, default="../data/CVE")
    parser.add_argument("--output_dir", type=str, default=None)
    args = parser.parse_args(argv)
    output_dir = args.output_dir or f"{args.data_dir}_clean"
    files = preprocess_directory(args.data_dir, output_dir)
    print(f"Preprocessed {len(files)} Solidity files into {output_dir}")


if __name__ == "__main__":
    main()
