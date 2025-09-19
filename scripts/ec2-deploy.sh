#!/usr/bin/env bash
set -euo pipefail

# Idiot-proof EC2 deploy via SSM. No SSH required.
# - Installs Docker + AWS CLI on the instance (idempotent)
# - Deploys the container from ECR with required env/params
#
# Usage:
#   scripts/ec2-deploy.sh [INSTANCE_ID]
#
# Env (optional):
#   AWS_PROFILE (default: devops-sandbox)
#   AWS_REGION  (default: ap-southeast-2)
#   DOMAIN      (default: java-demo-ec2.aws.deanlofts.xyz)

AWS_PROFILE=${AWS_PROFILE:-devops-sandbox}
AWS_REGION=${AWS_REGION:-ap-southeast-2}
DOMAIN=${DOMAIN:-java-demo-ec2.aws.deanlofts.xyz}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)

INSTANCE_ID=${1:-}
if [[ -z "$INSTANCE_ID" ]]; then
  # Try resolve by Name tag set by Terraform (aws-lab-java-<env>-ec2-app); fall back to single running instance.
  INSTANCE_ID=$(aws ec2 describe-instances \
    --profile "$AWS_PROFILE" --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=aws-lab-java-development-ec2-app" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' --output text || true)
  if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
    echo "ERROR: Could not resolve INSTANCE_ID automatically. Pass it explicitly: scripts/ec2-deploy.sh i-xxxxxxxxxxxxxxxxx" >&2
    exit 1
  fi>
fi

echo "Using AWS_PROFILE=$AWS_PROFILE AWS_REGION=$AWS_REGION INSTANCE_ID=$INSTANCE_ID"

send_and_wait() {
  local param_file="$1"
  local cmd_id
  cmd_id=$(aws ssm send-command \
    --profile "$AWS_PROFILE" --region "$AWS_REGION" \
    --document-name AWS-RunShellScript \
    --targets Key=instanceids,Values="$INSTANCE_ID" \
    --parameters file://"$param_file" \
    --query 'Command.CommandId' --output text)
  echo "CommandId: $cmd_id ($param_file)"

  while true; do
    # shellcheck disable=SC2016
    local out
    out=$(aws ssm list-command-invocations \
      --profile "$AWS_PROFILE" --region "$AWS_REGION" --details \
      --command-id "$cmd_id" \
      --query 'CommandInvocations[0].CommandPlugins[0].[Status,Output]' --output text || true)
    local status
    status=$(awk 'NR==1 {print $1}' <<<"$out")
    echo "Status: $status"
    if [[ "$status" == "InProgress" || -z "$status" ]]; then
      sleep 3
      continue
    fi
    echo "Output:\n${out#*$status }"
    if [[ "$status" != "Success" ]]; then
      echo "ERROR: SSM command failed ($param_file)" >&2
      exit 1
    fi
    break
  done
}

echo "Step 1/2: Install Docker + AWS CLI (idempotent)"
send_and_wait "$repo_root/scripts/ssm/install_docker.json"

echo "Step 2/2: Deploy application container"
send_and_wait "$repo_root/scripts/ssm/deploy_app.json"

echo "Checking health via ALB: https://$DOMAIN/actuator/health"
set +e
code=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/actuator/health")
set -e
echo "HTTP: $code"
if [[ "$code" != "200" ]]; then
  echo "NOTE: ALB may need a minute to mark target healthy. Rechecking target group..."
fi

echo "Done."

