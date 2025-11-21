# SRE Technical Test

Welcome to the SRE Technical Test. This repository contains a basic "starter kit" for a service that provides information about Large Language Models (LLMs).

## Context
We have a simple serverless application that retrieves LLM versions and scores from a database. The current implementation is a "Proof of Concept" (PoC) and is not yet production-ready.

## The Challenge
Your task is to assume the role of an SRE joining the team. You have inherited this codebase and need to improve it.

**Scenario:**
The Product team wants to scale this service to support 1000s of concurrent users. They are concerned about:
1. **Cold Start Times**: The API can be slow on the first request.
2. **Reliability & Scaling**: Is the current architecture robust enough?
3. **Costs**: As traffic grows, how do we keep costs manageable?

### Your Objectives
1. **Analyze**: Review the current setup (Terraform + Lambda + DynamoDB).
2. **Extend/Improve**:
    - Propose and/or implement changes to improve **cold start times**.
    - Propose and/or implement changes to make this **production-ready** (scaling to 1000s of users).
    - Consider **observability**, **security**, and **cost optimization**.
3. **Document**: Your thought process is more important than a complete solution.

## Key Points & Guidelines
- **Time Limit**: Spend **1-2 hours max**. We value your time. Evidence of spending significantly more time may actually work against you (we want to see how you prioritize).
- **LLM Use**: You are **encouraged** to use LLMs (ChatGPT, Claude, Copilot, etc.) to help you. We want to see how you leverage tools.
- **Approach over Completeness**: We are not testing for a finished product. We are testing your approach to problem-solving. Incomplete code with a clear explanation of what you *would* do is better than perfect code with no context.
- **Deliverable**:
    - Please capture your work as a git repository.
    - Submit a **git bundle** via email complete with commit history.
    - `git bundle create sre-test.bundle --all`
    - **Instructions**: Update this README or add a `SOLUTION.md` explaining how to run your improvements (even if they are theoretical or partially implemented).

## Current Architecture
- **Infrastructure**: Terraform (AWS Provider).
- **Compute**: AWS Lambda (Python).
- **Database**: Amazon DynamoDB.
- **API**: API Gateway (HTTP API).

## Setup Instructions

### Prerequisites
- AWS CLI (configured with credentials)
- Terraform (v1.0+)
- Python 3.9+

### 1. Deploy Infrastructure
Initialize and apply the Terraform configuration:
```bash
cd terraform
terraform init
terraform apply
```
Note the `api_url` output.

### 2. Seed Data
Populate the DynamoDB table with sample data:
```bash
cd ../scripts
pip install boto3
python seed_data.py
```

### 3. Test
Call the API endpoint:
```bash
curl <api_url>/llms
```

## Questions?
During the interview, we will use your submission as a talking point to discuss your design choices, trade-offs, and how you would handle real-world production scenarios.
