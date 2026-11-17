#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
STACK_NAME="${STACK_NAME:-coffee-shop-ecs}"
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-shiva029}"
IMAGE_TAG="${IMAGE_TAG:-v2}"

echo "Checking AWS credentials..."
aws sts get-caller-identity --region "$AWS_REGION" >/dev/null

echo "Finding the default VPC and two subnets in different Availability Zones..."
VPC_ID="$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)"
if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  echo "No default VPC found in $AWS_REGION. Create a default VPC or adapt the template for your VPC."
  exit 1
fi

SUBNETS="$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets | sort_by(@, &AvailabilityZone) | [?MapPublicIpOnLaunch==`true`].[SubnetId,AvailabilityZone]' --output text | awk '!seen[$2]++ {print $1}' | head -n 2 | paste -sd, -)" 
IFS=',' read -r -a SUBNET_ARRAY <<< "$SUBNETS"
if [[ "${#SUBNET_ARRAY[@]}" -lt 2 ]]; then
  echo "Need two default-VPC subnets in different Availability Zones with public IP mapping enabled."
  exit 1
fi

echo "Using VPC: $VPC_ID"
echo "Using subnets: $SUBNETS"
echo "Deploying stack $STACK_NAME in $AWS_REGION..."

aws cloudformation deploy \
  --template-file cloudformation/ecs-stack.yaml \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --parameter-overrides \
    "VpcId=$VPC_ID" \
    "SubnetIds=$SUBNETS" \
    "DockerHubUsername=$DOCKERHUB_USERNAME" \
    "ImageTag=$IMAGE_TAG" \
  --capabilities CAPABILITY_IAM

echo
echo "Application URL:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ApplicationURL'].OutputValue | [0]" --output text
