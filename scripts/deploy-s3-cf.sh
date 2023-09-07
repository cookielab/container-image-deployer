#!/bin/sh

help() {
  echo "Usage: $0 [-h] [-v] -d <SOURCE_DIR> -b <AWS_S3_BUCKET_URI> -i <AWS_CF_DISTRIBUTION_ID>"
  echo ""
  echo "Options:"
  echo "  -d SOURCE_DIR"
  echo "        Local source directory. Required!"
  echo "  -b AWS_S3_BUCKET_URI"
  echo "        AWS S3 bucket URI in the following format: 's3://<bucket>/[<directory>]'. Required!"
  echo "  -i AWS_CF_DISTRIBUTION_ID"
  echo "        AWS CloudFront Distribution ID. Required!"
  echo "  -v    Verbose output (print API commands being executed)"
  echo "  -h    Display this help message"
  echo ""
  echo "Other supported environment variables:"
  echo "  AWS_S3_BUCKET  Can be used to construct the S3 bucket URI."
  echo "                 If used, AWS_S3_BUCKET_URI doesn't have to be set."
  echo "  AWS_S3_PATH    Can be used to construct the S3 bucket URI. Has to start with '/'."
  echo "                 Works only when AWS_S3_BUCKET is set. Defaults to '/'."
  echo ""
  echo "All mandatory options can be provided as environment variables."
}

log() {
  if [ $# -eq 2 ]; then
    printf " -> %-32s %s\n" "${1}:" "$2" >&2
  else
    echo "$@" >&2
  fi
}

# Copy to S3
# ==========
# Wrapper to recursively copy the source directory to the S3 bucket URI
#
# Requires:
# - the source directory (-d / $SOURCE_DIR)
# - the S3 Bucket URI (-b / $AWS_S3_BUCKET_URI)
#
s3_cp() {
  src_dir="${1}"
  s3_uri="${2}"
  s3_bucket=$(echo "${s3_uri}" | awk -F/ '{print $3}')
  s3_dir=/$(echo "${s3_uri}" | awk -F/ 'BEGIN { OFS="/"; ORS=""; } { for (i=4; i<=NF; i++) printf "%s%s", $i, (i<NF ? OFS : ORS)}' | sed 's|/*$||')
  log "Source Directory" "${src_dir}"
  log "Destination S3 bucket name" "${s3_bucket}"
  log "Destination S3 bucket directory" "${s3_dir}"
  cmd_opts="--recursive"
  test "${VERBOSE}" -gt 0 && set -x
  aws s3 cp ${cmd_opts} "${src_dir}" "s3://${s3_bucket}${s3_dir}"
  ret=$?
  test "${VERBOSE}" -gt 0 && set +x
  return ${ret}
}

# CloudFront invalidation
# =======================
# Wrapper to retrieve the Invalidation ID for the `cf_wait` function.
#
# Requires:
# - the CloudFront Distribution ID (-i / $AWS_CF_DISTRIBUTION_ID)
#
cf_invalidate() {
  cf_dist_id="${1}"
  log "CloudFront Distribution ID" "${cf_dist_id}"
  test "${VERBOSE}" -gt 0 && set -x
  val=$(aws cloudfront create-invalidation --distribution-id "${cf_dist_id}" --paths '/*' --output json)
  ret=$?
  test "${VERBOSE}" -gt 0 && set +x
  echo "${val}" | jq -r .Invalidation.Id
  return ${ret}
}

# CloudFront wait-to-finish invalidation
# ======================================
# This just waits for the CloudFront Invalidation to finish.
#
# Requires:
# - the CloudFront Distribution ID (-i / $AWS_CF_DISTRIBUTION_ID)
# - the CloudFront Invalidation ID (value from cf_invalidate)
#
cf_wait() {
  cf_dist_id="${1}"
  cf_inv_id="${2}"
  log "CloudFront Invalidation ID" "${cf_inv_id}"
  test "${VERBOSE}" -gt 0 && set -x
  aws cloudfront wait invalidation-completed --distribution-id "${cf_dist_id}" --id "${cf_inv_id}"
  ret=$?
  test "${VERBOSE}" -gt 0 && set +x
  return ${ret}
}

########################################################################################
set -e

OPTIND=1
VERBOSE=0
ERR=0

# Use the optional input variables when defined
test -n "${AWS_S3_BUCKET}" && AWS_S3_BUCKET_URI="s3://${AWS_S3_BUCKET}${AWS_S3_PATH:-/}"

# Parse command line
while getopts "h?d:b:i:v?" opt; do
  case "${opt}" in
    h) help && exit 0 ;;
    d) SOURCE_DIR="${OPTARG}" ;;
    b) AWS_S3_BUCKET_URI="${OPTARG}" ;;
    i) AWS_CF_DISTRIBUTION_ID="${OPTARG}" ;;
    v) VERBOSE=1 ;;
    *) log "Unknown option ${opt}" ;;
  esac
done

# Validate inputs
test -z "${SOURCE_DIR}" && log "!!! No source directory specified" && ERR=1
test -z "${AWS_CF_DISTRIBUTION_ID}" && log "!!! No CloudFront Distribution ID specified" && ERR=1
test -z "${AWS_S3_BUCKET_URI}" && log "!!! No S3 Bucket URI specified" && ERR=1
test "${ERR}" -eq 1 && help && exit 1

if ! (echo "${AWS_S3_BUCKET_URI}" | grep -Eq '^s3://[a-zA-Z0-9._-]+/')
then
  log "!!! Invalid S3 URI: ${AWS_S3_BUCKET_URI} (It needs to be in the following format: s3://<bucket-name>/[<directory>])"
  ERR=1
fi
test "${ERR}" -gt 0 && exit 1

# Run the operations
log "==> Files in S3 (copying)"
s3_cp "${SOURCE_DIR}" "${AWS_S3_BUCKET_URI}"
log "==> Files in S3 (copied)"

log "==> CloudFront Invalidation (creating)"
AWS_CF_INVALIDATION_ID=$(cf_invalidate "${AWS_CF_DISTRIBUTION_ID}")
log "==> CloudFront Invalidation (waiting)"
cf_wait "${AWS_CF_DISTRIBUTION_ID}" "${AWS_CF_INVALIDATION_ID}"
log "==> CloudFront Invalidation (finished)"
