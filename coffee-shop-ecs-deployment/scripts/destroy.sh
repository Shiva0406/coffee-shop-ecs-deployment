#!/usr/bin/env bash
set -euo pipefail
AWS_REGION="${AWS_REGION:-ap-south-1}"
STACK_NAME="${STACK_NAME:-coffee-shop-ecs}"

echo "WARNING: This deletes the ECS services, ALB, RDS database, and generated database secret."
read -r -p "Type DELETE to continue: " CONFIRM
[[ "$CONFIRM" == "DELETE" ]] || { echo "Cancelled."; exit 0; }

aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
echo "Stack deleted."
