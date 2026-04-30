# ReadForMe

A serverless application that converts documents into audio. Upload a file, and the app extracts the text, detects its language, optionally translates it to your chosen language, and generates an MP3 using AWS Polly — all orchestrated through a Step Functions state machine.

---

## How It Works

1. The frontend requests a pre-signed S3 upload URL from the API.
2. The file is uploaded directly to S3 from the browser.
3. An S3 event triggers EventBridge, which starts the Step Functions state machine.
4. The state machine runs four Lambda functions in sequence:
   - **Text Extractor** — uses Amazon Textract to extract text from the document.
   - **Language Detector** — uses Amazon Comprehend to identify the source language.
   - **Text Translator** — uses Amazon Translate to translate to the target language (skipped if source = target).
   - **Audio Generator** — uses Amazon Polly to synthesize speech and saves the MP3 to S3.
5. Job status is tracked in DynamoDB throughout the pipeline.
6. The frontend polls the download API using the `job_id` and plays the audio once ready.

---

## Architecture

```
Browser
  │
  ├─► API Gateway ──► upload-url-generator (Lambda)  ──► S3 pre-signed URL
  │
  ├─► S3 (file upload via pre-signed URL)
  │       │
  │       └─► EventBridge ──► Step Functions State Machine
  │                                   │
  │                           text-extractor (Textract)
  │                                   │
  │                           language-detector (Comprehend)
  │                                   │
  │                           text-translator (Translate)
  │                                   │
  │                           audio-generator (Polly) ──► S3 (MP3)
  │
  └─► API Gateway ──► download-url-generator (Lambda) ──► DynamoDB + S3 pre-signed URL
```

---

## Project Structure

```
read-for-me/
├── backend/                        # Lambda function source code (Python)
│   ├── upload_url_generator.py     # Generates S3 pre-signed PUT URL for file upload
│   ├── download_url_generator.py   # Checks job status in DynamoDB; returns pre-signed GET URL for the MP3
│   ├── text_extractor.py           # Extracts text from uploaded document using Textract
│   ├── language_detector.py        # Detects dominant language using Comprehend
│   ├── text_translator.py          # Translates text to target language using Translate
│   ├── audio_generator.py          # Synthesizes MP3 from text using Polly; uploads to S3
│   └── lambda_function_*.zip       # Deployment packages uploaded to AWS by Terraform
│
├── frontend/                       # Static web frontend
│   ├── index.html                  # Main UI — file upload, language selection, audio playback
│   └── authentication.js           # Cognito OAuth2 PKCE flow — login, token exchange, refresh
│
├── infra/                          # Terraform infrastructure-as-code (AWS, ap-south-1)
│   ├── main.tf                     # Provider config and S3 remote state backend
│   ├── common.tf                   # Shared IAM trust policies and input variables
│   ├── api-gateway.tf              # REST API Gateway with Cognito authorizer
│   ├── cognito.tf                  # Cognito User Pool and App Client
│   ├── amplify.tf                  # Amplify app for hosting the frontend
│   ├── dynamodb.tf                 # DynamoDB table (ReadForMe) for job tracking
│   ├── event-bridge.tf             # EventBridge rule to trigger state machine on S3 upload
│   ├── step-function-state-machine.tf  # Step Functions state machine definition
│   ├── lambda-upload-url-generator.tf
│   ├── lambda-download-url-generator.tf
│   ├── lambda-text-extractor.tf
│   ├── lambda-language-detector.tf
│   ├── lambda-text-translator.tf
│   └── lambda-audio-generator.tf
│
└── .github/
    ├── workflows/
    │   └── build_deploy.yaml       # CI/CD pipeline — runs Terraform, then deploys frontend to Amplify
    └── scripts/
        └── terraform.sh            # Helper script to run Terraform from the infra/ directory
```

---

## Languages & Technologies

| Layer | Technology |
|---|---|
| Backend | Python 3 |
| Infrastructure | Terraform (HCL) |
| Frontend | HTML, JavaScript (vanilla) |
| CI/CD | GitHub Actions |
| AWS Services | Lambda, API Gateway, S3, Step Functions, EventBridge, DynamoDB, Textract, Comprehend, Translate, Polly, Cognito, Amplify |

---

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.x
- AWS CLI configured with credentials that have sufficient permissions
- An S3 bucket named `read-for-me-tfstate` for Terraform remote state (create this manually once)

### Clone the repository

```bash
git clone https://github.com/<your-username>/read-for-me.git
cd read-for-me
```

### Deploy infrastructure

```bash
cd infra
terraform init
terraform apply
```

Terraform will provision all AWS resources and output the Cognito domain, client ID, Amplify app URL, and API Gateway stage URL.

### Deploy the frontend

The CI/CD pipeline handles frontend deployment automatically on every push to `main`. It:
1. Runs `terraform apply` to ensure infrastructure is up to date.
2. Generates a `config.js` file from Terraform outputs (Cognito settings, API URL).
3. Zips `index.html`, `authentication.js`, and `config.js`, uploads to S3, and triggers an Amplify deployment.

To deploy manually, replicate the steps in `.github/workflows/build_deploy.yaml`.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS access key for CI/CD |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for CI/CD |

---

## DynamoDB Job Tracking

Each upload creates a job record in the `ReadForMe` table with the following lifecycle:

```
TEXT_EXTRACTED → DOMINANT_LANGUAGE_DETECTED → TEXT_TRANSLATION_DONE → AUDIO_GENERATION_DONE
```

The download API returns the job status and, once complete, a pre-signed URL to stream or download the generated MP3.
