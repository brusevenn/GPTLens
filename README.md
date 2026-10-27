# GPTLens

This is the repo for the code and datasets used in the paper [Large Language Model-Powered Smart Contract Vulnerability Detection: New Perspectives](https://arxiv.org/pdf/2310.01152.pdf), accepted by the IEEE Trust, Privacy and Security (TPS) conference 2023.

If you find this repository useful, please give us a star! Thank you: )

## Getting Start

### Step 0: Configure the LLM API

Install dependencies with `pip install -r requirements.txt`. Configure the repository-local `.env` with `DEEPSEEK_API_KEY`, `DEEPSEEK_BASE_URL`, `DEEPSEEK_MODEL`, and `CADG_LLM_PROVIDER=deepseek`. For the authorized comparison experiment, the API client fixes DeepSeek Flash, high reasoning effort, thinking enabled, 65,536 max tokens, 300-second request timeout, and zero automatic retries. The client does not send temperature or top_p.

### Step 1: Preprocess your own dataset

Add your dataset to the directory "GPTLens/data/xx"

remove the comments, empty lines and whitespace:

```sh
python pre_process.py --data_dir="../data/CVE" # replace CVE with your onw dataset
```

### Step 2: Run Auditor

```sh
python run_auditor.py --backend=gpt-4 --topk=3 --num_auditor=1 --data_dir="../data/CVE_clean"
```

| Parameter      | Description                                                     |
|----------------|-----------------------------------------------------------------|
| `backend`      | The version of GPT                                              |
| `topk`         | Identify k vulnerabilities per each auditor                     |
| `num_auditor`  | The total number of independent auditors.                       |
| `data_dir`     | The directory for storing preprocessed smart contracts.         |


### Step 3: Run Critic

```sh
python run_critic.py --backend=gpt-4 --auditor_dir="auditor_gpt-4_0_top3_1" --num_critic=1
```
| Parameter     | Description                                                    |
|---------------|----------------------------------------------------------------|
| `backend`     | The version of GPT                                             |
| `auditor_dir` | The directory of logs outputted by the auditor.                |
| `num_critic`  | The total number of independent critics.                       |
| `shot`        | Whether few shot or zero shot prompt.                          |


### Step 4: Run Ranker

```sh
python run_ranker.py --auditor_dir="auditor_gpt-4_0.7_top3_1" --critic_dir="critic_gpt-4_0_1" --strategy="default"
```
| Parameter     | Description                                     |
|---------------|-------------------------------------------------|
| `auditor_dir` | The directory of logs outputted by the auditor. |
| `critic_dir`  | The directory of logs outputted by the critic.  |
| `strategy`    | The strategy for generating the final score.    |


Some updates: 

**09/28**: We observed that the outputs of auditors can drift largely at different time periods. 
For instance, GPT-4 could easily identify the vulnerability in the CVE-2018-19830.sol at Sep. 16 but had difficulty detecting it at Sep. 28.
```sh
    {
        "function_name": "UBSexToken",
        "vulnerability": "Unexpected Behaviour",
        "criticism": "The reasoning is correct. The function name does not match the contract name, which means it is not the constructor and can be called by anyone at any time. This can lead to the totalSupply and owner of the token being reset, which is a serious vulnerability.",
        "correctness": 9,
        "severity": 9,
        "profitability": 9,
        "reason": "The function name does not match the contract name. This indicates that this function is intended to be the constructor, but it is not. This means that anyone can call the function at any time and reset the totalSupply and owner of the token.",
        "code": "function UBSexToken() {\n    owner = msg.sender;\n    totalSupply = 1.9 * 10 ** 26;\n    balances[owner] = totalSupply;\n}",
        "label": "Access Control",
        "file_name": "2018-19830.sol",
        "description": "The UBSexToken() function of a smart contract implementation for Business Alliance Financial Circle (BAFC), an tradable Ethereum ERC20 token, allows attackers to change the owner of the contract, because the function is public (by default) and does not check the caller's identity."
    },
```
We uploaded a set of results that we obtained on Sep. 28 using GPT-4 with 1 auditor, 1 critic and 3 outputs per each contract (see src/logs/auditor_gpt-4_0.7_top3_1/critic_gpt-4_0_1_zero_0928). 
The composite score less than 5 can be deemed as not being a vulnerability.

**10/26**: We observed that the output of critic can also be different (-.-) at different time periods, even with the same input and the temperature set to 0 (deterministic generation). This might be caused by the update of GPT-4 (?). To make scoring consistent, we added few shot examples for critic prompt. 
We uploaded a set of results of the critic with few-shot prompt that obtained on Oct. 26 using GPT-4 (see src/logs/auditor_gpt-4_0.7_top3_1/critic_gpt-4_0_1_few_1026).

This repo will be continuously updated to make generation more consistent and robust.

-----
## Citation

```
@misc{hu2023large,
      title={Large Language Model-Powered Smart Contract Vulnerability Detection: New Perspectives}, 
      author={Sihao Hu and Tiansheng Huang and Fatih İlhan and Selim Furkan Tekin and Ling Liu},
      year={2023},
      eprint={2310.01152},
      archivePrefix={arXiv},
      primaryClass={cs.CR}
}
```

-----
## Q&A

If you have any questions, you can either open an issue or contact me (sihaohu@gatech.edu), and I will reply as soon as I see the issue or email.


## ACToolBench comparison runner (Ubuntu 22.04)

The repository package at `datasets/actoolbench-cleaned-154/` contains 154 case records mapped to 121 source projects and 694 unique Solidity files. GPTLens natively audits Solidity files independently and does not resolve sibling imports; the harness therefore runs each unique source file once inside its project group, then maps its file outputs back to all associated case IDs. This is 121 project jobs, not 694 dataset cases, and it does not repeat a source call for cases sharing a project.

Do not pass the manifests, input index, hash sidecars, or evaluation labels to the model. The harness validates the index/source SHA-256 mapping and reads only indexed source files. Each project job runs the native Auditor, Critic, and default Ranker, saving stage outputs/statuses and a project-result record. Parent orchestration controls global concurrency 2 and the 1,200-second project-case deadline.

From the repository root, after the environment and repository-local `.env` are configured:

```sh
python scripts/benchmark.py --project-id <project_id> --output experiments/comparison-20261027-deepseek-high/<project_id> --prompt-layout baseline
```

`project_id` must come from `datasets/actoolbench-cleaned-154/tools/gptlens/input-index.json`. The `prefix_stable` prompt layout is an optional cache-diagnostic variant that reorders fixed native GPTLens instructions before the variable source text without changing the prompt wording or detector workflow. Never use it to rerun a project already included in a diagnostic or formal run.
