#!/usr/bin/env bash
set -euo pipefail

region="${AWS_REGION:-us-east-1}"
account_id="$(aws sts get-caller-identity --query Account --output text)"
bucket="${1:-}"

if [ -n "$bucket" ]; then
  if ! aws s3api head-bucket --bucket "$bucket"; then
    echo "The bucket exists or is reachable only with different permissions: $bucket"
    echo "Verify the bucket name and that this AWS Academy identity can access it."
    exit 1
  fi
  echo "Using existing state bucket: $bucket"
  echo "Configure TF_STATE_BUCKET=$bucket in GitHub."
  exit 0
fi

bucket="garage-management-tf-state-${account_id}"

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
