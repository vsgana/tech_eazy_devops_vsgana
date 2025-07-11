# EC2 Deployment with GitHub Actions and Terraform

This project automates the provisioning of AWS infrastructure using **Terraform**, triggered via **GitHub Actions**.

## 📦 Features

- Provision EC2 instances (`writer` and `reader`)
- Attach IAM instance profiles
- Store logs in an S3 bucket
- Auto-generate key pairs for SSH access
- Deploy app scripts using `user_data`
- Health check on Port 80 after deployment
- Triggered on:
  - Push to `main`
  - Tags `deploy-dev` or `deploy-prod`
  - Manual trigger via **GitHub Actions UI**

---

## 🚀 Deployment Flow

1. GitHub Action runs on:
   - Push to `main`
   - Push tag like `deploy-dev` or `deploy-prod`
   - Manual trigger via **workflow_dispatch**

2. Terraform:
   - Initializes the project
   - Applies infrastructure using `${stage}.tfvars`
   - Provisions two EC2 instances
   - Creates S3 bucket with lifecycle rules
   - Writes logs to S3
   - Generates dynamic SSH key pairs

3. Health check:
   - Polls the writer EC2 public IP
   - Verifies port 80 returns HTTP `200` (OK)

---

## 🛠 Manual Trigger Instructions

You can manually deploy using GitHub’s UI:

1. Go to **Actions → Deploy EC2 with Terraform**
2. Click **"Run workflow"**
3. Choose the environment:
   - `dev`
   - `prod`

---

## 🧪 Variables

Terraform uses different variable files depending on the stage:

- `dev.tfvars`
- `prod.tfvars`


---

## 🔐 Secrets Used

Add these in **GitHub > Settings > Secrets and Variables > Actions**:

| Secret Name             | Description              |
|-------------------------|--------------------------|
| `AWS_ACCESS_KEY_ID`     | Your AWS access key ID   |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key      |

---

.
├── .github/workflows/
│   └── deploy.yml
├── main.tf
├── output.tf
├── iam.tf
├── dev.tfvars
├── prod.tfvars
└── scripts/
      └── scripts.sh
      └── reader.sh





