#!/usr/bin/env bash
set -euo pipefail

region="${AWS_REGION:-us-east-1}"
account_id="$(aws sts get-caller-identity --query Account --output text)"
bucket="${1:-garage-management-tf-state-${account_id}}"

if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
  echo "State bucket already exists: $bucket"
  exit 0
fi

if [ "$region" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$bucket" --region "$region"
else
  aws s3api create-bucket \
    --bucket "$bucket" \
    --region "$region" \
    --create-bucket-configuration LocationConstraint="$region"
fi

aws s3api put-bucket-versioning \
  --bucket "$bucket" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "$bucket" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-encryption \
  --bucket "$bucket" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo
echo "Configure this GitHub Environment variable in all five repositories:"
echo "TF_STATE_BUCKET=$bucket"
