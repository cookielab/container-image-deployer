#!/bin/sh

set -e

help() {
  echo "Usage: $0 [-h] [-v] -d <SOURCE_DIR> -b <AWS_S3_BUCKET_URI> -i <AWS_CF_DISTRIBUTION_ID>"
  echo "  -h    Display this help message"
  echo "  -v    Verbose output (commands are being executed)"
  echo "  -d    Source directory"
  echo "  -b    S3 bucket URI (s3://<bucket-name>/[<directory>])"
  echo "  -i    CloudFront Distribution ID"
}

log() {
  if [ $# -eq 2 ]; then
    printf "%-32s %s\n" "${1}:" "$2" >&2
  else
    echo "$@" >&2
  fi
}

# Recursive copy to S3
# ====================
#
# Requires the source directory (-d) and the S3 Bucket URI (-b)
#
s3_cp() {
  src_dir="${1}"
  s3_uri="${2}"
  s3_bucket=$(echo "${s3_uri}" | awk -F/ '{print $3}')
  s3_dir=$(echo "${s3_uri}" | awk -F/ 'BEGIN { OFS="/"; ORS="/"; } { for (i=4; i<=NF; i++) printf "%s%s", $i, (i<NF ? OFS : ORS)}' | sed 's|//|/|')
  log "Source Directory" "${src_dir}"
  log "Destination S3 bucket name" "${s3_bucket}"
  log "Destination S3 bucket directory" "${s3_dir}"
  test "${VERBOSE}" -gt 0 && set -x
  aws s3 cp --recursive "${src_dir}" "${s3_uri}"
  ret=$?
  test "${VERBOSE}" -gt 0 && set +x
  return ${ret}
}

# CloudFront invalidation
# =======================
#
# This is wrapped to retrieve the Invalidation ID for the foll
#
# Requires the CloudFront Distribution ID (-i)
#
cf_invalidate() {
  d_id="${1}"
  log "CloudFront Distribution ID" "${d_id}"
  test "${VERBOSE}" -gt 0 && set -x
  aws cloudfront create-invalidation --distribution-id "${d_id}" --paths '/*' | jq -r .Invalidation.Id
  ret=$?
  test "${VERBOSE}" -gt 0 && set +x
  return ${ret}
}

# CloudFront wait-to-finish invalidation
# ======================================
#
# Requires the CloudFront Distribution ID (-i) and the Invalidation ID (value from cf_invalidate)
#
cf_wait() {
  d_id="${1}"
  inv_id="${2}"
  log "CloudFront Invalidation ID" "${inv_id}"
  test "${VERBOSE}" -gt 0 && set -x
  aws cloudfront wait invalidation-completed --distribution-id "${d_id}" --id "${inv_id}"
  ret=$?
  test "${VERBOSE}" -gt 0 && set +x
  return ${ret}
}

########################################################################################

# Parse command line
#
OPTIND=1
VERBOSE=0
while getopts "h?d:b:i:v?" opt; do
  case "$opt" in
    h)
      help
      exit 0
      ;;
    d) SOURCE_DIR="${OPTARG}" ;;
    b) AWS_S3_BUCKET_URI="${OPTARG}" ;;
    i) AWS_CF_DISTRIBUTION_ID="${OPTARG}" ;;
    v) VERBOSE=1 ;;
    *) log "Unknown option ${opt}" ;;
  esac
done

# Validate inputs
#
test -z "${SOURCE_DIR}" && help && exit 1
test -z "${AWS_S3_BUCKET_URI}" && help && exit 1
test -z "${AWS_CF_DISTRIBUTION_ID}" && help && exit 1
(echo "${AWS_S3_BUCKET_URI}" | grep -Eq '^s3://[a-zA-Z0-9._-]+/' ) || (
  log "Invalid S3 URI: ${AWS_S3_BUCKET_URI} (It needs to be in the following format: s3://<bucket-name>/[<directory>])" && \
  exit 1 \
)

# Run the operations
#
s3_cp "${SOURCE_DIR}" "${AWS_S3_BUCKET_URI}"
AWS_CF_INVALIDATION_ID=$(cf_invalidate "${AWS_CF_DISTRIBUTION_ID}" || exit 1)
cf_wait "${AWS_CF_DISTRIBUTION_ID}" "${AWS_CF_INVALIDATION_ID}"
