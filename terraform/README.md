# Terraform 실행 가이드

## 디렉토리 구조

```
terraform/
├── modules/
│   ├── foundation/      # S3, DynamoDB, IAM
│   ├── vector_store/    # OpenSearch Serverless
│   ├── knowledge_base/  # Bedrock Knowledge Base
│   ├── gateway/         # Lambda, AgentCore, Cognito
│   └── config/          # SSM Parameters
└── environments/
    ├── dev/             # 개발 환경
    └── prod/            # 운영 환경
```

## 사전 준비

```bash
# AWS 자격증명 설정
aws configure
# 또는
export AWS_PROFILE=your-profile

# Python 가상환경 (seed 스크립트용)
cd /path/to/repo
python3 -m venv .venv
.venv/bin/pip install boto3 requests
```

## 환경 선택

### Dev 환경

```bash
cd terraform/environments/dev
terraform init
```

### Prod 환경

```bash
cd terraform/environments/prod
terraform init
```

## 전체 배포

```bash
terraform plan
terraform apply
```

## Stage별 순차 배포 (권장)

Stage 간 의존성이 있으므로 아래 순서를 따릅니다.

```bash
# 1단계: S3, DynamoDB, IAM
terraform apply -target=module.foundation

# 2단계: OpenSearch Serverless + 인덱스 생성
terraform apply -target=module.vector_store

# 3단계: Bedrock Knowledge Base + 데이터 수집
terraform apply -target=module.knowledge_base

# 4단계: Lambda, AgentCore Gateway, Cognito
terraform apply -target=module.gateway

# 5단계: SSM Parameters
terraform apply -target=module.config
```

## Dev vs Prod 차이

| 항목 | dev | prod |
|------|-----|------|
| `project_name` | `anycompany-dev` | `anycompany` |
| Coordinator 모델 | Claude Haiku 4.5 (저렴) | Claude Sonnet 4.6 |
| Sub-agent 모델 | Claude Haiku 4.5 | Claude Haiku 4.5 |

## 환경별 변수 수정

`terraform.tfvars`에서 변경:

```hcl
# environments/dev/terraform.tfvars
project_name         = "anycompany-dev"
region               = "us-west-2"
coordinator_model_id = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
python_bin           = "/path/to/your/.venv/bin/python3"
```

## 리소스 삭제

```bash
# 특정 stage만 삭제
terraform destroy -target=module.knowledge_base

# 전체 삭제
terraform destroy
```

## 주의사항

- `module.vector_store`는 OpenSearch Serverless 생성 후 인덱스 초기화까지 수행합니다. 완료까지 약 2~3분 소요됩니다.
- `module.knowledge_base`의 KB ingestion은 비동기로 실행됩니다. AWS 콘솔에서 ingestion 완료 여부를 확인하세요.
- `agentcore_gateway_url` SSM 파라미터는 Gateway 생성 후 수동으로 업데이트해야 합니다.
