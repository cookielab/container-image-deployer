#!/bin/sh

set -xe

MISSING_ENV=0

if [[ -z "${SOURCE_DIR}" ]]; then
  echo "SOURCE_DIR env must be set"
  MISSING_ENV=1
fi

if [[ -z "${AWS_S3_BUCKET}" ]]; then
  echo "AWS_S3_BUCKET env must be set"
  MISSING_ENV=1
fi

if [[ -z "${AWS_CF_DISTRIBUTION_ID}" ]]; then
  echo "AWS_CF_DISTRIBUTION_ID env must be set"
  MISSING_ENV=1
fi

if [[ "${MISSING_ENV}" == "1" ]]; then
  exit 1
fi

aws s3 cp --recursive "${SOURCE_DIR}" "s3://${AWS_S3_BUCKET}/"
AWS_CF_INVALIDATION_ID="$(aws cloudfront create-invalidation --distribution-id ${AWS_CF_DISTRIBUTION_ID} --paths '/*' | jq -r .Invalidation.Id)"
echo "CloudFront Invalidation ID - ${AWS_CF_INVALIDATION_ID}"
aws cloudfront wait invalidation-completed --distribution-id ${AWS_CF_DISTRIBUTION_ID} --id ${AWS_CF_INVALIDATION_ID}
