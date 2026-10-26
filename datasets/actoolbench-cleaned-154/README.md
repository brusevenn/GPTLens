# ACToolBench-cleaned-154 input package for GPTLens

This is a dataset-only adaptation for `GPTLens`. No detector/research code was changed, and no detector run, compilation, or evaluation was performed during packaging.

**Target execution platform: Ubuntu 22.04 LTS.** Run the commands below from the repository root with POSIX paths. Each project needs its own compatible Python environment; this dataset packaging did not provision or test those environments.

## Contents and provenance

- Source: [`brusevenn/smart-contract-AC-detector`](https://github.com/brusevenn/smart-contract-AC-detector), `main`, commit `99b0ad9f39ee54a7d9645ac693dd74e9d4479f7e`.
- Original full manifest: [`full/manifest.json`](full/manifest.json), copied byte-for-byte from `datasets/actoolbench-cleaned/full/manifest.json` (Git blob SHA-1 `9d4160fca8ff05ca2ab105deb8db732564829e79`, SHA-256 `9c74d0a6c647543e80cced49044639b7a8c40e241fc8593c21e574210584b5fa`).
- Source trees: `full/projects/<project_id>/source_code/`, including each project's original `config.json` and all Solidity sources/dependencies.
- Upstream license: [`UPSTREAM_LICENSE`](UPSTREAM_LICENSE).
- `file-hashes.jsonl` records each copied project/config file's repository-relative path, byte count, SHA-256, Git blob SHA-1, project ID, and role. The manifest's per-source SHA-256 values are retained unchanged.
- `tools/gptlens/input-index.json` preserves the case-to-project mapping and this tool's input paths; `source-files.txt` is the tool-ready unique Solidity input list.

Counts: **154 case records**, **121 project trees**, **694 unique Solidity files**, and **121 compile configuration files**. Multiple case records can share a project tree; the tool input list is therefore a list of unique source files, not 154 independently selected contracts. Use the case mapping in `input-index.json` when relating tool results back to records.

## Label boundary

Only source/config files are intended as detector input. The case manifest and tool index contain opaque case/project identifiers and source paths/hashes, but no per-case vulnerability type, official function name, root-cause description, or adjudication result. Do not pass `full/manifest.json`, `input-index.json`, `file-hashes.jsonl`, or `source-files.txt` into the model prompt; use only the `.sol` files through the tool's normal loader. The copied manifest has global dataset metadata but no case-level label assignments.

Source bytes, including original comments and formatting, are preserved. No evaluation-side files were copied. The upstream manifest records `source_compile_status: NOT_EXECUTED`; compiler compatibility is not implied by this package.

## GPTLens input layout and limitations

The `release` branch has no repository-level requirements file or Python version pin. Its `src/model.py` uses the legacy `openai.ChatCompletion.create` API; use an isolated environment with a compatible SDK, or make an intentional code migration separately.

- `data/ACToolBench154/` is a flat directory with 694 byte-identical Solidity input copies. Stable filenames encode the project ID and original relative source path (slashes changed to `__`); `tools/gptlens/input-index.json` maps them back to the canonical tree and hashes.
- The checked-in `src/pre_process.py` and `src/run_auditor.py` enumerate only top-level `.sol` files, so this flat adapter matches the current loader. Dependencies/configs are retained under `full/projects/`, but GPTLens audits each flat source file independently and does not resolve imports or inject sibling dependency files.
- Example from the repository root; `pre_process.py` writes to a sibling directory but does not create it, so create it first:

```sh
mkdir -p data/ACToolBench154_clean
python3 src/pre_process.py --data_dir=data/ACToolBench154
python3 src/run_auditor.py --backend=gpt-4 --temperature=0.7 --topk=3 --num_auditor=1 --data_dir=data/ACToolBench154_clean
```

The preprocessing stage removes comments and blank lines and writes derived files to `data/ACToolBench154_clean/`; those generated files are not committed. The existing GPTLens API-key configuration is not changed or included in this package.
