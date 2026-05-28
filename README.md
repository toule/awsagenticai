# AWS Agentic AI — 셀프호스팅 핸즈온

AWS Workshop Studio "Agentic AI 핸즈온 Day" 를 자기 AWS 계정에서 처음부터 끝까지 재현·운영 가능한 코드 repo.

## 위키

전체 가이드 (이론 + 핸즈온): https://toule.atlassian.net/wiki/spaces/IT/pages/909770754

## 빠른 시작

```bash
git clone https://github.com/toule/awsagenticai.git
cd awsagenticai
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cd terraform
terraform init && terraform apply   # ~7분
```

## 구조

```
terraform/       ← Bootstrap 인프라 (실 apply 검증됨)
scripts/         ← 인덱스 생성, DDB 시드
seed-data/       ← AnyCompany 샘플 데이터 (50건)
lab-0/           ← Strands 기초 8패턴
lab-1b/          ← FAQ Agent (Strands)
lab-2/           ← 제품검색 + MCP + Guardrails
lab-3/           ← 재고 에이전트
lab-4/           ← 오케스트레이터 (Agents-as-Tools)
lab-5/           ← AgentCore Runtime 배포
lab-6/           ← Observability + Eval
```

## 검증 상태

- Bootstrap: us-west-2 실 apply 7분 통과 (account 264594923212)
- Lab-7 caching: cacheWriteInputTokens=1218, cacheReadInputTokens=1218
- Lab-8 Memory: ACTIVE 143s, create_event + list_events PASS
- Lab-9 thinking: reasoningContent + text 정상 반환
- Lab-11 Code Interpreter: SANDBOX numpy 실행 PASS

## 모델 ID 규칙

4세대 Anthropic (Sonnet 4.6, Haiku 4.5) 은 inference profile prefix 필수:
- `us.anthropic.claude-sonnet-4-6` (us-west-2/east-1/east-2)
- `global.anthropic.claude-sonnet-4-6` (4+ region)
- bare ID → ValidationException
