# Automated Cloud Cost-Optimization Pipeline

## 📌 Project Overview

An enterprise-grade FinOps automation pipeline engineered to eliminate cloud resource wastage. This system automatically identifies running development environments and gracefully terminates them during off-business hours based on specific resource tagging schema (`AutoStop = true`), reducing idle compute infrastructure costs by up to 30%.

## 🏗️ Architecture & Tools

- **Infrastructure as Code (IaC):** Terraform (configured for `us-east-1`)
- **Cloud Provider:** Amazon Web Services (AWS)
- **Compute Asset:** AWS EC2 (Ubuntu Linux)
- **Serverless Automation:** AWS Lambda (Python 3.11 with Boto3 SDK)
- **Event Orchestration:** Amazon EventBridge (CloudWatch Events via Cron Expression)

---

## 🛠️ Step-by-Step Implementation

### 1. Infrastructure Layer (Terraform)

The environment consists of an AWS EC2 instance built natively using Infrastructure as Code. The instance is dynamically labeled with targeted automation tags:

- `Environment = Dev`
- `AutoStop = true`

### 2. Automation Layer (Python & AWS Lambda)

A Python serverless function utilizes the `boto3` SDK to query the AWS EC2 control plane. It captures instance IDs matching the filtering criteria (`instance-state-name: running` and `tag:AutoStop: true`) and triggers a graceful `stop_instances` execution.

- _Note:_ Lambda timeout threshold configured to `10 seconds` to absorb API handshake latency.

### 3. Orchestration Layer (EventBridge Cron)

An EventBridge rule invokes the Lambda function on a scheduled cron configuration:
`cron(0 22 ? * MON-FRI *)` -> Executes automatically at 5:00 PM EST, Monday through Friday.

---

## 🚀 How to Deploy Locally

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/tmeri26/aws-cost-saver.git](https://github.com/tmeri26/aws-cost-saver.git)
   cd aws-cost-saver
   ```

terraform init

terraform apply
